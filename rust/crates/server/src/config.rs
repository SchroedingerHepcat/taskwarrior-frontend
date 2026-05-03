use taskwarrior_compat::{TaskChampionStorageConfig, TaskChampionSyncConfig};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BackendConfig {
    pub storage: TaskChampionStorageConfig,
    pub sync: TaskChampionSyncConfig,
}

impl Default for BackendConfig {
    fn default() -> Self {
        Self {
            storage: TaskChampionStorageConfig::InMemory,
            sync: TaskChampionSyncConfig::Disabled,
        }
    }
}
