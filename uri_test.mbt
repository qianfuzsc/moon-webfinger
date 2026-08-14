// Tests for the lightweight URI checker (uri.mbt).

///|
test "check_absolute_uri accepts acct uri" {
  match check_absolute_uri("acct:alice@example.com") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_absolute_uri accepts https uri" {
  match check_absolute_uri("https://example.com/alice") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_absolute_uri accepts mailto uri" {
  match check_absolute_uri("mailto:alice@example.com") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_absolute_uri accepts urn uri" {
  match check_absolute_uri("urn:example:user:alice") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_absolute_uri accepts tag uri" {
  match check_absolute_uri("tag:example.com,2026:alice") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_absolute_uri accepts pct-encoded uri" {
  match check_absolute_uri("https://example.com/a%20b") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_absolute_uri rejects empty string" {
  match check_absolute_uri("") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidUri", msg="kind")
  }
}

///|
test "check_absolute_uri rejects relative reference" {
  match check_absolute_uri("/alice") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidUri", msg="kind")
  }
}

///|
test "check_absolute_uri rejects bare host" {
  match check_absolute_uri("example.com/alice") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidUri", msg="kind")
  }
}

///|
test "check_absolute_uri rejects space" {
  match check_absolute_uri("https://example.com/a b") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidUri", msg="kind")
  }
}

///|
test "check_absolute_uri rejects control character" {
  match check_absolute_uri("https://example.com/a\u0000b") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidUri", msg="kind")
  }
}

///|
test "check_absolute_uri rejects malformed percent" {
  match check_absolute_uri("https://example.com/%2") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "check_absolute_uri rejects non-ascii" {
  match check_absolute_uri("https://example.com/中文") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidUri", msg="kind")
  }
}

///|
test "uri_scheme extracts and lowercases scheme" {
  match uri_scheme("HTTPS://Example.com/x") {
    Some(s) => inspect(s, content="https")
    None => assert_true(false, msg="expected a scheme")
  }
}

///|
test "uri_scheme returns None for relative input" {
  match uri_scheme("/alice") {
    None => assert_true(true)
    Some(_) => assert_true(false, msg="expected no scheme")
  }
}

///|
test "scheme_is compares case-insensitively" {
  assert_true(scheme_is("HTTPS://example.com", "https"), msg="https")
  assert_true(scheme_is("acct:bob@example.com", "acct"), msg="acct")
  assert_true(!scheme_is("http://example.com", "https"), msg="http vs https")
}

///|
test "check_hostname accepts plain domain" {
  match check_hostname("example.com") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_hostname rejects ip literal" {
  match check_hostname("192.0.2.1") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(_) => assert_true(true)
  }
}

///|
test "check_hostname rejects leading hyphen label" {
  match check_hostname("-bad.example.com") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(_) => assert_true(true)
  }
}

///|
test "check_hostname rejects empty label" {
  match check_hostname("a..b") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(_) => assert_true(true)
  }
}
