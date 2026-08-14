///|
/// JRD parsing entry points.
///
/// `parse_jrd` parses a JSON document into the JRD model under default
/// limits; `parse_jrd_with_limits` lets callers tighten or relax every
/// bound. Both convert every failure — empty input, oversized input,
/// JSON syntax errors, a non-object root, wrong member types, missing
/// required link members, or limit violations — into a structured
/// `WebFingerError`. Neither can panic on any input.
///
/// RFC 7033 Section 4.4 requires that clients MUST ignore unknown JRD
/// members, so unknown members are preserved as extensions rather than
/// rejected. Known members with the wrong JSON type are rejected: the
/// RFC defines their shapes normatively and gives no licence to accept
/// other shapes silently.

///|
/// Parse a JRD document under `Limits::default()`.
pub fn parse_jrd(
  input : String,
) -> Result[JsonResourceDescriptor, WebFingerError] {
  parse_jrd_with_limits(input, Limits::default())
}

///|
/// Parse a JRD document under caller-supplied limits.
pub fn parse_jrd_with_limits(
  input : String,
  limits : Limits,
) -> Result[JsonResourceDescriptor, WebFingerError] {
  try {
    if input.length() == 0 {
      raise WebFingerError(Input, EmptyInput, None, "input is empty")
    }
    let byte_len = utf8_byte_length(input)
    if byte_len > limits.max_input_bytes {
      raise WebFingerError(
        Limit,
        LimitExceeded,
        None,
        "input is \{byte_len} bytes; limit is \{limits.max_input_bytes}",
      )
    }
    let j = @json.parse(input) catch {
      e =>
        raise WebFingerError(
          Json,
          InvalidJson,
          None,
          "JSON syntax error: \{e.to_string()}",
        )
    }
    Ok(json_to_jrd_inner(j, limits, 1))
  } catch {
    e => Err(unwrap_webfinger_error(e))
  }
}
