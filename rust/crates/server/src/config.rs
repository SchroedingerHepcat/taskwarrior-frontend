use taskwarrior_compat::{TaskChampionStorageConfig, TaskChampionSyncConfig};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum UiStateConfig {
    InMemory,
    JsonFile(std::path::PathBuf),
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BackendConfig {
    pub storage: TaskChampionStorageConfig,
    pub sync: TaskChampionSyncConfig,
    pub ui_state: UiStateConfig,
}

impl Default for BackendConfig {
    fn default() -> Self {
        Self {
            storage: TaskChampionStorageConfig::InMemory,
            sync: TaskChampionSyncConfig::Disabled,
            ui_state: UiStateConfig::InMemory,
        }
    }
}
