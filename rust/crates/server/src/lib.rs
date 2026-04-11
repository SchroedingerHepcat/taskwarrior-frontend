//! Server-facing API boundary placeholders for the spike.

use core::Task;
use taskwarrior_compat::TaskwarriorRecord;

pub fn healthcheck() -> &'static str {
    "ok"
}

pub fn sample_task() -> Task {
    let record = TaskwarriorRecord {
        description: "Initial compatibility spike".to_string(),
    };

    record.into_task("server-sample")
}

#[cfg(test)]
mod tests {
    use super::{healthcheck, sample_task};

    #[test]
    fn healthcheck_is_stable() {
        assert_eq!(healthcheck(), "ok");
    }

    #[test]
    fn sample_task_is_constructed_via_compat_layer() {
        let task = sample_task();

        assert_eq!(task.id, "server-sample");
        assert_eq!(task.description, "Initial compatibility spike");
    }
}
