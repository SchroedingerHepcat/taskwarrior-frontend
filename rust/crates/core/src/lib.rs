//! Core task domain types for the compatibility spike.

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Task {
    pub id: String,
    pub description: String,
}

impl Task {
    pub fn new(id: impl Into<String>, description: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            description: description.into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::Task;

    #[test]
    fn constructs_task_from_owned_values() {
        let task = Task::new("task-1", "Compatibility spike");

        assert_eq!(task.id, "task-1");
        assert_eq!(task.description, "Compatibility spike");
    }
}
