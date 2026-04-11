//! Server-facing API boundary placeholders for the spike.

use taskwarrior_core::Task;
use uuid::Uuid;

pub fn healthcheck() -> &'static str {
    "ok"
}

pub fn sample_task() -> Task {
    Task::new(Uuid::from_u128(1), "Initial compatibility spike")
}

#[cfg(test)]
mod tests {
    use super::{healthcheck, sample_task};
    use uuid::Uuid;

    #[test]
    fn healthcheck_is_stable() {
        assert_eq!(healthcheck(), "ok");
    }

    #[test]
    fn sample_task_is_constructed_via_compat_layer() {
        let task = sample_task();

        assert_eq!(task.id, Uuid::from_u128(1));
        assert_eq!(task.description, "Initial compatibility spike");
    }
}
