///|
test "builders create a valid full descriptor" {
  let link = match
    JrdLinkBuilder::new("self")
    .href("https://example.com/a")
    .media_type("text/html")
    .title("en", "Alice")
    .build() {
    Ok(v) => v
    Err(e) => abort(e.to_display())
  }
  let jrd = match
    JrdBuilder::new()
    .subject("acct:alice@example.com")
    .alias("https://example.com/a")
    .property_null("https://example.com/private")
    .link(link)
    .build() {
    Ok(v) => v
    Err(e) => abort(e.to_display())
  }
  assert_eq(validate_jrd_all(jrd), true, msg="valid")
  assert_eq(jrd.links.length(), 1, msg="link")
}

///|
test "builder rejects reserved extension name" {
  match JrdBuilder::new().extension("subject", @json.parse("true")).build() {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "DuplicateReservedExtension", msg="kind")
  }
}
