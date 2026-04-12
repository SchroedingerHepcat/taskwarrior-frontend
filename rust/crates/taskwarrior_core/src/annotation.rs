use chrono::{DateTime, Utc};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Annotation {
    pub entry: DateTime<Utc>,
    pub description: String,
}

impl Annotation {
    pub fn new(
        entry: DateTime<Utc>,
        description: impl Into<String>,
    ) -> Self {
        Self {
            entry,
            description: description.into(),
        }
    }
}
