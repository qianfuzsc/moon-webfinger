///|
/// Lightweight URI checks for the WebFinger scope.
///
/// This is deliberately NOT a complete RFC 3986 URI resolver. It covers
/// only what WebFinger needs (RFC 7033 Sections 2, 4.1, 4.4):
///
/// * a WebFinger `resource` must be an absolute URI — RFC 7033 Section 2
///   says relative references are not used with WebFinger;
/// * a URI must not contain spaces or control characters;
/// * every `%` must begin a well-formed `%XX` escape;
/// * non-ASCII characters are rejected (they must be percent-encoded;
///   full IDNA/IRI handling is out of scope, see `docs/limitations.md`);
/// * the scheme must match RFC 3986 `scheme = ALPHA *( ALPHA / DIGIT /
///   "+" / "-" / "." )`.
///
/// `check_absolute_uri` accepts any scheme: RFC 7033 Section 4.5 is
/// neutral about the scheme of the query target (`acct:`, `mailto:`,
/// `http:`, `https:`, `urn:`, `tag:` and others are all fine).

///|
/// Internal: RFC 3986 scheme character check (first position).
fn is_scheme_start_u16(u : UInt16) -> Bool {
  is_ascii_alpha_u16(u)
}

///|
/// Internal: RFC 3986 scheme character check (subsequent positions).
fn is_scheme_char_u16(u : UInt16) -> Bool {
  is_ascii_alpha_u16(u) ||
  is_ascii_digit_u16(u) ||
  u == 43 ||
  u == 45 ||
  u == 46
}

///|
/// Internal: whether a code unit is a C0/C1 control or a space, i.e.
/// never legal unescaped in a URI.
fn is_uri_forbidden_u16(u : UInt16) -> Bool {
  u < 0x20 || u == 0x20 || (u >= 0x7F && u <= 0x9F)
}

///|
/// Internal: scan a string for raw percent escapes; every `%` must be
/// followed by two ASCII hex digits. Returns the offending offset or
/// `None` when the string is well-formed.
fn malformed_percent_offset(s : String) -> Int? {
  let mut i = 0
  while i < s.length() {
    let u = s[i]
    if u == 37 {
      if i + 2 >= s.length() {
        return Some(i)
      }
      match (hex_value_u16(s[i + 1]), hex_value_u16(s[i + 2])) {
        (Some(_), Some(_)) => i = i + 3
        _ => return Some(i)
      }
    } else {
      i = i + 1
    }
  }
  None
}

///|
/// Internal: find the scheme terminator `:`; returns the index of `:`
/// or `None`.
fn scheme_colon_offset(s : String) -> Int? {
  let mut i = 0
  while i < s.length() {
    let u = s[i]
    if u == 58 {
      return Some(i)
    }
    if !is_scheme_char_u16(u) {
      return None
    }
    i = i + 1
  }
  None
}

///|
/// Check that `s` is an absolute URI within the WebFinger scope.
/// Errors use stage `Uri` and kind `InvalidUri` (or `InvalidPercentEncoding`
/// for bad escapes).
pub fn check_absolute_uri(s : String) -> Result[Unit, WebFingerError] {
  try {
    check_absolute_uri_inner(s)
    Ok(())
  } catch {
    e => Err(unwrap_webfinger_error(e))
  }
}

///|
/// Internal raise-based version of `check_absolute_uri`.
fn check_absolute_uri_inner(s : String) -> Unit raise {
  if s.length() == 0 {
    raise WebFingerError(Uri, InvalidUri, None, "empty string is not a URI")
  }
  let mut i = 0
  let mut saw_forbidden = false
  let mut saw_non_ascii = false
  while i < s.length() {
    let u = s[i]
    if is_uri_forbidden_u16(u) {
      saw_forbidden = true
    }
    if u > 0x7F {
      saw_non_ascii = true
    }
    i = i + 1
  }
  if saw_forbidden {
    raise WebFingerError(
      Uri,
      InvalidUri,
      None,
      "URI must not contain spaces or control characters",
    )
  }
  if saw_non_ascii {
    raise WebFingerError(
      Uri,
      InvalidUri,
      None,
      "URI must be ASCII; percent-encode non-ASCII characters",
    )
  }
  match malformed_percent_offset(s) {
    Some(off) =>
      raise WebFingerError(
        Uri,
        InvalidPercentEncoding,
        Some(off),
        "malformed percent escape",
      )
    None => ()
  }
  // Scheme: the first character must start a scheme and a ':' must
  // terminate it. Anything else is a relative reference (not used with
  // WebFinger) or not a URI at all.
  if !is_scheme_start_u16(s[0]) {
    raise WebFingerError(
      Uri,
      InvalidUri,
      Some(0),
      "not an absolute URI: missing scheme",
    )
  }
  match scheme_colon_offset(s) {
    Some(colon) =>
      if colon <= 0 {
        raise WebFingerError(Uri, InvalidUri, None, "empty URI scheme")
      }
    None =>
      raise WebFingerError(
        Uri,
        InvalidUri,
        None,
        "not an absolute URI: missing ':' after scheme",
      )
  }
}

///|
/// Extract the scheme of a URI-shaped string (the part before `:`),
/// lowercased, or `None` when no valid scheme is present. Does not
/// validate the rest of the string.
pub fn uri_scheme(s : String) -> String? {
  match scheme_colon_offset(s) {
    Some(0) => None
    Some(n) =>
      if is_scheme_start_u16(s[0]) {
        Some(s[0:n].to_lower().to_owned())
      } else {
        None
      }
    None => None
  }
}

///|
/// Case-insensitive scheme comparison.
pub fn scheme_is(s : String, scheme : String) -> Bool {
  match uri_scheme(s) {
    Some(actual) => actual == scheme.to_lower()
    None => false
  }
}

///|
/// Internal: whether a string is a plausible DNS domain name within the
/// WebFinger scope: ASCII letters, digits, hyphens and dots; non-empty
/// labels; no label may start or end with a hyphen; the final label must
/// not be all digits (an IPv4 address literal is not a domain name);
/// port and userinfo are rejected. IDN (U-labels) is out of scope:
/// internationalized hosts must be given as A-labels.
fn is_domain_name(s : String) -> Bool {
  if s.length() == 0 || s.length() > 253 {
    return false
  }
  let mut label_len = 0
  let mut i = 0
  while i < s.length() {
    let u = s[i]
    if u == 46 {
      if label_len == 0 {
        return false
      }
      label_len = 0
    } else if is_ascii_alpha_u16(u) || is_ascii_digit_u16(u) || u == 45 {
      if u == 45 && label_len == 0 {
        return false
      }
      if u == 45 && i + 1 >= s.length() {
        return false
      }
      if u == 45 && i + 1 < s.length() && s[i + 1] == 46 {
        return false
      }
      label_len = label_len + 1
    } else {
      return false
    }
    i = i + 1
  }
  if label_len == 0 {
    return false
  }
  // The final label must not be all digits: that is an IPv4 literal,
  // not a domain name (RFC 7565 wants a DNS domain name here).
  let mut last_dot = -1
  let mut k = 0
  while k < s.length() {
    if s[k] == 46 {
      last_dot = k
    }
    k = k + 1
  }
  let mut all_digits = true
  let mut m = last_dot + 1
  while m < s.length() {
    if !is_ascii_digit_u16(s[m]) {
      all_digits = false
    }
    m = m + 1
  }
  if all_digits {
    false
  } else {
    true
  }
}

///|
/// Check that `host` is a plausible DNS domain name for use in `acct`
/// URIs and WebFinger origins. Advisory-level strictness: this is a
/// conservative syntactic heuristic, not a resolver.
pub fn check_hostname(host : String) -> Result[Unit, WebFingerError] {
  if host.length() == 0 {
    return Err(WebFingerError(Uri, InvalidUri, None, "empty host"))
  }
  if host.contains("[") || host.contains("]") || host.contains(":") {
    return Err(
      WebFingerError(
        Uri,
        InvalidUri,
        None,
        "host must be a domain name, not an IP literal or host:port",
      ),
    )
  }
  if !is_domain_name(host) {
    return Err(WebFingerError(Uri, InvalidUri, None, "invalid domain name"))
  }
  Ok(())
}
