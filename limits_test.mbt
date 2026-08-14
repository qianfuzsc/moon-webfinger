///|
test "strict limits reject oversized input" {
  let text = "{\"subject\":\"acct:" + "a".repeat(17000) + "@example.com\"}"
  match parse_jrd_with_limits(text, Limits::strict()) {
    Ok(_) => assert_true(false, msg="expected limit error")
    Err(e) => assert_eq(e.kind_name(), "LimitExceeded", msg="kind")
  }
}

///|
test "utf8 byte length counts multibyte characters" {
  assert_eq(utf8_byte_length("A中😀"), 8, msg="bytes")
  assert_eq(within_byte_limit("中文", 6), true, msg="within")
  assert_eq(within_byte_limit("中文", 5), false, msg="over")
}
