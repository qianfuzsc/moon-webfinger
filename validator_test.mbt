///|
test "validator reports missing subject as warning only" {
  let jrd = expect_parse("{}")
  let issues = validate_jrd(jrd)
  assert_eq(issues.length(), 1, msg="one issue")
  assert_eq(issues[0].severity_name(), "Warning", msg="severity")
  assert_eq(validate_jrd_all(jrd), true, msg="warning is valid")
}

///|
test "resource validation distinguishes match and mismatch" {
  let jrd = expect_parse("{\"subject\":\"acct:a@x\"}")
  assert_eq(
    validate_for_resource(jrd, "acct:a@x")[0].code,
    "SubjectMatch",
    msg="match",
  )
  assert_eq(
    validate_for_resource(jrd, "acct:b@x")[0].code,
    "SubjectMismatch",
    msg="mismatch",
  )
}
