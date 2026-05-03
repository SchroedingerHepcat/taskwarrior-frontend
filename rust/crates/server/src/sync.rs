use taskwarrior_compat::TaskChampionSyncConfig;
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PreparedTaskWrite {
    pub task_id: Uuid,
    pub operation_count: usize,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SyncMode {
    Disabled,
    Configured,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SyncStatus {
    Disabled,
    Pending,
    Synced { task_count: usize },
    Failed(String),
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SyncAttempt {
    pub status: SyncStatus,
}

pub trait SyncCoordinator {
    fn record_task_write(
        &mut self,
        write: PreparedTaskWrite,
    ) -> Result<(), String>;

    fn mode(&self) -> SyncMode;

    fn sync_config(&self) -> TaskChampionSyncConfig;

    fn record_sync_attempt(
        &mut self,
        attempt: SyncAttempt,
    ) -> Result<(), String>;
}

#[derive(Default)]
pub struct InMemorySyncCoordinator {
    writes: Vec<PreparedTaskWrite>,
    attempts: Vec<SyncAttempt>,
    sync_config: TaskChampionSyncConfig,
}

impl InMemorySyncCoordinator {
    pub fn disabled() -> Self {
        Self::default()
    }

    pub fn configured(config: TaskChampionSyncConfig) -> Self {
        Self {
            sync_config: config,
            ..Self::default()
        }
    }

    pub fn writes(&self) -> &[PreparedTaskWrite] {
        &self.writes
    }

    pub fn attempts(&self) -> &[SyncAttempt] {
        &self.attempts
    }
}

impl SyncCoordinator for InMemorySyncCoordinator {
    fn record_task_write(
        &mut self,
        write: PreparedTaskWrite,
    ) -> Result<(), String> {
        self.writes.push(write);
        Ok(())
    }

    fn mode(&self) -> SyncMode {
        if self.sync_config.is_enabled() {
            SyncMode::Configured
        } else {
            SyncMode::Disabled
        }
    }

    fn sync_config(&self) -> TaskChampionSyncConfig {
        self.sync_config.clone()
    }

    fn record_sync_attempt(
        &mut self,
        attempt: SyncAttempt,
    ) -> Result<(), String> {
        self.attempts.push(attempt);
        Ok(())
    }
}
