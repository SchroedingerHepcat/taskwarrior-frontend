use crate::error::CompatibilityError;
use std::path::PathBuf;
use taskchampion::storage::AccessMode;
use taskchampion::{ServerConfig, Uuid};

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TaskChampionStorageConfig {
    InMemory,
    Sqlite {
        path: PathBuf,
        create_if_missing: bool,
    },
}

impl Default for TaskChampionStorageConfig {
    fn default() -> Self {
        Self::InMemory
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum TaskChampionSyncConfig {
    Disabled,
    Local(TaskChampionLocalSyncConfig),
    Remote(TaskChampionRemoteSyncConfig),
}

impl Default for TaskChampionSyncConfig {
    fn default() -> Self {
        Self::Disabled
    }
}

impl TaskChampionSyncConfig {
    pub fn is_enabled(&self) -> bool {
        !matches!(self, Self::Disabled)
    }

    pub fn into_server_config(
        self
    ) -> Result<Option<ServerConfig>, CompatibilityError> {
        match self {
            Self::Disabled => Ok(None),
            Self::Local(config) => Ok(Some(ServerConfig::Local {
                server_dir: config.server_dir,
            })),
            Self::Remote(config) => {
                config.validate()?;

                Ok(Some(ServerConfig::Remote {
                    url: config.url,
                    client_id: config.client_id,
                    encryption_secret: config.encryption_secret,
                }))
            }
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskChampionLocalSyncConfig {
    pub server_dir: PathBuf,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskChampionRemoteSyncConfig {
    pub url: String,
    pub client_id: Uuid,
    pub encryption_secret: Vec<u8>,
    pub allow_plain_http: bool,
}

impl TaskChampionRemoteSyncConfig {
    fn validate(&self) -> Result<(), CompatibilityError> {
        if self.url.trim().is_empty() {
            return Err(CompatibilityError::InvalidSyncConfig(
                "remote sync server URL is required".to_string(),
            ));
        }

        if self.encryption_secret.is_empty() {
            return Err(CompatibilityError::InvalidSyncConfig(
                "remote sync encryption secret is required".to_string(),
            ));
        }

        if !self.allow_plain_http && self.url.starts_with("http://") {
            return Err(CompatibilityError::InvalidSyncConfig(
                "remote sync requires HTTPS unless plain HTTP is allowed"
                    .to_string(),
            ));
        }

        Ok(())
    }
}

pub fn sqlite_access_mode() -> AccessMode {
    AccessMode::ReadWrite
}
