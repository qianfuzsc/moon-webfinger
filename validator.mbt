///|
/// RFC semantic validation of parsed JRDs.
///
/// The parser (`parser.mbt` / `json_adapter.mbt`) enforces JSON member
/// *types* and limits. This module enforces the *semantic* constraints
/// that RFC 7033 places on a JRD, separated into three severity levels:
///
/// * `Error` — violations of RFC MUSTs (e.g. `subject` and `aliases`
///   must be URIs; `properties` names must be URIs; `rel` must be a URI
///   or registered relation type; `href` must be a URI);
/// * `Warning` — violations of RFC SHOULDs that are explicitly not
///   hard errors (e.g. the subject SHOULD be present per Section 4.4.1);
/// * `Info` — permitted variations the caller may want to know about
///   (e.g. a subject that differs from the queried resource, which RFC
///   7033 Section 4.4.1 explicitly allows).
///
/// `validate_jrd` collects every issue; `validate_jrd_all` reports
/// whether any Error-severity issue exists. Validation never modifies
/// the model and never follows any link.

///|
/// Severity of a validation issue.
pub enum ValidationSeverity {
  Error
  Warning
  Info
}

///|
pub impl Show for ValidationSeverity with fn to_string(self) -> String {
  match self {
    Error => "Error"
    Warning => "Warning"
    Info => "Info"
  }
}

///|
/// A single validation issue. `code` is a stable machine-readable name
/// (e.g. `MissingSubject`), `message` a human-readable description.
pub struct ValidationIssue {
  severity : ValidationSeverity
  code : String
  message : String
}

///|
/// The severity name, for consumer packages that cannot match the enum.
pub fn ValidationIssue::severity_name(self : ValidationIssue) -> String {
  Show::to_string(self.severity)
}

///|
/// Internal: RFC 5646 basic-syntax check for a language tag: a primary
/// subtag of 1..8 ASCII letters followed by zero or more subtags of
/// 1..8 ASCII letters or digits, or the reserved tag `und`. This is a
/// syntactic check only; full RFC 5646 registry validation is out of
/// scope.
fn is_plausible_language_tag(tag : String) -> Bool {
  if tag == "und" {
    return true
  }
  let mut subtag_len = 0
  let mut subtag_index = 0
  let mut i = 0
  while i < tag.length() {
    let u = tag[i]
    if u == 45 {
      if subtag_len == 0 {
        return false
      }
      subtag_index = subtag_index + 1
      subtag_len = 0
    } else if is_ascii_alpha_u16(u) {
      subtag_len = subtag_len + 1
    } else if is_ascii_digit_u16(u) {
      if subtag_index == 0 {
        return false
      }
      subtag_len = subtag_len + 1
    } else {
      return false
    }
    if subtag_len > 8 {
      return false
    }
    i = i + 1
  }
  subtag_len > 0
}

///|
/// Whether a language tag (or `und`) passes the RFC 5646 basic syntax
/// check used by the validator and builders.
pub fn check_language_tag(tag : String) -> Bool {
  is_plausible_language_tag(tag)
}

///|
/// Internal: collect the top-level property names in sorted order.
fn sorted_property_names(m : Map[String, PropertyValue]) -> Array[String] {
  let keys : Array[String] = []
  for k in m.keys() {
    keys.push(k)
  }
  keys.sort()
  keys
}

///|
/// Validate a parsed JRD and collect all issues (Error, Warning and
/// Info) in a deterministic order.
pub fn validate_jrd(jrd : JsonResourceDescriptor) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  match jrd.subject {
    None =>
      issues.push({
        severity: Warning,
        code: "MissingSubject",
        message: "the JRD has no subject member (RFC 7033 Section 4.4.1: SHOULD be present)",
      })
    Some(subject) =>
      match check_absolute_uri(subject) {
        Ok(_) => ()
        Err(_) =>
          issues.push({
            severity: Error,
            code: "InvalidSubjectUri",
            message: "subject is not an absolute URI: \{subject}",
          })
      }
  }
  for alias in jrd.aliases {
    match check_absolute_uri(alias) {
      Ok(_) => ()
      Err(_) =>
        issues.push({
          severity: Error,
          code: "InvalidAliasUri",
          message: "alias is not an absolute URI: \{alias}",
        })
    }
  }
  for name in sorted_property_names(jrd.properties) {
    match check_absolute_uri(name) {
      Ok(_) => ()
      Err(_) =>
        issues.push({
          severity: Error,
          code: "InvalidPropertyUri",
          message: "property name is not a URI: \{name}",
        })
    }
  }
  for link in jrd.links {
    match check_rel_value(link.rel) {
      Ok(_) => ()
      Err(_) =>
        issues.push({
          severity: Error,
          code: "InvalidLinkRelValue",
          message: "link rel is neither a URI nor a registered relation type: \{link.rel}",
        })
    }
    match link.href {
      None => ()
      Some(href) =>
        match check_absolute_uri(href) {
          Ok(_) => ()
          Err(_) =>
            issues.push({
              severity: Error,
              code: "InvalidLinkHrefUri",
              message: "link href is not an absolute URI: \{href}",
            })
        }
    }
    for tag in sorted_title_names(link.titles) {
      if !is_plausible_language_tag(tag) {
        issues.push({
          severity: Warning,
          code: "InvalidTitleLanguageTag",
          message: "title key is not a plausible language tag (RFC 5646) or 'und': \{tag}",
        })
      }
    }
    for name in sorted_property_names(link.properties) {
      match check_absolute_uri(name) {
        Ok(_) => ()
        Err(_) =>
          issues.push({
            severity: Error,
            code: "InvalidPropertyUri",
            message: "link property name is not a URI: \{name}",
          })
      }
    }
  }
  issues
}

///|
/// Internal: sorted title language tags (for deterministic validation
/// output).
fn sorted_title_names(m : Map[String, String]) -> Array[String] {
  let keys : Array[String] = []
  for k in m.keys() {
    keys.push(k)
  }
  keys.sort()
  keys
}

///|
/// Whether a parsed JRD passes validation with no Error-severity issue.
/// Warnings (e.g. a missing subject) and Info issues do not fail this
/// check, matching the RFC's own SHOULD-level requirements.
pub fn validate_jrd_all(jrd : JsonResourceDescriptor) -> Bool {
  for issue in validate_jrd(jrd) {
    match issue.severity {
      Error => return false
      _ => ()
    }
  }
  true
}

///|
/// The first Error-severity issue, or `None` when the JRD is valid.
pub fn first_validation_error(jrd : JsonResourceDescriptor) -> ValidationIssue? {
  for issue in validate_jrd(jrd) {
    match issue.severity {
      Error => return Some(issue)
      _ => ()
    }
  }
  None
}

///|
/// Check a parsed JRD against the resource it was queried with.
///
/// RFC 7033 Section 4.4.1: the subject MAY differ from the queried
/// resource (identity changes, canonical forms), so a differing subject
/// is reported as Info, not as an error. A subject (or alias) equal to
/// the requested resource is also reported as Info for callers that
/// want to confirm the match.
pub fn validate_for_resource(
  jrd : JsonResourceDescriptor,
  requested_resource : String,
) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  match check_absolute_uri(requested_resource) {
    Ok(_) => ()
    Err(_) =>
      issues.push({
        severity: Error,
        code: "InvalidRequestedResource",
        message: "requested resource is not an absolute URI: \{requested_resource}",
      })
  }
  match jrd.subject {
    None =>
      issues.push({
        severity: Warning,
        code: "MissingSubject",
        message: "the JRD has no subject member (RFC 7033 Section 4.4.1: SHOULD be present)",
      })
    Some(subject) =>
      if subject == requested_resource {
        issues.push({
          severity: Info,
          code: "SubjectMatch",
          message: "subject equals the requested resource",
        })
      } else {
        issues.push({
          severity: Info,
          code: "SubjectMismatch",
          message: "subject differs from the requested resource; RFC 7033 Section 4.4.1 permits this",
        })
      }
  }
  for alias in jrd.aliases {
    if alias == requested_resource {
      issues.push({
        severity: Info,
        code: "AliasMatch",
        message: "an alias equals the requested resource",
      })
    }
  }
  issues
}
