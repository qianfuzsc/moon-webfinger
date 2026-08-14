///|
test "audit reports missing subject and unknown member" {
  let jrd = expect_parse("{\"x-extension\":true}")
  let findings = audit_jrd(jrd)
  assert_true(findings.length() >= 2, msg="findings")
}

///|
test "response audit reports transport concerns" {
  let ctx = WebFingerResponseContext::new(
    Some("https://a.example/x"),
    "http://b.example/x",
    500,
    None,
    Some(2000000),
  )
  let findings = audit_response(ctx)
  assert_true(findings.length() >= 4, msg="transport findings")
}
