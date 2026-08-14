// Tests for request target construction (request.mbt).

///|
test "build_request_target for acct resource" {
  match build_request_target("acct:alice@example.com") {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=acct%3Aalice%40example.com",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "build_request_target encodes equals and ampersand" {
  match build_request_target("https://example.com/a?b=c&d=e") {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=https%3A%2F%2Fexample.com%2Fa%3Fb%3Dc%26d%3De",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "build_request_target rejects empty resource" {
  match build_request_target("") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "MissingResource", msg="kind")
  }
}

///|
test "build_request_target rejects relative resource" {
  match build_request_target("alice") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidResource", msg="kind")
  }
}

///|
test "build_request_target rejects fragment in resource" {
  match build_request_target("https://example.com/a#frag") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidResource", msg="kind")
  }
}

///|
test "build_request_target_with_rels preserves order and duplicates" {
  match
    build_request_target_with_rels("acct:bob@example.com", [
      "http://a.example/x", "http://b.example/y", "http://a.example/x",
    ]) {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=acct%3Abob%40example.com&rel=http%3A%2F%2Fa.example%2Fx&rel=http%3A%2F%2Fb.example%2Fy&rel=http%3A%2F%2Fa.example%2Fx",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "build_request_target accepts registered relation type tokens" {
  match
    build_request_target_with_rels("acct:bob@example.com", [
      "self", "profile-page",
    ]) {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=acct%3Abob%40example.com&rel=self&rel=profile-page",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "build_request_target rejects rel with spaces" {
  match build_request_target_with_rels("acct:bob@example.com", ["bad rel"]) {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidRelValue", msg="kind")
  }
}

///|
test "build_request_target rejects empty rel" {
  match build_request_target_with_rels("acct:bob@example.com", [""]) {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidRelValue", msg="kind")
  }
}

///|
test "canonicalize_request sorts and deduplicates rels" {
  match
    canonicalize_request("acct:bob@example.com", [
      "http://b.example", "http://a.example", "http://b.example",
    ]) {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=acct%3Abob%40example.com&rel=http%3A%2F%2Fa.example&rel=http%3A%2F%2Fb.example",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "check_rel_value accepts uri and token" {
  match check_rel_value("http://webfinger.example/rel/x") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="uri rel rejected: \{e.to_display()}")
  }
  match check_rel_value("self") {
    Ok(_) => assert_true(true)
    Err(e) => assert_true(false, msg="token rel rejected: \{e.to_display()}")
  }
}

///|
test "build_webfinger_url joins origin and target" {
  match
    build_webfinger_url("https://example.com", "acct:alice@example.com", []) {
    Ok(url) =>
      inspect(
        url,
        content="https://example.com/.well-known/webfinger?resource=acct%3Aalice%40example.com",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "build_webfinger_url accepts trailing slash and port" {
  match
    build_webfinger_url("https://example.com:8443/", "acct:alice@example.com", []) {
    Ok(url) =>
      inspect(
        url,
        content="https://example.com:8443/.well-known/webfinger?resource=acct%3Aalice%40example.com",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "build_webfinger_url rejects http origin" {
  match
    build_webfinger_url("http://example.com", "acct:alice@example.com", []) {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "NonHttpsOrigin", msg="kind")
  }
}

///|
test "build_webfinger_url rejects origin with path" {
  match
    build_webfinger_url("https://example.com/base", "acct:alice@example.com", []) {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidOrigin", msg="kind")
  }
}

///|
test "build_request_target rejects raw unicode resource" {
  match build_request_target("https://example.com/中文") {
    Ok(_) => assert_true(false, msg="expected error: URI must be ASCII")
    Err(e) => assert_eq(e.kind_name(), "InvalidResource", msg="kind")
  }
}
