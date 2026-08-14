///|
test "serializer uses deterministic member order" {
  let jrd = expect_parse(
    "{\"links\":[],\"properties\":{},\"aliases\":[\"https://b\"],\"subject\":\"acct:a@x\"}",
  )
  inspect(
    serialize_jrd(jrd),
    content="{\"aliases\":[\"https://b\"],\"subject\":\"acct:a@x\"}",
  )
}

///|
test "canonicalization is idempotent" {
  let once = canonicalize_jrd_text(
    "{ \"subject\" : \"acct:a@x\", \"aliases\" : [] }",
  )
  match once {
    Err(e) => assert_true(false, msg=e.to_display())
    Ok(a) =>
      match canonicalize_jrd_text(a) {
        Ok(b) => assert_eq(a, b, msg="idempotent")
        Err(e) => assert_true(false, msg=e.to_display())
      }
  }
}
