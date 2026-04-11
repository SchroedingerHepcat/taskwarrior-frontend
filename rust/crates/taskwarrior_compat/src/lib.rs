//! Taskwarrior compatibility boundary for the compatibility spike.
//!
//! This crate prefers the existing `taskchampion` library for task-model
//! property names and low-level operation generation instead of inventing
//! custom storage behavior in this repository.

use std::error::Error;
use std::fmt::{Display, Formatter};
use taskchampion::chrono::{DateTime, TimeZone, Utc};
use taskchampion::{Operations, TaskData};
use taskwarrior_core::{Annotation, Task, TaskStatus};

const PROP_DESCRIPTION: &str = "description";
const PROP_STATUS: &str = "status";
const PROP_ENTRY: &str = "entry";
const PROP_MODIFIED: &str = "modified";
const PROP_DUE: &str = "due";
const PROP_END: &str = "end";
const PROP_WAIT: &str = "wait";
const ANNOTATION_PREFIX: &str = "annotation_";
const TAG_PREFIX: &str = "tag_";

#[derive(Debug, Eq, PartialEq)]
pub enum CompatibilityError {
    InvalidTimestamp { property: String, value: String },
}

impl Display for CompatibilityError {
    fn fmt(
        &self,
        f: &mut Formatter<'_>,
    ) -> std::fmt::Result {
        match self {
            Self::InvalidTimestamp { property, value } => {
                write!(
                    f,
                    "invalid timestamp for {property}: {value}"
                )
            }
        }
    }
}

impl Error for CompatibilityError {}

#[derive(Debug)]
pub struct EncodedTask {
    pub task_data: TaskData,
    pub operations: Operations,
}

pub fn decode_task(task_data: &TaskData) -> Result<Task, CompatibilityError> {
    let mut task = Task::new(
        task_data.get_uuid(),
        task_data
            .get(PROP_DESCRIPTION)
            .unwrap_or_default(),
    );
    task.status = decode_status(task_data.get(PROP_STATUS));
    task.entry = decode_timestamp(task_data, PROP_ENTRY)?;
    task.modified = decode_timestamp(task_data, PROP_MODIFIED)?;
    task.due = decode_timestamp(task_data, PROP_DUE)?;
    task.end = decode_timestamp(task_data, PROP_END)?;
    task.wait = decode_timestamp(task_data, PROP_WAIT)?;

    for (key, value) in task_data.iter() {
        if let Some(tag) = key.strip_prefix(TAG_PREFIX) {
            task.add_tag(tag);
            continue;
        }

        if let Some(raw_entry) = key.strip_prefix(ANNOTATION_PREFIX) {
            task.add_annotation(Annotation::new(
                parse_timestamp(key, raw_entry)?,
                value.clone(),
            ));
            continue;
        }

        if !is_known_property(key) {
            task.set_user_defined_attribute(key.clone(), value.clone());
        }
    }

    Ok(task)
}

pub fn encode_task(task: &Task) -> EncodedTask {
    let mut operations = Operations::new();
    let mut task_data = TaskData::create(task.id, &mut operations);

    task_data.update(
        PROP_DESCRIPTION,
        Some(task.description.clone()),
        &mut operations,
    );
    task_data.update(
        PROP_STATUS,
        Some(encode_status(&task.status).to_string()),
        &mut operations,
    );
    set_timestamp(
        &mut task_data,
        PROP_ENTRY,
        task.entry,
        &mut operations,
    );
    set_timestamp(
        &mut task_data,
        PROP_MODIFIED,
        task.modified,
        &mut operations,
    );
    set_timestamp(
        &mut task_data,
        PROP_DUE,
        task.due,
        &mut operations,
    );
    set_timestamp(
        &mut task_data,
        PROP_END,
        task.end,
        &mut operations,
    );
    set_timestamp(
        &mut task_data,
        PROP_WAIT,
        task.wait,
        &mut operations,
    );

    for annotation in &task.annotations {
        let key = format!(
            "{ANNOTATION_PREFIX}{}",
            annotation.entry.timestamp(),
        );
        task_data.update(
            key,
            Some(annotation.description.clone()),
            &mut operations,
        );
    }

    for tag in &task.tags {
        task_data.update(
            format!("{TAG_PREFIX}{tag}"),
            Some(String::new()),
            &mut operations,
        );
    }

    for (key, value) in &task.user_defined_attributes {
        task_data.update(
            key.clone(),
            Some(value.clone()),
            &mut operations,
        );
    }

    EncodedTask {
        task_data,
        operations,
    }
}

fn decode_status(raw: Option<&str>) -> TaskStatus {
    match raw.unwrap_or("pending") {
        "pending" => TaskStatus::Pending,
        "completed" => TaskStatus::Completed,
        "deleted" => TaskStatus::Deleted,
        "recurring" => TaskStatus::Recurring,
        other => TaskStatus::Unknown(other.to_string()),
    }
}

fn encode_status(status: &TaskStatus) -> &str {
    match status {
        TaskStatus::Pending => "pending",
        TaskStatus::Completed => "completed",
        TaskStatus::Deleted => "deleted",
        TaskStatus::Recurring => "recurring",
        TaskStatus::Unknown(other) => other.as_str(),
    }
}

fn decode_timestamp(
    task_data: &TaskData,
    property: &str,
) -> Result<Option<DateTime<Utc>>, CompatibilityError> {
    task_data
        .get(property)
        .map(|value| parse_timestamp(property, value))
        .transpose()
}

fn parse_timestamp(
    property: impl Into<String>,
    value: &str,
) -> Result<DateTime<Utc>, CompatibilityError> {
    let property = property.into();
    let seconds = value.parse::<i64>().map_err(|_| {
        CompatibilityError::InvalidTimestamp {
            property: property.clone(),
            value: value.to_string(),
        }
    })?;

    Utc.timestamp_opt(seconds, 0)
        .single()
        .ok_or_else(
            || CompatibilityError::InvalidTimestamp {
                property,
                value: value.to_string(),
            },
        )
}

fn set_timestamp(
    task_data: &mut TaskData,
    property: &str,
    value: Option<DateTime<Utc>>,
    operations: &mut Operations,
) {
    task_data.update(
        property,
        value.map(|timestamp| timestamp.timestamp().to_string()),
        operations,
    );
}

fn is_known_property(key: &str) -> bool {
    matches!(
        key,
        PROP_DESCRIPTION
            | PROP_STATUS
            | PROP_ENTRY
            | PROP_MODIFIED
            | PROP_DUE
            | PROP_END
            | PROP_WAIT
    ) || key.starts_with(ANNOTATION_PREFIX)
        || key.starts_with(TAG_PREFIX)
}

#[cfg(test)]
mod tests {
    use super::{
        decode_task, encode_task, CompatibilityError, ANNOTATION_PREFIX,
        PROP_DESCRIPTION, PROP_DUE, PROP_END, PROP_ENTRY, PROP_MODIFIED,
        PROP_STATUS, PROP_WAIT, TAG_PREFIX,
    };
    use taskchampion::chrono::{DateTime, TimeZone, Utc};
    use taskchampion::{Operation, Operations, TaskData, Uuid};
    use taskwarrior_core::{Annotation, Task, TaskStatus};

    fn timestamp(secs: i64) -> DateTime<Utc> {
        Utc.timestamp_opt(secs, 0).single().unwrap()
    }

    fn build_task_data(
        uuid: Uuid,
        updates: &[(&str, &str)],
    ) -> TaskData {
        let mut operations = Operations::new();
        let mut task_data = TaskData::create(uuid, &mut operations);

        for (property, value) in updates {
            task_data.update(
                *property,
                Some((*value).to_string()),
                &mut operations,
            );
        }

        task_data
    }

    #[test]
    fn decode_maps_taskchampion_fields_into_core_task() {
        let task_data = build_task_data(
            Uuid::from_u128(10),
            &[
                (
                    PROP_DESCRIPTION,
                    "Plan compatibility spike",
                ),
                (PROP_STATUS, "recurring"),
                (PROP_ENTRY, "100"),
                (PROP_MODIFIED, "150"),
                (PROP_DUE, "175"),
                (PROP_END, "190"),
                (PROP_WAIT, "200"),
                (
                    &format!("{ANNOTATION_PREFIX}150"),
                    "first note",
                ),
                (&format!("{TAG_PREFIX}home"), ""),
                ("jira.id", "TW-1"),
            ],
        );

        let task = decode_task(&task_data).unwrap();

        assert_eq!(task.id, Uuid::from_u128(10));
        assert_eq!(
            task.description,
            "Plan compatibility spike"
        );
        assert_eq!(task.status, TaskStatus::Recurring);
        assert_eq!(task.entry, Some(timestamp(100)));
        assert_eq!(task.modified, Some(timestamp(150)));
        assert_eq!(task.due, Some(timestamp(175)));
        assert_eq!(task.end, Some(timestamp(190)));
        assert_eq!(task.wait, Some(timestamp(200)));
        assert_eq!(
            task.annotations,
            vec![Annotation::new(
                timestamp(150),
                "first note"
            )],
        );
        assert!(task.tags.contains("home"));
        assert_eq!(
            task.user_defined_attributes.get("jira.id"),
            Some(&"TW-1".to_string()),
        );
    }

    #[test]
    fn decode_preserves_unknown_status_for_forward_compatibility() {
        let task_data = build_task_data(
            Uuid::from_u128(11),
            &[
                (
                    PROP_DESCRIPTION,
                    "Forward compatibility",
                ),
                (PROP_STATUS, "blocked-elsewhere"),
            ],
        );

        let task = decode_task(&task_data).unwrap();

        assert_eq!(
            task.status,
            TaskStatus::Unknown("blocked-elsewhere".to_string()),
        );
    }

    #[test]
    fn decode_rejects_invalid_timestamps() {
        let task_data = build_task_data(
            Uuid::from_u128(12),
            &[
                (PROP_DESCRIPTION, "Bad time"),
                (PROP_WAIT, "not-a-timestamp"),
            ],
        );

        let err = decode_task(&task_data).unwrap_err();

        assert_eq!(
            err,
            CompatibilityError::InvalidTimestamp {
                property: PROP_WAIT.to_string(),
                value: "not-a-timestamp".to_string(),
            },
        );
    }

    #[test]
    fn encode_generates_taskchampion_task_data_and_operations() {
        let mut task = Task::new(
            Uuid::from_u128(13),
            "Implement conversions",
        );
        task.status = TaskStatus::Completed;
        task.entry = Some(timestamp(100));
        task.modified = Some(timestamp(150));
        task.due = Some(timestamp(175));
        task.end = Some(timestamp(190));
        task.wait = Some(timestamp(200));
        task.add_annotation(Annotation::new(timestamp(150), "done"));
        task.add_tag("work");
        task.set_user_defined_attribute("jira.id", "TW-13");

        let encoded = encode_task(&task);

        assert_eq!(
            encoded.task_data.get_uuid(),
            Uuid::from_u128(13)
        );
        assert_eq!(
            encoded.task_data.get(PROP_DESCRIPTION),
            Some("Implement conversions"),
        );
        assert_eq!(
            encoded.task_data.get(PROP_STATUS),
            Some("completed")
        );
        assert_eq!(
            encoded.task_data.get(PROP_ENTRY),
            Some("100")
        );
        assert_eq!(
            encoded.task_data.get(PROP_MODIFIED),
            Some("150")
        );
        assert_eq!(
            encoded.task_data.get(PROP_DUE),
            Some("175")
        );
        assert_eq!(
            encoded.task_data.get(PROP_END),
            Some("190")
        );
        assert_eq!(
            encoded.task_data.get(PROP_WAIT),
            Some("200")
        );
        assert_eq!(
            encoded
                .task_data
                .get(format!("{ANNOTATION_PREFIX}150")),
            Some("done"),
        );
        assert_eq!(
            encoded.task_data.get(format!("{TAG_PREFIX}work")),
            Some(""),
        );
        assert_eq!(
            encoded.task_data.get("jira.id"),
            Some("TW-13")
        );
        assert!(matches!(
            encoded.operations.first(),
            Some(Operation::Create {
                uuid
            }) if *uuid == Uuid::from_u128(13)
        ));
    }

    #[test]
    fn core_tasks_round_trip_through_taskchampion_data() {
        let mut task = Task::new(Uuid::from_u128(14), "Round trip");
        task.status = TaskStatus::Unknown("future-state".to_string());
        task.entry = Some(timestamp(10));
        task.modified = Some(timestamp(11));
        task.due = Some(timestamp(12));
        task.end = Some(timestamp(13));
        task.wait = Some(timestamp(20));
        task.add_annotation(Annotation::new(timestamp(15), "kept"));
        task.add_tag("home");
        task.set_user_defined_attribute("jira.id", "TW-14");

        let encoded = encode_task(&task);
        let decoded = decode_task(&encoded.task_data).unwrap();

        assert_eq!(decoded, task);
    }
}
