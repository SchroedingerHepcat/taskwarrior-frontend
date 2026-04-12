//! Server-facing API boundary placeholders for the spike.

mod operations;
mod requests;

pub use operations::{
    add_task_dependency, compat_round_trip, create_task, healthcheck,
    query_tasks, sample_task, transition_task,
};
pub use requests::{CreateTaskRequest, TaskQuery, TransitionTaskRequest};
