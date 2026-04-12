use std::collections::BTreeMap;
use taskwarrior_core::Task;
use uuid::Uuid;

pub trait TaskRepository {
    fn get(
        &self,
        id: Uuid,
    ) -> Option<Task>;
    fn list(&self) -> Vec<Task>;
    fn upsert(
        &mut self,
        task: Task,
    );
}

#[derive(Default)]
pub struct InMemoryTaskRepository {
    tasks: BTreeMap<Uuid, Task>,
}

impl TaskRepository for InMemoryTaskRepository {
    fn get(
        &self,
        id: Uuid,
    ) -> Option<Task> {
        self.tasks.get(&id).cloned()
    }

    fn list(&self) -> Vec<Task> {
        self.tasks.values().cloned().collect()
    }

    fn upsert(
        &mut self,
        task: Task,
    ) {
        self.tasks.insert(task.id, task);
    }
}
