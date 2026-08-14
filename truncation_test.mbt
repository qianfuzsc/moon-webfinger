///|
test "complex jrd character prefixes never panic" {
  let fixtures = [
    "{\"subject\":\"acct:alice@example.com\",\"aliases\":[\"https://例子.example/用户\"],\"properties\":{\"https://example.com/name\":\"中文\"},\"links\":[{\"rel\":\"self\",\"href\":\"https://example.com/😀\",\"titles\":{\"zh\":\"你好\"},\"properties\":{\"https://example.com/p\":\"值\"}}]}",
    "{\"subject\":\"urn:example:αβγ\",\"aliases\":[\"https://example.com/a\",\"https://example.com/b\"],\"links\":[{\"rel\":\"alternate\",\"titles\":{\"und\":\"🌙 Moon\"}}]}",
    "{\"subject\":\"tag:example.com,2026:alice\",\"properties\":{\"https://example.com/null\":null},\"x\":{\"nested\":{\"array\":[1,true,\"多字节\"]}}}",
    "{\"links\":[{\"rel\":\"http://webfinger.net/rel/profile-page\",\"type\":\"text/html\",\"href\":\"https://example.com/élève\",\"titles\":{\"fr\":\"Élève\"}}]}",
    "{\"subject\":\"mailto:alice@example.com\",\"aliases\":[\"urn:example:一\"],\"properties\":{\"https://example.com/emoji\":\"😀😃😄\"}}",
  ]
  let mut cases = 0
  for fixture in fixtures {
    let prefix = StringBuilder::new()
    ignore(parse_jrd(""))
    cases = cases + 1
    for ch in fixture {
      prefix.write_char(ch)
      ignore(parse_jrd(prefix.to_string()))
      cases = cases + 1
    }
  }
  assert_true(cases > 400, msg="prefix coverage")
}

///|
test "representative truncated json returns structured errors" {
  for
    input in [
      "{", "{\"subject\"", "{\"subject\":\"acct:a@x", "{\"links\":[{\"rel\":\"self\"}",
    ] {
    match parse_jrd(input) {
      Ok(_) => assert_true(false, msg="accepted truncation")
      Err(e) => assert_eq(e.stage_name(), "Json", msg="stage")
    }
  }
}
