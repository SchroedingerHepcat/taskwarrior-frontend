//! Taskwarrior compatibility boundary types for the spike.

use core::Task;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskwarriorRecord {
    pub description: String,
}

impl TaskwarriorRecord {
    pub fn into_task(self, id: impl Into<String>) -> Task {
        Task::new(id, self.description)
    }
}

#[cfg(test)]
mod tests {
    use super::TaskwarriorRecord;

    #[test]
    fn converts_record_into_core_task() {
        let record = TaskwarriorRecord {
            description: "Recurring support comes later".to_string(),
        };

        let task = record.into_task("task-compat-1");

        assert_eq!(task.id, "task-compat-1");
        assert_eq!(task.description, "Recurring support comes later");
    }
}
