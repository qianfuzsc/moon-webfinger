///|
test "query helpers preserve link order and omit missing hrefs" {
  let jrd = expect_parse(
    "{\"links\":[{\"rel\":\"self\",\"href\":\"https://a\"},{\"rel\":\"self\"},{\"rel\":\"self\",\"href\":\"https://b\"}]}",
  )
  assert_eq(find_links_by_rel(jrd, "self").length(), 3, msg="links")
  assert_eq(hrefs_by_rel(jrd, "self"), ["https://a", "https://b"], msg="hrefs")
  assert_eq(first_href(jrd, "self"), Some("https://a"), msg="first")
}

///|
test "relation summary is lexical and counted" {
  let jrd = expect_parse(
    "{\"links\":[{\"rel\":\"z\"},{\"rel\":\"a\"},{\"rel\":\"z\"}]}",
  )
  let summary = relation_summary(jrd)
  assert_eq(summary[0].rel, "a", msg="sorted")
  assert_eq(summary[1].count, 2, msg="count")
}
