// Tests for the JRD model and its helpers (model.mbt).

///|
test "empty jrd has no members" {
  let jrd = JsonResourceDescriptor::empty()
  assert_eq(jrd.subject, None, msg="subject")
  assert_eq(jrd.aliases.length(), 0, msg="aliases")
  assert_eq(jrd.links.length(), 0, msg="links")
  assert_eq(jrd.properties.length(), 0, msg="properties")
}

///|
test "property value constructors" {
  let s = PropertyValue::string("x")
  let n = PropertyValue::null()
  assert_eq(s.is_null(), false, msg="string not null")
  assert_eq(n.is_null(), true, msg="null is null")
  assert_eq(s.as_string(), Some("x"), msg="as_string")
  assert_eq(n.as_string(), None, msg="null as_string")
}

///|
test "title exact match" {
  let link = JrdLink::new("self")
  link.titles.set("en", "Hello")
  link.titles.set("en-us", "Howdy")
  assert_eq(link.title("en"), Some("Hello"), msg="exact")
  assert_eq(link.title("de"), None, msg="absent")
}

///|
test "title case-insensitive match" {
  let link = JrdLink::new("self")
  link.titles.set("en-US", "Howdy")
  assert_eq(link.title("en-us"), Some("Howdy"), msg="ci lookup")
  assert_eq(link.has_title("EN-us"), true, msg="has_title ci")
}

///|
test "preferred_title follows caller priority" {
  let link = JrdLink::new("self")
  link.titles.set("en", "Hello")
  link.titles.set("fr", "Salut")
  assert_eq(
    link.preferred_title(["fr", "en"]),
    Some("Salut"),
    msg="first choice",
  )
  assert_eq(
    link.preferred_title(["de", "en"]),
    Some("Hello"),
    msg="fallback choice",
  )
  assert_eq(link.preferred_title(["de"]), None, msg="no match")
}

///|
test "fallback_title prefers und then smallest tag" {
  let link = JrdLink::new("self")
  link.titles.set("en", "Hello")
  link.titles.set("fr", "Salut")
  assert_eq(
    link.fallback_title(),
    Some("Hello"),
    msg="lexicographically smallest",
  )
  link.titles.set("und", "Untitled")
  assert_eq(link.fallback_title(), Some("Untitled"), msg="und wins")
}

///|
test "link property access" {
  let link = JrdLink::new("self")
  link.properties.set(
    "http://example.com/role",
    PropertyValue::string("editor"),
  )
  assert_eq(link.has_property("http://example.com/role"), true, msg="has")
  assert_eq(link.has_property("http://example.com/x"), false, msg="absent")
  match link.property("http://example.com/role") {
    Some(StringValue(s)) => assert_eq(s, "editor", msg="value")
    _ => assert_true(false, msg="expected string value")
  }
}

///|
test "jrd property access" {
  let jrd = JsonResourceDescriptor::empty()
  jrd.properties.set(
    "http://example.com/ns/version",
    PropertyValue::string("1.3"),
  )
  jrd.properties.set("http://example.com/ns/ext", PropertyValue::null())
  assert_eq(jrd.has_property("http://example.com/ns/version"), true, msg="has")
  match jrd.property("http://example.com/ns/ext") {
    Some(v) => assert_eq(v.is_null(), true, msg="null value")
    None => assert_true(false, msg="missing property")
  }
}

///|
test "jrd semantic equality ignores member order" {
  let a = expect_parse(
    "{\"subject\":\"acct:a@example.com\",\"aliases\":[\"https://a.example/\"],\"properties\":{\"http://x\":\"1\"}}",
  )
  let b = expect_parse(
    "{\"properties\":{\"http://x\":\"1\"},\"aliases\":[\"https://a.example/\"],\"subject\":\"acct:a@example.com\"}",
  )
  assert_eq(jrd_semantic_equal(a, b), true, msg="equal")
}

///|
test "jrd semantic equality preserves links array order" {
  let a = expect_parse(
    "{\"links\":[{\"rel\":\"self\",\"href\":\"https://a\"},{\"rel\":\"me\",\"href\":\"https://b\"}]}",
  )
  let b = expect_parse(
    "{\"links\":[{\"rel\":\"me\",\"href\":\"https://b\"},{\"rel\":\"self\",\"href\":\"https://a\"}]}",
  )
  assert_eq(jrd_semantic_equal(a, b), false, msg="order matters")
}

///|
test "jrd link semantic equality with null and absent distinctions" {
  let a = expect_parse(
    "{\"links\":[{\"rel\":\"x\",\"properties\":{\"http://p\":null}}]}",
  )
  let b = expect_parse("{\"links\":[{\"rel\":\"x\"}]}")
  assert_eq(jrd_semantic_equal(a, b), false, msg="null property is not absence")
}

///|
test "library_version is 0.1.0-dev" {
  inspect(library_version(), content="0.1.0-dev")
}
