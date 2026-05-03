use crate::codec::{decode_task, encode_task};
use crate::config::{
    sqlite_access_mode, TaskChampionStorageConfig, TaskChampionSyncConfig,
};
use crate::error::CompatibilityError;
use taskchampion::storage::inmemory::InMemoryStorage;
use taskchampion::{Replica, ServerConfig, SqliteStorage, Uuid};
use taskwarrior_core::Task;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskChampionWrite {
    pub task: Task,
    pub operation_count: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskChampionSyncReport {
    pub task_count: usize,
}

pub struct TaskChampionTaskStore {
    replica: TaskChampionReplica,
}

impl Default for TaskChampionTaskStore {
    fn default() -> Self {
        Self::new()
    }
}

impl TaskChampionTaskStore {
    pub fn new() -> Self {
        Self {
            replica: TaskChampionReplica::InMemory(Replica::new(
                InMemoryStorage::new(),
            )),
        }
    }

    pub async fn from_config(
        config: TaskChampionStorageConfig
    ) -> Result<Self, CompatibilityError> {
        let replica = match config {
            TaskChampionStorageConfig::InMemory => {
                TaskChampionReplica::InMemory(Replica::new(
                    InMemoryStorage::new(),
                ))
            }
            TaskChampionStorageConfig::Sqlite {
                path,
                create_if_missing,
            } => {
                let storage = SqliteStorage::new(
                    path,
                    sqlite_access_mode(),
                    create_if_missing,
                )
                .await
                .map_err(storage_error)?;
                TaskChampionReplica::Sqlite(Replica::new(storage))
            }
        };

        Ok(Self { replica })
    }

    pub async fn get_task(
        &mut self,
        task_id: Uuid,
    ) -> Result<Option<Task>, CompatibilityError> {
        let Some(task_data) = self.replica.get_task_data(task_id).await? else {
            return Ok(None);
        };

        decode_task(&task_data).map(Some)
    }

    pub async fn list_tasks(
        &mut self
    ) -> Result<Vec<Task>, CompatibilityError> {
        let task_data = self.replica.all_task_data().await?;

        task_data
            .iter()
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
            .await?;

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

    pub async fn sync(
        &mut self,
        config: TaskChampionSyncConfig,
    ) -> Result<TaskChampionSyncReport, CompatibilityError> {
        let Some(server_config) = config.into_server_config()? else {
            return Ok(TaskChampionSyncReport {
                task_count: self.list_tasks().await?.len(),
            });
        };

        self.sync_with_server_config(server_config).await
    }

    async fn sync_with_server_config(
        &mut self,
        config: ServerConfig,
    ) -> Result<TaskChampionSyncReport, CompatibilityError> {
        let mut server = config
            .into_server()
            .await
            .map_err(storage_error)?;
        self.replica.sync(&mut server, false).await?;

        Ok(TaskChampionSyncReport {
            task_count: self.list_tasks().await?.len(),
        })
    }
}

fn storage_error(error: taskchampion::Error) -> CompatibilityError {
    CompatibilityError::TaskChampionStorage(error.to_string())
}

enum TaskChampionReplica {
    InMemory(Replica<InMemoryStorage>),
    Sqlite(Replica<SqliteStorage>),
}

impl TaskChampionReplica {
    async fn get_task_data(
        &mut self,
        task_id: Uuid,
    ) -> Result<Option<taskchampion::TaskData>, CompatibilityError> {
        match self {
            Self::InMemory(replica) => replica
                .get_task_data(task_id)
                .await
                .map_err(storage_error),
            Self::Sqlite(replica) => replica
                .get_task_data(task_id)
                .await
                .map_err(storage_error),
        }
    }

    async fn all_task_data(
        &mut self
    ) -> Result<Vec<taskchampion::TaskData>, CompatibilityError> {
        let tasks = match self {
            Self::InMemory(replica) => replica
                .all_task_data()
                .await
                .map_err(storage_error)?,
            Self::Sqlite(replica) => replica
                .all_task_data()
                .await
                .map_err(storage_error)?,
        };

        Ok(tasks.into_values().collect())
    }

    async fn commit_operations(
        &mut self,
        operations: taskchampion::Operations,
    ) -> Result<(), CompatibilityError> {
        match self {
            Self::InMemory(replica) => replica
                .commit_operations(operations)
                .await
                .map_err(storage_error),
            Self::Sqlite(replica) => replica
                .commit_operations(operations)
                .await
                .map_err(storage_error),
        }
    }

    async fn sync(
        &mut self,
        server: &mut Box<dyn taskchampion::Server>,
        avoid_snapshots: bool,
    ) -> Result<(), CompatibilityError> {
        match self {
            Self::InMemory(replica) => replica
                .sync(server, avoid_snapshots)
                .await
                .map_err(storage_error),
            Self::Sqlite(replica) => replica
                .sync(server, avoid_snapshots)
                .await
                .map_err(storage_error),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::TaskChampionTaskStore;
    use crate::{
        TaskChampionLocalSyncConfig, TaskChampionStorageConfig,
        TaskChampionSyncConfig,
    };
    use std::fs;
    use std::path::PathBuf;
    use taskchampion::chrono::{TimeZone, Utc};
    use taskchampion::Uuid;
    use taskwarrior_core::{Task, TaskStatus};

    fn timestamp(secs: i64) -> taskchampion::chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    fn temp_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "taskwarrior-frontend-{name}-{}",
            Uuid::new_v4()
        ))
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

    #[tokio::test]
    async fn sqlite_config_persists_tasks_between_store_instances() {
        let storage_dir = temp_path("sqlite-storage");
        let task_id = Uuid::from_u128(502);

        let mut first = TaskChampionTaskStore::from_config(
            TaskChampionStorageConfig::Sqlite {
                path: storage_dir.clone(),
                create_if_missing: true,
            },
        )
        .await
        .unwrap();
        let mut task = Task::new(task_id, "durable sqlite task");
        task.entry = Some(timestamp(10));
        task.modified = Some(timestamp(10));
        first.upsert_task(&task).await.unwrap();
        drop(first);

        let mut second = TaskChampionTaskStore::from_config(
            TaskChampionStorageConfig::Sqlite {
                path: storage_dir.clone(),
                create_if_missing: false,
            },
        )
        .await
        .unwrap();
        let loaded = second.get_task(task_id).await.unwrap().unwrap();

        assert_eq!(
            loaded.description,
            "durable sqlite task"
        );

        let _ = fs::remove_dir_all(storage_dir);
    }

    #[tokio::test]
    async fn local_sync_moves_tasks_between_replicas() {
        let server_dir = temp_path("local-sync-server");
        fs::create_dir_all(&server_dir).unwrap();
        let task_id = Uuid::from_u128(503);
        let sync_config =
            TaskChampionSyncConfig::Local(TaskChampionLocalSyncConfig {
                server_dir: server_dir.clone(),
            });
        let mut source = TaskChampionTaskStore::new();
        let mut target = TaskChampionTaskStore::new();
        let mut task = Task::new(task_id, "synced through taskchampion");
        task.entry = Some(timestamp(10));
        task.modified = Some(timestamp(10));

        source.upsert_task(&task).await.unwrap();
        let source_report = source.sync(sync_config.clone()).await.unwrap();
        let target_report = target.sync(sync_config).await.unwrap();
        let loaded = target.get_task(task_id).await.unwrap().unwrap();

        assert_eq!(source_report.task_count, 1);
        assert_eq!(target_report.task_count, 1);
        assert_eq!(
            loaded.description,
            "synced through taskchampion"
        );

        let _ = fs::remove_dir_all(server_dir);
    }
}
