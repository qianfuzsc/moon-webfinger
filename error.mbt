///|
/// Structured errors for the moon-webfinger library.
///
/// Every public API in this package converts failures into
/// `Result[_, WebFingerError]`; nothing panics and nothing propagates a
/// bare `Error` to callers. Internally the package raises a single
/// `WebFingerError` suberror and converts it at each public boundary.
///
/// Errors carry four components:
///
/// * `stage` — which processing area produced the error,
/// * `kind` — the concrete error category,
/// * `offset` — a precise UTF-8 byte offset when one is known, otherwise
///   `None` (the underlying JSON parser does not expose byte offsets, so
///   JSON syntax errors report `None` rather than a fabricated offset),
/// * `context` — a human-readable, one-line description.
///
/// The `WebFingerErrorStage` and `WebFingerErrorKind` enums are read-only
/// for consumer packages: consumers compare them through
/// `stage_name()` / `kind_name()` and `to_string()`.

///|
/// The processing area that produced a `WebFingerError`.
pub enum WebFingerErrorStage {
  Input
  Json
  Request
  Uri
  Jrd
  Subject
  Alias
  Property
  Link
  Context
  Limit
  Builder
}

///|
pub impl Show for WebFingerErrorStage with fn to_string(self) -> String {
  match self {
    Input => "Input"
    Json => "Json"
    Request => "Request"
    Uri => "Uri"
    Jrd => "Jrd"
    Subject => "Subject"
    Alias => "Alias"
    Property => "Property"
    Link => "Link"
    Context => "Context"
    Limit => "Limit"
    Builder => "Builder"
  }
}

///|
/// The concrete error category of a `WebFingerError`.
pub enum WebFingerErrorKind {
  InvalidJson
  RootNotObject
  MissingResource
  InvalidResource
  InvalidUri
  InvalidPercentEncoding
  WrongMemberType
  MissingRequiredMember
  InvalidLink
  InvalidProperty
  InvalidContentType
  LimitExceeded
  DuplicateReservedExtension
  InvalidRelValue
  InvalidLanguageTag
  InvalidAcctUri
  InvalidOrigin
  NonHttpsOrigin
  InvalidHttpStatus
  NonHttpsFinalUrl
  EmptyInput
}

///|
pub impl Show for WebFingerErrorKind with fn to_string(self) -> String {
  match self {
    InvalidJson => "InvalidJson"
    RootNotObject => "RootNotObject"
    MissingResource => "MissingResource"
    InvalidResource => "InvalidResource"
    InvalidUri => "InvalidUri"
    InvalidPercentEncoding => "InvalidPercentEncoding"
    WrongMemberType => "WrongMemberType"
    MissingRequiredMember => "MissingRequiredMember"
    InvalidLink => "InvalidLink"
    InvalidProperty => "InvalidProperty"
    InvalidContentType => "InvalidContentType"
    LimitExceeded => "LimitExceeded"
    DuplicateReservedExtension => "DuplicateReservedExtension"
    InvalidRelValue => "InvalidRelValue"
    InvalidLanguageTag => "InvalidLanguageTag"
    InvalidAcctUri => "InvalidAcctUri"
    InvalidOrigin => "InvalidOrigin"
    NonHttpsOrigin => "NonHttpsOrigin"
    InvalidHttpStatus => "InvalidHttpStatus"
    NonHttpsFinalUrl => "NonHttpsFinalUrl"
    EmptyInput => "EmptyInput"
  }
}

///|
/// The single structured error type of this package.
pub suberror WebFingerError {
  WebFingerError(WebFingerErrorStage, WebFingerErrorKind, Int?, String)
}

///|
/// The processing area of this error.
pub fn WebFingerError::stage(self : WebFingerError) -> WebFingerErrorStage {
  match self {
    WebFingerError(stage, _, _, _) => stage
  }
}

///|
/// The concrete category of this error.
pub fn WebFingerError::kind(self : WebFingerError) -> WebFingerErrorKind {
  match self {
    WebFingerError(_, kind, _, _) => kind
  }
}

///|
/// A precise UTF-8 byte offset into the original input, or `None` when the
/// failing component cannot report one (notably JSON syntax errors).
pub fn WebFingerError::offset(self : WebFingerError) -> Int? {
  match self {
    WebFingerError(_, _, offset, _) => offset
  }
}

///|
/// A human-readable, one-line description of the failure.
pub fn WebFingerError::context(self : WebFingerError) -> String {
  match self {
    WebFingerError(_, _, _, context) => context
  }
}

///|
/// The stage name, for consumer packages that cannot match the enum.
pub fn WebFingerError::stage_name(self : WebFingerError) -> String {
  Show::to_string(self.stage())
}

///|
/// The kind name, for consumer packages that cannot match the enum.
pub fn WebFingerError::kind_name(self : WebFingerError) -> String {
  Show::to_string(self.kind())
}

///|
/// A single-line rendering like
/// `Uri error InvalidUri: not an absolute URI (offset: None)`.
pub fn WebFingerError::to_display(self : WebFingerError) -> String {
  match self.offset() {
    Some(n) =>
      "\{self.stage_name()} error \{self.kind_name()}: \{self.context()} (offset: \{n})"
    None =>
      "\{self.stage_name()} error \{self.kind_name()}: \{self.context()} (offset: None)"
  }
}

///|
/// Internal: unwrap a caught `Error` back into `WebFingerError`. Every
/// public boundary in this package only ever raises `WebFingerError`; a
/// foreign error reaching this point is an internal bug.
fn unwrap_webfinger_error(e : Error) -> WebFingerError {
  match e {
    WebFingerError(stage, kind, offset, context) =>
      WebFingerError(stage, kind, offset, context)
    _ =>
      abort(
        "internal error: unexpected non-WebFingerError propagated to a Result boundary",
      )
  }
}
