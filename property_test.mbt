///|
test "800 deterministic round-trip and canonicalization cases" {
  let prng = prng_new(7033)
  let mut i = 0
  while i < 800 {
    let name = random_alnum(prng, 1, 18)
    let value = random_alnum(prng, 0, 24)
    let input = "{\"subject\":\"acct:" +
      name +
      "@example.com\",\"properties\":{\"https://example.com/value\":\"" +
      value +
      "\"}}"
    let a = expect_parse(input)
    let encoded = serialize_jrd(a)
    let b = expect_parse(encoded)
    assert_eq(jrd_semantic_equal(a, b), true, msg="round trip case \{i}")
    match canonicalize_jrd_text(encoded) {
      Ok(encoded2) => assert_eq(encoded, encoded2, msg="canonical case \{i}")
      Err(e) => assert_true(false, msg=e.to_display())
    }
    assert_eq(
      percent_encode_component(name),
      percent_encode_component(name),
      msg="encoding case \{i}",
    )
    i = i + 1
  }
}

///|
test "request construction is deterministic across 200 cases" {
  let prng = prng_new(7565)
  let mut i = 0
  while i < 200 {
    let resource = "acct:" + random_alnum(prng, 1, 16) + "@example.com"
    let a = match build_request_target(resource) {
      Ok(v) => v
      Err(e) => abort(e.to_display())
    }
    let b = match build_request_target(resource) {
      Ok(v) => v
      Err(e) => abort(e.to_display())
    }
    assert_eq(a, b, msg="request case \{i}")
    i = i + 1
  }
}
