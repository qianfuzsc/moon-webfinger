///|
test "parser rejects non-object roots" {
  for input in ["null", "true", "1", "\"x\"", "[]"] {
    match parse_jrd(input) {
      Ok(_) => assert_true(false, msg="accepted " + input)
      Err(_) => ()
    }
  }
}

///|
test "parser rejects wrong known member types" {
  for
    input in [
      "{\"subject\":1}", "{\"aliases\":{}}", "{\"properties\":[]}", "{\"links\":{}}",
    ] {
    match parse_jrd(input) {
      Ok(_) => assert_true(false, msg="accepted " + input)
      Err(_) => ()
    }
  }
}
