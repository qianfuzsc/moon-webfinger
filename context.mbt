///|
/// HTTPS context validation for WebFinger exchanges.
///
/// WebFinger is an HTTPS-only protocol (RFC 7033 Sections 4 and 9.1):
/// clients MUST query over HTTPS, MUST NOT fall back to plain HTTP, and
/// MUST re-validate certificates after any redirect (which itself MUST
/// only target an https URI). Because this library performs no network
/// access, the caller supplies the observed exchange facts — request
/// URL, final URL, HTTP status, Content-Type and body size — and
/// `validate_response_context` checks the protocol invariants that are
/// checkable without a connection:
///
/// * the final URL must be an absolute https URI;
/// * a supplied request URL must also be https;
/// * the status must be in the 2xx success range;
/// * the Content-Type must be `application/jrd+json` (RFC 7033 Section
///   10.2; parameters are tolerated and the media type comparison is
///   case-insensitive).
///
/// Redirects to another https origin are permitted by RFC 7033, so an
/// origin change between request and final URL is not an error here; the
/// audit module reports it as an advisory finding instead.

///|
/// The caller-observed facts about a WebFinger request. `resource` and
/// `rels` are the values actually sent.
pub struct WebFingerRequestContext {
  request_url : String
  resource : String
  rels : Array[String]
}

///|
/// Build a request context. No validation happens here; use
/// `validate_response_context` on the paired response context.
pub fn WebFingerRequestContext::new(
  request_url : String,
  resource : String,
  rels : Array[String],
) -> WebFingerRequestContext {
  { request_url, resource, rels }
}

///|
/// The caller-observed facts about a WebFinger response.
pub struct WebFingerResponseContext {
  request_url : String?
  final_url : String
  status : Int
  content_type : String?
  body_bytes : Int?
}

///|
/// Build a response context. `status` is the HTTP status code,
/// `content_type` the full Content-Type header value (parameters
/// allowed), `body_bytes` the response body size in bytes when known.
pub fn WebFingerResponseContext::new(
  request_url : String?,
  final_url : String,
  status : Int,
  content_type : String?,
  body_bytes : Int?,
) -> WebFingerResponseContext {
  { request_url, final_url, status, content_type, body_bytes }
}

///|
/// The registered JRD media type.
pub const JRD_MEDIA_TYPE : String = "application/jrd+json"

///|
/// Whether a Content-Type header value denotes the JRD media type.
/// Parameters (after `;`) are ignored and the media type comparison is
/// ASCII case-insensitive. Malformed values simply return false.
pub fn is_jrd_content_type(content_type : String) -> Bool {
  match content_type.split_once(";") {
    Some((media_type, _params)) =>
      media_type.trim().to_lower().to_owned() == JRD_MEDIA_TYPE
    None => content_type.trim().to_lower().to_owned() == JRD_MEDIA_TYPE
  }
}

///|
/// Internal: whether a status code is in the 2xx success range.
fn is_success_status(status : Int) -> Bool {
  status >= 200 && status <= 299
}

///|
/// Validate a response context against the checkable RFC 7033 transport
/// invariants. Returns the first violation found as a structured error;
/// advisory observations (such as a same-scheme redirect) are reported
/// by `audit_response` instead.
pub fn validate_response_context(
  ctx : WebFingerResponseContext,
) -> Result[Unit, WebFingerError] {
  match check_absolute_uri(ctx.final_url) {
    Ok(_) => ()
    Err(e) =>
      return Err(
        WebFingerError(
          Context,
          NonHttpsFinalUrl,
          None,
          "final_url is not an absolute URI: \{e.context()}",
        ),
      )
  }
  if !scheme_is(ctx.final_url, "https") {
    return Err(
      WebFingerError(
        Context,
        NonHttpsFinalUrl,
        None,
        "final_url must use the https scheme (RFC 7033 Section 4.2)",
      ),
    )
  }
  match ctx.request_url {
    Some(url) =>
      match check_absolute_uri(url) {
        Ok(_) =>
          if !scheme_is(url, "https") {
            return Err(
              WebFingerError(
                Context,
                NonHttpsOrigin,
                None,
                "request_url must use the https scheme",
              ),
            )
          }
        Err(e) =>
          return Err(
            WebFingerError(
              Context,
              InvalidOrigin,
              None,
              "request_url is not an absolute URI: \{e.context()}",
            ),
          )
      }
    None => ()
  }
  if !is_success_status(ctx.status) {
    return Err(
      WebFingerError(
        Context,
        InvalidHttpStatus,
        None,
        "status \{ctx.status} is not in the 2xx success range",
      ),
    )
  }
  match ctx.content_type {
    None =>
      return Err(
        WebFingerError(
          Context,
          InvalidContentType,
          None,
          "content_type is missing; JRD responses must use \{JRD_MEDIA_TYPE}",
        ),
      )
    Some(ct) =>
      if !is_jrd_content_type(ct) {
        return Err(
          WebFingerError(
            Context,
            InvalidContentType,
            None,
            "content_type \{ct} is not \{JRD_MEDIA_TYPE}",
          ),
        )
      }
  }
  Ok(())
}

///|
/// Internal: offset of the first `/` or `None`.
fn first_slash(s : String) -> Int? {
  let mut i = 0
  while i < s.length() {
    if s[i] == 47 {
      return Some(i)
    }
    i = i + 1
  }
  None
}

///|
/// The origin (scheme + host + port) of a URL-shaped string, lowercased
/// scheme and host, or `None` when it cannot be split. Syntactic only.
pub fn origin_of(url : String) -> String? {
  match url.split_once("://") {
    Some((scheme, rest)) =>
      match first_slash(rest.to_owned()) {
        Some(n) =>
          Some("\{scheme.to_lower()}://\{rest[0:n].to_owned().to_lower()}")
        None => Some("\{scheme.to_lower()}://\{rest.to_owned().to_lower()}")
      }
    None => None
  }
}
