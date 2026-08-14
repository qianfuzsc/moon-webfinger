///|
/// WebFinger request construction.
///
/// Per RFC 7033 Section 4:
///
/// * the path component MUST be `/.well-known/webfinger`;
/// * the query MUST contain a `resource` parameter exactly once, holding
///   the (absolute URI) query target;
/// * the query MAY contain one or more `rel` parameters holding link
///   relation types;
/// * every parameter value MUST be percent-encoded per RFC 3986 Section
///   2.1 with `=` and `&` additionally encoded, and no spaces may be
///   inserted.
///
/// This module builds request *targets* only. It never derives a host
/// from the resource, never resolves DNS, and never performs network
/// access; `build_webfinger_url` requires the HTTPS origin to be passed
/// in explicitly by the caller.
///
/// RFC 7033 Section 4.3 permits repeating `rel`, so
/// `build_request_target_with_rels` preserves the caller's rel order and
/// duplicates. `canonicalize_request` is the one place that normalizes:
/// it sorts rels and drops duplicates, which is semantically neutral
/// because RFC 7033 Section 4.1 says parameter order does not matter.

///|
/// The well-known WebFinger path.
pub const WELL_KNOWN_PATH : String = "/.well-known/webfinger"

///|
/// Internal: RFC 7230 token characters (`tchar`), used to recognise
/// registered link relation types (RFC 5988 relation-type).
fn is_tchar_u16(u : UInt16) -> Bool {
  is_alnum_u16(u) ||
  u == 33 ||
  u == 35 ||
  u == 36 ||
  u == 37 ||
  u == 38 ||
  u == 39 ||
  u == 42 ||
  u == 43 ||
  u == 45 ||
  u == 46 ||
  u == 94 ||
  u == 95 ||
  u == 96 ||
  u == 124 ||
  u == 126
}

///|
/// Internal: whether `rel` is a token-shaped (registered) relation type.
fn is_registered_relation_type(rel : String) -> Bool {
  if rel.length() == 0 {
    return false
  }
  let mut i = 0
  while i < rel.length() {
    if !is_tchar_u16(rel[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Check a link relation value: per RFC 7033 Section 4.4.4.1 a rel value
/// must be exactly one URI or one registered relation type (token). This
/// is a syntactic check — the library cannot consult the IANA registry.
pub fn check_rel_value(rel : String) -> Result[Unit, WebFingerError] {
  if rel.length() == 0 {
    return Err(
      WebFingerError(Request, InvalidRelValue, None, "rel value is empty"),
    )
  }
  if is_registered_relation_type(rel) {
    return Ok(())
  }
  match check_absolute_uri(rel) {
    Ok(_) => Ok(())
    Err(_) =>
      Err(
        WebFingerError(
          Request,
          InvalidRelValue,
          None,
          "rel must be a URI or a registered relation type",
        ),
      )
  }
}

///|
/// Internal: validate the `resource` query target. RFC 7033 requires an
/// absolute URI (relative references are not used with WebFinger); an
/// unencoded `#` would make it a URI-reference with a fragment rather
/// than a URI, so it is rejected and must be percent-encoded.
fn check_resource(resource : String) -> Result[Unit, WebFingerError] {
  if resource.length() == 0 {
    return Err(
      WebFingerError(Request, MissingResource, None, "resource is empty"),
    )
  }
  if utf8_byte_length(resource) > Limits::default().max_subject_bytes {
    return Err(
      WebFingerError(
        Limit,
        LimitExceeded,
        None,
        "resource exceeds \{Limits::default().max_subject_bytes} bytes",
      ),
    )
  }
  if resource.contains("#") {
    return Err(
      WebFingerError(
        Request,
        InvalidResource,
        None,
        "resource must not contain a fragment; percent-encode '#'",
      ),
    )
  }
  match check_absolute_uri(resource) {
    Ok(_) => Ok(())
    Err(e) => Err(WebFingerError(Request, InvalidResource, None, e.context()))
  }
}

///|
/// Internal: validate every rel and return a display context on failure.
fn check_rels(rels : Array[String]) -> Result[Unit, WebFingerError] {
  for rel in rels {
    match check_rel_value(rel) {
      Ok(_) => continue
      Err(e) =>
        return Err(
          WebFingerError(
            Request,
            InvalidRelValue,
            None,
            "\{e.context()} (rel: \{rel})",
          ),
        )
    }
  }
  Ok(())
}

///|
/// Internal: assemble the query component.
fn build_query(resource : String, rels : Array[String]) -> String {
  let sb = StringBuilder::new(size_hint=64 + resource.length() * 3)
  sb.write_string("resource=")
  sb.write_string(percent_encode_component(resource))
  for rel in rels {
    sb.write_string("&rel=")
    sb.write_string(percent_encode_component(rel))
  }
  sb.to_string()
}

///|
/// Build the WebFinger request target for a resource without rel
/// filters.
pub fn build_request_target(
  resource : String,
) -> Result[String, WebFingerError] {
  build_request_target_with_rels(resource, [])
}

///|
/// Build the WebFinger request target for a resource plus zero or more
/// rel filters. Rel order and duplicates are preserved, matching RFC
/// 7033 Section 4.3.
pub fn build_request_target_with_rels(
  resource : String,
  rels : Array[String],
) -> Result[String, WebFingerError] {
  match check_resource(resource) {
    Err(e) => Err(e)
    Ok(_) =>
      match check_rels(rels) {
        Err(e) => Err(e)
        Ok(_) => Ok("\{WELL_KNOWN_PATH}?\{build_query(resource, rels)}")
      }
  }
}

///|
/// Canonicalize a request target for the same resource and rels: the
/// `resource` parameter always comes first, rels are sorted and
/// deduplicated. Parameter order is not semantic (RFC 7033 Section 4.1),
/// so this normalization is safe, but it is provided as a separate
/// function because ordinary request building preserves caller order.
pub fn canonicalize_request(
  resource : String,
  rels : Array[String],
) -> Result[String, WebFingerError] {
  match check_resource(resource) {
    Err(e) => Err(e)
    Ok(_) =>
      match check_rels(rels) {
        Err(e) => Err(e)
        Ok(_) => {
          let unique : Map[String, Bool] = Map([])
          let sorted : Array[String] = []
          for rel in rels {
            if !unique.contains(rel) {
              unique.set(rel, true)
              sorted.push(rel)
            }
          }
          sorted.sort()
          Ok("\{WELL_KNOWN_PATH}?\{build_query(resource, sorted)}")
        }
      }
  }
}

///|
/// Internal: validate an HTTPS origin (`https://host[:port]` with an
/// optional single trailing slash; no path, query, fragment or userinfo).
fn check_https_origin(origin : String) -> Result[Unit, WebFingerError] {
  if !scheme_is(origin, "https") {
    return Err(
      WebFingerError(
        Context,
        NonHttpsOrigin,
        None,
        "origin must use the https scheme",
      ),
    )
  }
  if origin.contains("?") || origin.contains("#") {
    return Err(
      WebFingerError(
        Context,
        InvalidOrigin,
        None,
        "origin must not contain a query or fragment",
      ),
    )
  }
  let mut rest = origin[8:].to_owned()
  if rest.has_suffix("/") {
    rest = rest[0:rest.length() - 1].to_owned()
  }
  if rest.length() == 0 {
    return Err(
      WebFingerError(Context, InvalidOrigin, None, "origin has no host"),
    )
  }
  if rest.contains("/") {
    return Err(
      WebFingerError(
        Context,
        InvalidOrigin,
        None,
        "origin must not contain a path",
      ),
    )
  }
  if rest.contains("@") {
    return Err(
      WebFingerError(
        Context,
        InvalidOrigin,
        None,
        "origin must not contain userinfo",
      ),
    )
  }
  // Optional port.
  let host_part = match rest.split_once(":") {
    Some((h, p)) => {
      let port = p.to_owned()
      if port.length() == 0 {
        return Err(WebFingerError(Context, InvalidOrigin, None, "empty port"))
      }
      let mut i = 0
      while i < port.length() {
        if !is_ascii_digit_u16(port[i]) {
          return Err(
            WebFingerError(Context, InvalidOrigin, None, "port must be numeric"),
          )
        }
        i = i + 1
      }
      h.to_owned()
    }
    None => rest
  }
  match check_hostname(host_part) {
    Ok(_) => Ok(())
    Err(_) =>
      Err(
        WebFingerError(
          Context,
          InvalidOrigin,
          None,
          "origin host must be a DNS domain name",
        ),
      )
  }
}

///|
/// Internal: strip one trailing slash for URL assembly.
fn origin_without_trailing_slash(origin : String) -> String {
  if origin.has_suffix("/") && origin.length() > 1 {
    origin[0:origin.length() - 1].to_owned()
  } else {
    origin
  }
}

///|
/// Build a full WebFinger URL from a caller-supplied HTTPS origin plus
/// the resource and optional rel filters. The origin is validated
/// syntactically (https scheme, domain name host, optional numeric
/// port) but never contacted: no DNS, no TLS, no network.
pub fn build_webfinger_url(
  origin : String,
  resource : String,
  rels : Array[String],
) -> Result[String, WebFingerError] {
  match check_https_origin(origin) {
    Err(e) => Err(e)
    Ok(_) =>
      match build_request_target_with_rels(resource, rels) {
        Err(e) => Err(e)
        Ok(target) => Ok("\{origin_without_trailing_slash(origin)}\{target}")
      }
  }
}
