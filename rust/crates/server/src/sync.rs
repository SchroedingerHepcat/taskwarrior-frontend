use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PreparedTaskWrite {
    pub task_id: Uuid,
    pub operation_count: usize,
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
