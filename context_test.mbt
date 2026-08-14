///|
test "response context accepts https jrd response" {
  let ctx = WebFingerResponseContext::new(
    Some("https://example.com/.well-known/webfinger"),
    "https://example.com/.well-known/webfinger",
    200,
    Some("Application/JRD+JSON; charset=utf-8"),
    Some(2),
  )
  assert_true(validate_response_context(ctx) is Ok(_), msg="valid")
}

///|
test "response context rejects insecure final url" {
  let ctx = WebFingerResponseContext::new(
    None,
    "http://example.com/x",
    200,
    Some(JRD_MEDIA_TYPE),
    None,
  )
  match validate_response_context(ctx) {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "NonHttpsFinalUrl", msg="kind")
  }
}
