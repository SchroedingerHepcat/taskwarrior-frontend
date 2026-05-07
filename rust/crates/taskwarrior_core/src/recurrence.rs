use chrono::{DateTime, Utc};
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TaskRecurrence {
    pub recur: String,
    pub rtype: Option<String>,
    pub until: Option<DateTime<Utc>>,
    pub parent: Option<Uuid>,
    pub mask: Option<String>,
    pub imask: Option<String>,
}

impl TaskRecurrence {
    pub fn new(recur: impl Into<String>) -> Self {
        Self {
            recur: recur.into(),
            rtype: None,
            until: None,
            parent: None,
            mask: None,
            imask: None,
        }
    }
}
