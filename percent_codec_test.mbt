// Tests for percent encoding/decoding (percent_codec.mbt).

///|
test "percent_encode_component keeps unreserved characters" {
  inspect(percent_encode_component("abcXYZ019-._~"), content="abcXYZ019-._~")
}

///|
test "percent_encode_component encodes reserved characters" {
  inspect(percent_encode_component("a b&c=d?"), content="a%20b%26c%3Dd%3F")
}

///|
test "percent_encode_component encodes acct uri" {
  inspect(
    percent_encode_component("acct:alice@example.com"),
    content="acct%3Aalice%40example.com",
  )
}

///|
test "percent_encode_component encodes unicode as utf8 bytes" {
  inspect(percent_encode_component("中文"), content="%E4%B8%AD%E6%96%87")
}

///|
test "percent_encode_component encodes emoji" {
  inspect(percent_encode_component("🎉"), content="%F0%9F%8E%89")
}

///|
test "percent_encode_component encodes the percent sign itself" {
  inspect(percent_encode_component("100%"), content="100%25")
}

///|
test "percent_encode_acct_localpart keeps sub-delims" {
  inspect(percent_encode_acct_localpart("juliet+tag!~"), content="juliet+tag!~")
}

///|
test "percent_decode round-trips encoded text" {
  match percent_decode("acct%3Aalice%40example.com") {
    Ok(s) => inspect(s, content="acct:alice@example.com")
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "percent_decode round-trips unicode" {
  match percent_decode("%E4%B8%AD%E6%96%87%F0%9F%8E%89") {
    Ok(s) => inspect(s, content="中文🎉")
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "percent_decode rejects malformed escape" {
  match percent_decode("ab%2") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "percent_decode rejects non-hex escape" {
  match percent_decode("ab%2G") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "percent_decode rejects raw non-ascii" {
  match percent_decode("中文") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "percent_decode rejects invalid utf8 bytes" {
  match percent_decode("%C3%28") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "percent_decode rejects overlong encoding" {
  match percent_decode("%C0%AF") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "percent_decode rejects surrogate code point" {
  match percent_decode("%ED%A0%80") {
    Ok(_) => assert_true(false, msg="expected error")
    Err(e) => assert_eq(e.kind_name(), "InvalidPercentEncoding", msg="kind")
  }
}

///|
test "percent_decode handles empty input" {
  match percent_decode("") {
    Ok(s) => inspect(s, content="")
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}
