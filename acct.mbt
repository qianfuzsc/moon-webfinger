///|
/// Minimal `acct` URI support (RFC 7565), limited to what WebFinger
/// actually needs.
///
/// RFC 7565 Section 7:
///
///     acctURI  = "acct" ":" userpart "@" host
///     userpart = unreserved / sub-delims
///                0*( unreserved / pct-encoded / sub-delims )
///
/// This module provides `parse_acct_uri`, `is_acct_uri` and
/// `acct_resource`. It deliberately does NOT implement a full email
/// validator, an SMTP address parser or an IDNA framework: the host is
/// checked with the same conservative domain-name heuristic as
/// `check_hostname`, and internationalized localparts/hosts must be
/// percent-encoded / A-labels (see `docs/limitations.md`).

///|
/// A parsed `acct:` URI. `localpart` is the (possibly percent-encoded)
/// userpart exactly as it appeared in the URI; `host` is the domain as
/// it appeared.
pub struct AcctUri {
  localpart : String
  host : String
}

///|
/// The canonical reconstructed URI `acct:<localpart>@<host>`.
pub fn AcctUri::to_uri_string(self : AcctUri) -> String {
  "acct:\{self.localpart}@\{self.host}"
}

///|
/// Internal: whether a raw code unit may appear unescaped in the userpart
/// (unreserved or sub-delims).
fn is_userpart_char_u16(u : UInt16) -> Bool {
  is_unreserved_u16(u) || is_sub_delim_u16(u)
}

///|
/// Internal: whether a localpart string is valid as-is: every raw
/// character is a userpart character and every `%` begins a valid
/// `%XX` escape.
fn is_valid_localpart(localpart : String) -> Bool {
  if localpart.length() == 0 {
    return false
  }
  let mut i = 0
  while i < localpart.length() {
    let u = localpart[i]
    if u == 37 {
      if i + 2 >= localpart.length() {
        return false
      }
      match (hex_value_u16(localpart[i + 1]), hex_value_u16(localpart[i + 2])) {
        (Some(_), Some(_)) => i = i + 3
        _ => return false
      }
    } else if !is_userpart_char_u16(u) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Quick, syntactic-only test: does this string use the `acct` scheme
/// (case-insensitively) and contain the `userpart@host` shape? This does
/// not validate the localpart or the host; use `parse_acct_uri` for a
/// strict parse.
pub fn is_acct_uri(s : String) -> Bool {
  scheme_is(s, "acct") && s.contains("@")
}

///|
/// Strictly parse an `acct` URI per RFC 7565. Returns the localpart and
/// host, or a structured error (`InvalidAcctUri` / `InvalidUri` /
/// `InvalidPercentEncoding`).
pub fn parse_acct_uri(s : String) -> Result[AcctUri, WebFingerError] {
  Ok(parse_acct_uri_inner(s)) catch {
    e => Err(unwrap_webfinger_error(e))
  }
}

///|
/// Internal raise-based version of `parse_acct_uri`.
fn parse_acct_uri_inner(s : String) -> AcctUri raise {
  if !scheme_is(s, "acct") {
    raise WebFingerError(Uri, InvalidAcctUri, None, "URI scheme is not acct")
  }
  check_absolute_uri_inner(s)
  let body = s[5:]
  match body.split_once("@") {
    Some((localpart, host)) => {
      if localpart.length() == 0 {
        raise WebFingerError(
          Uri,
          InvalidAcctUri,
          None,
          "acct URI localpart is empty",
        )
      }
      if host.contains("@") {
        raise WebFingerError(
          Uri,
          InvalidAcctUri,
          None,
          "raw '@' is not allowed in the acct localpart",
        )
      }
      if !is_valid_localpart(localpart.to_owned()) {
        raise WebFingerError(
          Uri,
          InvalidAcctUri,
          None,
          "invalid acct localpart (allowed: unreserved, sub-delims, percent-encoded)",
        )
      }
      match check_hostname(host.to_owned()) {
        Ok(_) => {
          let acct : AcctUri = {
            localpart: localpart.to_owned(),
            host: host.to_owned(),
          }
          acct
        }
        Err(_) =>
          raise WebFingerError(
            Uri,
            InvalidAcctUri,
            None,
            "invalid acct host: must be a DNS domain name",
          )
      }
    }
    None =>
      raise WebFingerError(
        Uri,
        InvalidAcctUri,
        None,
        "acct URI must contain exactly one '@'",
      )
  }
}

///|
/// Build an `acct` URI from a raw localpart and host. The localpart is
/// percent-encoded as needed (unreserved characters and sub-delims pass
/// through; note that a literal `%` is treated as data and encoded, so
/// pass the raw, unencoded localpart). The host must pass
/// `check_hostname`.
pub fn acct_resource(
  localpart : String,
  host : String,
) -> Result[String, WebFingerError] {
  match check_hostname(host) {
    Err(e) => Err(e)
    Ok(_) => {
      let encoded = percent_encode_acct_localpart(localpart)
      Ok("acct:\{encoded}@\{host}")
    }
  }
}
