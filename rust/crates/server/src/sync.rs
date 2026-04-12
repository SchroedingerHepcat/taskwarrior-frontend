use taskwarrior_compat::{encode_task, CompatibilityError};
use taskwarrior_core::Task;
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PreparedTaskWrite {
    pub task_id: Uuid,
    pub operation_count: usize,
}

pub trait CompatibilityGateway {
    fn prepare_task_write(
        &self,
        task: &Task,
    ) -> Result<PreparedTaskWrite, CompatibilityError>;
}

#[derive(Default)]
pub struct TaskwarriorCompatibilityGateway;

impl CompatibilityGateway for TaskwarriorCompatibilityGateway {
    fn prepare_task_write(
        &self,
        task: &Task,
    ) -> Result<PreparedTaskWrite, CompatibilityError> {
        let encoded = encode_task(task);

        Ok(PreparedTaskWrite {
            task_id: task.id,
            operation_count: encoded.operations.len(),
        })
    }
}

pub trait SyncCoordinator {
    fn record_task_write(
        &mut self,
        write: PreparedTaskWrite,
    ) -> Result<(), String>;
}

#[derive(Default)]
pub struct InMemorySyncCoordinator {
    writes: Vec<PreparedTaskWrite>,
}

impl InMemorySyncCoordinator {
    pub fn writes(&self) -> &[PreparedTaskWrite] {
        &self.writes
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
}
