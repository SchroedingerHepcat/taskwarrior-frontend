use std::error::Error;
use std::fmt::{Display, Formatter};

#[derive(Debug, Eq, PartialEq)]
pub enum CompatibilityError {
    InvalidTimestamp { property: String, value: String },
    InvalidSyncConfig(String),
    TaskChampionStorage(String),
}

impl Display for CompatibilityError {
    fn fmt(
        &self,
        f: &mut Formatter<'_>,
    ) -> std::fmt::Result {
        match self {
            Self::InvalidTimestamp { property, value } => {
                write!(
                    f,
                    "invalid timestamp for {property}: {value}"
                )
            }
            Self::TaskChampionStorage(message) => {
                write!(
                    f,
                    "taskchampion storage error: {message}"
                )
            }
            Self::InvalidSyncConfig(message) => {
                write!(
                    f,
                    "invalid taskchampion sync config: {message}"
                )
            }
        }
    }
}

impl Error for CompatibilityError {}
