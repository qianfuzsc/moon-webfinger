///|
test "parser preserves unknown top-level and link members" {
  let jrd = expect_parse(
    "{\"subject\":\"acct:a@example.com\",\"x-extra\":{\"z\":1},\"links\":[{\"rel\":\"self\",\"x-link\":true}]}",
  )
  assert_eq(jrd.extensions.length(), 1, msg="top extension")
  assert_eq(jrd.links[0].extensions.length(), 1, msg="link extension")
}

///|
test "parser accepts unicode values" {
  let jrd = expect_parse(
    "{\"subject\":\"acct:a@example.com\",\"properties\":{\"https://example.com/name\":\"中文😀\"}}",
  )
  assert_eq(
    property_string(jrd, "https://example.com/name"),
    Some("中文😀"),
    msg="unicode",
  )
}
