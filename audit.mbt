///|
/// Advisory audit of parsed JRDs and response contexts.
///
/// Audit findings are advisory observations for humans and tooling; they
/// are deliberately NOT protocol errors. A JRD can carry every audit
/// finding listed here and still be a conforming document, and a
/// response can raise a finding and still be a valid exchange — the
/// validator (`validator.mbt`) owns the hard RFC constraints.
///
/// Findings are produced in a deterministic order and never trigger any
/// network activity. Every finding has a stable `code`, a severity
/// (`Warning` or `Info`), and a one-line `message`.

///|
/// Severity of an audit finding.
pub enum AuditSeverity {
  Warning
  Info
}

///|
pub impl Show for AuditSeverity with fn to_string(self) -> String {
  match self {
    Warning => "Warning"
    Info => "Info"
  }
}

///|
/// A single advisory finding.
pub struct AuditFinding {
  code : String
  severity : AuditSeverity
  message : String
}

///|
/// The severity name, for consumer packages that cannot match the enum.
pub fn AuditFinding::severity_name(self : AuditFinding) -> String {
  self.severity.to_string()
}

///|
/// Internal: append a finding.
fn push_finding(
  findings : Array[AuditFinding],
  severity : AuditSeverity,
  code : String,
  message : String,
) -> Unit {
  findings.push({ severity, code, message })
}

///|
/// Internal: sorted keys of a Json object (extension members).
fn sorted_json_keys(m : Map[String, Json]) -> Array[String] {
  let keys : Array[String] = []
  for k in m.keys() {
    keys.push(k)
  }
  keys.sort()
  keys
}

///|
/// Internal: sorted keys of a property map.
fn sorted_prop_keys(m : Map[String, PropertyValue]) -> Array[String] {
  let keys : Array[String] = []
  for k in m.keys() {
    keys.push(k)
  }
  keys.sort()
  keys
}

///|
/// Internal: whether a URI-shaped string uses a risky scheme. Advisory
/// only: RFC 7033 imposes no scheme policy on hrefs or property URIs.
fn has_risky_scheme(s : String) -> Bool {
  match uri_scheme(s) {
    Some(scheme) =>
      scheme == "file" ||
      scheme == "data" ||
      scheme == "javascript" ||
      scheme == "vbscript" ||
      scheme == "ftp"
    None => false
  }
}

///|
/// Internal: duplicate detection helpers.
fn alias_is_duplicate(aliases : Array[String], index : Int) -> Bool {
  let mut i = 0
  while i < index {
    if aliases[i] == aliases[index] {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Internal: whether two links share rel + href.
fn same_rel_href(a : JrdLink, b : JrdLink) -> Bool {
  a.rel == b.rel && a.href == b.href
}

///|
/// Internal: whether two links share rel + type + href.
fn same_rel_type_href(a : JrdLink, b : JrdLink) -> Bool {
  a.rel == b.rel && a.media_type == b.media_type && a.href == b.href
}

///|
/// Internal: whether a link duplicates an earlier one (same rel + href,
/// and later same rel + type + href).
fn link_duplicates(
  links : Array[JrdLink],
  index : Int,
  with_type : Bool,
) -> Bool {
  let mut i = 0
  while i < index {
    if with_type {
      if same_rel_type_href(links[i], links[index]) {
        return true
      }
    } else if same_rel_href(links[i], links[index]) {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Audit a parsed JRD and return all advisory findings in a
/// deterministic order.
pub fn audit_jrd(jrd : JsonResourceDescriptor) -> Array[AuditFinding] {
  let findings : Array[AuditFinding] = []
  match jrd.subject {
    None =>
      push_finding(
        findings,
        Warning,
        "MissingSubject",
        "the JRD has no subject member (RFC 7033 Section 4.4.1: SHOULD be present)",
      )
    Some(_) => ()
  }
  if jrd.aliases.length() == 0 {
    push_finding(findings, Info, "NoAliases", "the JRD carries no aliases")
  } else {
    let mut i = 0
    while i < jrd.aliases.length() {
      if alias_is_duplicate(jrd.aliases, i) {
        push_finding(
          findings,
          Warning,
          "DuplicateAlias",
          "alias appears more than once: \{jrd.aliases[i]}",
        )
      }
      i = i + 1
    }
  }
  if jrd.links.length() == 0 {
    push_finding(
      findings,
      Info,
      "NoLinks",
      "the JRD carries no links (servers may return an empty or absent links array)",
    )
  } else {
    let mut i = 0
    while i < jrd.links.length() {
      let link = jrd.links[i]
      if link_duplicates(jrd.links, i, true) {
        push_finding(
          findings,
          Warning,
          "DuplicateLink",
          "link \{i} repeats an earlier link's rel, type and href (rel: \{link.rel})",
        )
      } else if link_duplicates(jrd.links, i, false) {
        push_finding(
          findings,
          Warning,
          "DuplicateRelHref",
          "link \{i} repeats an earlier link's rel and href (rel: \{link.rel})",
        )
      }
      match link.href {
        None => ()
        Some(href) => {
          match check_absolute_uri(href) {
            Ok(_) => ()
            Err(_) =>
              push_finding(
                findings,
                Warning,
                "RelativeHref",
                "link href is not an absolute URI (RFC 7033 Section 2: relative references are not used with WebFinger): \{href}",
              )
          }
          if scheme_is(href, "http") {
            push_finding(
              findings,
              Warning,
              "InsecureHttpHref",
              "link href uses the http scheme; RFC 7033 does not forbid this, but consider https: \{href}",
            )
          }
          if has_risky_scheme(href) {
            push_finding(
              findings,
              Warning,
              "SuspiciousHrefScheme",
              "link href uses a potentially risky URI scheme: \{href}",
            )
          }
        }
      }
      i = i + 1
    }
  }
  for name in sorted_prop_keys(jrd.properties) {
    if has_risky_scheme(name) {
      push_finding(
        findings,
        Warning,
        "SuspiciousPropertyUri",
        "property identifier uses a potentially risky URI scheme: \{name}",
      )
    }
  }
  if serialize_jrd(jrd).length() > 65536 {
    push_finding(
      findings,
      Info,
      "VeryLargeDescriptor",
      "the serialized JRD exceeds 64 KiB; consider tighter limits for hostile inputs",
    )
  }
  for name in sorted_json_keys(jrd.extensions) {
    push_finding(
      findings,
      Info,
      "UnknownTopLevelMember",
      "unknown top-level member '\{name}' ignored per RFC 7033 Section 4.4 and preserved for round-tripping",
    )
  }
  findings
}

///|
/// Audit a response context and return advisory findings about the
/// transport facts the caller observed. Mirrors
/// `validate_response_context`, but everything here is advisory.
pub fn audit_response(ctx : WebFingerResponseContext) -> Array[AuditFinding] {
  let findings : Array[AuditFinding] = []
  if !scheme_is(ctx.final_url, "https") {
    push_finding(
      findings,
      Warning,
      "NonHttpsContext",
      "final_url does not use the https scheme (RFC 7033 Section 4.2 requires HTTPS)",
    )
  }
  if ctx.status < 200 || ctx.status > 299 {
    push_finding(
      findings,
      Warning,
      "NonSuccessStatus",
      "status \{ctx.status} is outside the 2xx success range",
    )
  }
  match ctx.content_type {
    None =>
      push_finding(
        findings,
        Warning,
        "MissingContentType",
        "response carried no Content-Type; JRD responses must use \{JRD_MEDIA_TYPE}",
      )
    Some(ct) =>
      if !is_jrd_content_type(ct) {
        push_finding(
          findings,
          Warning,
          "UnexpectedContentType",
          "Content-Type \{ct} is not \{JRD_MEDIA_TYPE}",
        )
      }
  }
  match ctx.request_url {
    None => ()
    Some(request_url) =>
      match (origin_of(request_url), origin_of(ctx.final_url)) {
        (Some(request_origin), Some(final_origin)) =>
          if request_origin != final_origin {
            push_finding(
              findings,
              Info,
              "RedirectDetected",
              "final URL origin differs from the request origin (redirects are permitted when they stay on https)",
            )
          }
        _ => ()
      }
  }
  match ctx.body_bytes {
    Some(bytes) =>
      if bytes > 1048576 {
        push_finding(
          findings,
          Info,
          "LargeBody",
          "response body is \{bytes} bytes; consider the max_input_bytes limit when parsing",
        )
      }
    None => ()
  }
  findings
}
