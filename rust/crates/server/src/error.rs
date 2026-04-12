use taskwarrior_compat::CompatibilityError;
use uuid::Uuid;

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ValidationError {
    EmptyDescription,
    MissingTaskChanges,
    EmptyRequiredTag,
    UnknownStatusInput,
    SelfDependency(Uuid),
}

#[derive(Debug, Eq, PartialEq)]
pub enum ServiceError {
    Validation(ValidationError),
    NotFound(Uuid),
    Compatibility(CompatibilityError),
    Sync(String),
}

impl From<ValidationError> for ServiceError {
    fn from(value: ValidationError) -> Self {
        Self::Validation(value)
    }
}

impl From<CompatibilityError> for ServiceError {
    fn from(value: CompatibilityError) -> Self {
        Self::Compatibility(value)
    }
}
