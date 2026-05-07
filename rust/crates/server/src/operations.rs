use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use taskwarrior_core::{Task, TaskStatus};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ApiMethod {
    Get,
    Post,
    Put,
    Patch,
    Delete,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct ApiEndpoint {
    pub method: ApiMethod,
    pub path: &'static str,
    pub summary: &'static str,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct HealthResponse {
    pub status: &'static str,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ApiAnnotation {
    pub entry: DateTime<Utc>,
    pub description: String,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ApiTask {
    pub id: String,
    pub description: String,
    pub project: Option<String>,
    pub status: String,
    pub entry: Option<DateTime<Utc>>,
    pub modified: Option<DateTime<Utc>>,
    pub due: Option<DateTime<Utc>>,
    pub scheduled: Option<DateTime<Utc>>,
    pub end: Option<DateTime<Utc>>,
    pub wait: Option<DateTime<Utc>>,
    pub recurrence: Option<ApiRecurrence>,
    pub tags: Vec<String>,
    pub annotations: Vec<ApiAnnotation>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct TaskResponse {
    pub task: ApiTask,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
pub struct TaskListResponse {
    pub tasks: Vec<ApiTask>,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ApiRecurrence {
    pub recur: String,
    pub rtype: Option<String>,
    pub until: Option<DateTime<Utc>>,
    pub parent: Option<String>,
    pub mask: Option<String>,
    pub imask: Option<String>,
}

pub fn api_spec() -> &'static [ApiEndpoint] {
    &[
        ApiEndpoint {
            method: ApiMethod::Get,
            path: "/health",
            summary: "Health check",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks",
            summary: "Create task",
        },
        ApiEndpoint {
            method: ApiMethod::Get,
            path: "/tasks/{id}",
            summary: "Get task detail",
        },
        ApiEndpoint {
            method: ApiMethod::Patch,
            path: "/tasks/{id}",
            summary: "Update task fields",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/{id}/transition",
            summary: "Transition task status",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/{id}/board-transition",
            summary: "Move task between supported board lanes",
        },
        ApiEndpoint {
            method: ApiMethod::Post,
            path: "/tasks/query",
            summary: "Query tasks",
        },
        ApiEndpoint {
            method: ApiMethod::Get,
            path: "/views",
            summary: "List saved task views",
        },
        ApiEndpoint {
            method: ApiMethod::Put,
            path: "/views/{id}",
            summary: "Create or update saved task view",
        },
        ApiEndpoint {
            method: ApiMethod::Delete,
            path: "/views/{id}",
            summary: "Delete saved task view",
        },
    ]
}

pub fn healthcheck() -> &'static str {
    "ok"
}

pub fn map_task(task: Task) -> ApiTask {
    ApiTask {
        id: task.id.to_string(),
        description: task.description,
        project: task.project,
        status: status_label(&task.status).to_string(),
        entry: task.entry,
        modified: task.modified,
        due: task.due,
        scheduled: task.scheduled,
        end: task.end,
        wait: task.wait,
        recurrence: task.recurrence.map(|recurrence| ApiRecurrence {
            recur: recurrence.recur,
            rtype: recurrence.rtype,
            until: recurrence.until,
            parent: recurrence.parent.map(|parent| parent.to_string()),
            mask: recurrence.mask,
            imask: recurrence.imask,
        }),
        tags: task.tags.into_iter().collect(),
        annotations: task
            .annotations
            .into_iter()
            .map(|annotation| ApiAnnotation {
                entry: annotation.entry,
                description: annotation.description,
            })
            .collect(),
    }
}

pub fn status_label(status: &TaskStatus) -> &str {
    match status {
        TaskStatus::Pending => "pending",
        TaskStatus::Completed => "completed",
        TaskStatus::Deleted => "deleted",
        TaskStatus::Recurring => "recurring",
        TaskStatus::Unknown(other) => other.as_str(),
    }
}

pub fn parse_status(raw: &str) -> TaskStatus {
    match raw {
        "pending" => TaskStatus::Pending,
        "completed" => TaskStatus::Completed,
        "deleted" => TaskStatus::Deleted,
        "recurring" => TaskStatus::Recurring,
        other => TaskStatus::Unknown(other.to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::{api_spec, map_task, status_label, ApiMethod};
    use chrono::{TimeZone, Utc};
    use taskwarrior_core::{Annotation, Task, TaskStatus};
    use uuid::Uuid;

    fn timestamp(secs: i64) -> chrono::DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    #[test]
    fn api_spec_covers_health_and_task_operations() {
        let endpoints = api_spec();

        assert_eq!(endpoints.len(), 10);
        assert!(endpoints.contains(&super::ApiEndpoint {
            method: ApiMethod::Get,
            path: "/tasks/{id}",
            summary: "Get task detail",
        }));
    }

    #[test]
    fn maps_core_task_into_api_task() {
        let mut task = Task::new(Uuid::from_u128(1), "demo");
        task.project = Some("frontend".to_string());
        task.entry = Some(timestamp(10));
        task.add_tag("home");
        task.add_annotation(Annotation::new(timestamp(20), "note"));

        let api_task = map_task(task);

        assert_eq!(
            api_task.id,
            Uuid::from_u128(1).to_string()
        );
        assert_eq!(
            api_task.project,
            Some("frontend".to_string())
        );
        assert_eq!(api_task.tags, vec!["home".to_string()]);
        assert_eq!(api_task.annotations.len(), 1);
        assert_eq!(
            status_label(&TaskStatus::Pending),
            "pending"
        );
    }
}
