//! Taskwarrior compatibility boundary for the compatibility spike.
//!
//! This crate prefers the existing `taskchampion` library for task-model
//! property names and low-level operation generation instead of inventing
//! custom storage behavior in this repository.

mod codec;
mod error;
mod properties;
mod store;

pub use codec::{decode_task, encode_task, EncodedTask};
pub use error::CompatibilityError;
pub use store::{TaskChampionTaskStore, TaskChampionWrite};
