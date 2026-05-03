use taskwarrior_compat::{
    CompatibilityError, TaskChampionStorageConfig, TaskChampionSyncConfig,
    TaskChampionSyncReport, TaskChampionTaskStore,
};
use taskwarrior_core::Task;
use uuid::Uuid;

#[allow(async_fn_in_trait)]
pub trait TaskRepository {
    async fn get(
        &mut self,
        id: Uuid,
    ) -> Result<Option<Task>, CompatibilityError>;

    async fn list(&mut self) -> Result<Vec<Task>, CompatibilityError>;

    async fn upsert(
        &mut self,
        task: Task,
    ) -> Result<StoredTask, CompatibilityError>;

    async fn sync(
        &mut self,
        config: TaskChampionSyncConfig,
    ) -> Result<TaskChampionSyncReport, CompatibilityError>;
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct StoredTask {
    pub task: Task,
    pub operation_count: usize,
}

#[derive(Default)]
pub struct TaskChampionTaskRepository {
    store: TaskChampionTaskStore,
}

impl TaskChampionTaskRepository {
    pub fn new(store: TaskChampionTaskStore) -> Self {
        Self { store }
    }

    pub async fn from_storage_config(
        config: TaskChampionStorageConfig
    ) -> Result<Self, CompatibilityError> {
        Ok(Self {
            store: TaskChampionTaskStore::from_config(config).await?,
        })
    }
}

impl TaskRepository for TaskChampionTaskRepository {
    async fn get(
        &mut self,
        id: Uuid,
    ) -> Result<Option<Task>, CompatibilityError> {
        self.store.get_task(id).await
    }

    async fn list(&mut self) -> Result<Vec<Task>, CompatibilityError> {
        self.store.list_tasks().await
    }

    async fn upsert(
        &mut self,
        task: Task,
    ) -> Result<StoredTask, CompatibilityError> {
        let write = self.store.upsert_task(&task).await?;

        Ok(StoredTask {
            task: write.task,
            operation_count: write.operation_count,
        })
    }

    async fn sync(
        &mut self,
        config: TaskChampionSyncConfig,
    ) -> Result<TaskChampionSyncReport, CompatibilityError> {
        self.store.sync(config).await
    }
}
