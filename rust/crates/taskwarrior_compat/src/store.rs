use crate::codec::{decode_task, encode_task};
use crate::error::CompatibilityError;
use taskchampion::storage::inmemory::InMemoryStorage;
use taskchampion::{Replica, Uuid};
use taskwarrior_core::Task;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskChampionWrite {
    pub task: Task,
    pub operation_count: usize,
}

pub struct TaskChampionTaskStore {
    replica: Replica<InMemoryStorage>,
}

impl Default for TaskChampionTaskStore {
    fn default() -> Self {
        Self::new()
    }
}

impl TaskChampionTaskStore {
    pub fn new() -> Self {
        Self {
            replica: Replica::new(InMemoryStorage::new()),
        }
    }

    pub async fn get_task(
        &mut self,
        task_id: Uuid,
    ) -> Result<Option<Task>, CompatibilityError> {
        self.replica
            .get_task_data(task_id)
            .await
            .map_err(storage_error)?
            .map(|task_data| decode_task(&task_data))
            .transpose()
    }

    pub async fn list_tasks(
        &mut self
    ) -> Result<Vec<Task>, CompatibilityError> {
        let task_data = self
            .replica
            .all_task_data()
            .await
            .map_err(storage_error)?;

        task_data
            .values()
            .map(decode_task)
            .collect::<Result<Vec<_>, _>>()
    }

    pub async fn upsert_task(
        &mut self,
        task: &Task,
    ) -> Result<TaskChampionWrite, CompatibilityError> {
        let encoded = encode_task(task);
        let operation_count = encoded.operations.len();

        self.replica
            .commit_operations(encoded.operations)
            .await
            .map_err(storage_error)?;

        let task = self.get_task(task.id).await?.ok_or_else(|| {
            CompatibilityError::TaskChampionStorage(format!(
                "task {} was not readable after commit",
                task.id
            ))
        })?;

        Ok(TaskChampionWrite {
            task,
            operation_count,
        })
    }
}

fn storage_error(error: taskchampion::Error) -> CompatibilityError {
    CompatibilityError::TaskChampionStorage(error.to_string())
}

#[cfg(test)]
mod tests {
    use super::TaskChampionTaskStore;
    use taskchampion::chrono::{TimeZone, Utc};
    use taskchampion::Uuid;
    use taskwarrior_core::{Task, TaskStatus};

    fn timestamp(secs: i64) -> taskchampion::chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    #[tokio::test]
    async fn upsert_commits_to_taskchampion_storage() {
        let mut store = TaskChampionTaskStore::new();
        let task_id = Uuid::from_u128(500);
        let mut task = Task::new(task_id, "stored by taskchampion");
        task.entry = Some(timestamp(10));
        task.modified = Some(timestamp(10));
        task.project = Some("storage".to_string());
        task.add_tag("backend");

        let write = store.upsert_task(&task).await.unwrap();
        let loaded = store.get_task(task_id).await.unwrap().unwrap();
        let listed = store.list_tasks().await.unwrap();

        assert!(write.operation_count > 0);
        assert_eq!(write.task, loaded);
        assert_eq!(
            loaded.description,
            "stored by taskchampion"
        );
        assert_eq!(
            loaded.project,
            Some("storage".to_string())
        );
        assert!(loaded.tags.contains("backend"));
        assert_eq!(listed, vec![loaded]);
    }

    #[tokio::test]
    async fn upsert_updates_existing_taskchampion_task() {
        let mut store = TaskChampionTaskStore::new();
        let task_id = Uuid::from_u128(501);
        let mut task = Task::new(task_id, "first");
        task.entry = Some(timestamp(10));
        task.modified = Some(timestamp(10));
        store.upsert_task(&task).await.unwrap();

        task.description = "second".to_string();
        task.transition_status(TaskStatus::Completed, timestamp(20));
        store.upsert_task(&task).await.unwrap();

        let loaded = store.get_task(task_id).await.unwrap().unwrap();

        assert_eq!(loaded.description, "second");
        assert_eq!(loaded.status, TaskStatus::Completed);
        assert_eq!(loaded.end, Some(timestamp(20)));
    }
}
