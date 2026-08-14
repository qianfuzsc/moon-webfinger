///|
/// Percent-encoding and -decoding for WebFinger query components.
///
/// RFC 7033 Section 4.1 requires that every WebFinger request parameter
/// value be percent-encoded per RFC 3986 Section 2.1, with the addition
/// that `=` and `&` inside parameter values are also percent-encoded.
/// This module implements exactly that:
///
/// * `percent_encode_component` — keeps RFC 3986 unreserved characters
///   (`A-Z a-z 0-9 - . _ ~`) and percent-encodes everything else,
///   including `=`, `&` and all non-ASCII characters (UTF-8 bytes).
/// * `percent_decode` — strict decoder: rejects malformed `%` escapes and
///   byte sequences that are not valid UTF-8.
///
/// UTF-8 encoding/decoding is implemented here directly (a tiny, fully
/// tested RFC 3629 subset) so the codec has no hidden failure modes.

///|
/// Internal: which characters are RFC 3986 unreserved.
fn is_unreserved(c : Char) -> Bool {
  c.is_ascii_alphabetic() ||
  c.is_ascii_digit() ||
  c == '-' ||
  c == '.' ||
  c == '_' ||
  c == '~'
}

///|
/// Internal: RFC 3986 sub-delims (`! $ & ' ( ) * + , ; =`).
fn is_sub_delim(c : Char) -> Bool {
  c == '!' ||
  c == '$' ||
  c == '&' ||
  c == '\'' ||
  c == '(' ||
  c == ')' ||
  c == '*' ||
  c == '+' ||
  c == ',' ||
  c == ';' ||
  c == '='
}

///|
/// Internal: ASCII classification helpers over UTF-16 code units, used by
/// the index-based scanners in this package (URI, percent and acct checks
/// only ever inspect ASCII positions, which are single code units).
fn is_ascii_alpha_u16(u : UInt16) -> Bool {
  (u >= 65 && u <= 90) || (u >= 97 && u <= 122)
}

///|
fn is_ascii_digit_u16(u : UInt16) -> Bool {
  u >= 48 && u <= 57
}

///|
fn is_alnum_u16(u : UInt16) -> Bool {
  is_ascii_alpha_u16(u) || is_ascii_digit_u16(u)
}

///|
fn is_unreserved_u16(u : UInt16) -> Bool {
  is_alnum_u16(u) || u == 45 || u == 46 || u == 95 || u == 126
}

///|
fn is_sub_delim_u16(u : UInt16) -> Bool {
  u == 33 ||
  u == 36 ||
  u == 38 ||
  u == 39 ||
  u == 40 ||
  u == 41 ||
  u == 42 ||
  u == 43 ||
  u == 44 ||
  u == 59 ||
  u == 61
}

///|
/// Internal: numeric value of an ASCII hex digit given as a UTF-16 code
/// unit, or `None`.
fn hex_value_u16(u : UInt16) -> Int? {
  if is_ascii_digit_u16(u) {
    Some(u.to_int() - 48)
  } else if u >= 97 && u <= 102 {
    Some(u.to_int() - 87)
  } else if u >= 65 && u <= 70 {
    Some(u.to_int() - 55)
  } else {
    None
  }
}

///|
/// Internal: uppercase hex digit for a byte value 0..15.
fn hex_digit_upper(n : Int) -> Char {
  if n < 10 {
    (48 + n).to_char().unwrap()
  } else {
    (55 + n).to_char().unwrap()
  }
}

///|
/// Internal: UTF-8 bytes of a Unicode code point (RFC 3629). The code
/// point must be a valid Unicode scalar value; callers guarantee that by
/// iterating `Char` values.
fn utf8_bytes_of_code_point(cp : Int) -> Array[Byte] {
  let bytes : Array[Byte] = []
  if cp < 0x80 {
    bytes.push(cp.to_byte())
  } else if cp < 0x800 {
    bytes.push((0xC0 | (cp >> 6)).to_byte())
    bytes.push((0x80 | (cp & 0x3F)).to_byte())
  } else if cp < 0x10000 {
    bytes.push((0xE0 | (cp >> 12)).to_byte())
    bytes.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    bytes.push((0x80 | (cp & 0x3F)).to_byte())
  } else {
    bytes.push((0xF0 | (cp >> 18)).to_byte())
    bytes.push((0x80 | ((cp >> 12) & 0x3F)).to_byte())
    bytes.push((0x80 | ((cp >> 6) & 0x3F)).to_byte())
    bytes.push((0x80 | (cp & 0x3F)).to_byte())
  }
  bytes
}

///|
/// Internal: append `%XX` for one byte to a builder.
fn write_percent_byte(sb : StringBuilder, b : Byte) -> Unit {
  let n = b.to_int()
  sb.write_char('%')
  sb.write_char(hex_digit_upper(n / 16))
  sb.write_char(hex_digit_upper(n % 16))
}

///|
/// Internal: percent-encode with a caller-supplied pass-through set.
/// Non-ASCII characters are always percent-encoded byte-wise as UTF-8.
fn encode_with(input : String, keep : (Char) -> Bool) -> String {
  let sb = StringBuilder::new(size_hint=input.length() * 3)
  for c in input {
    if keep(c) {
      sb.write_char(c)
    } else if c.is_ascii() {
      write_percent_byte(sb, c.to_int().to_byte())
    } else {
      let bytes = utf8_bytes_of_code_point(c.to_int())
      for b in bytes {
        write_percent_byte(sb, b)
      }
    }
  }
  sb.to_string()
}

///|
/// Percent-encode a query component value per RFC 7033 Section 4.1:
/// unreserved characters pass through, everything else (including `=`,
/// `&`, and non-ASCII text) is percent-encoded.
pub fn percent_encode_component(input : String) -> String {
  encode_with(input, is_unreserved)
}

///|
/// Percent-encode the localpart of an `acct` URI (RFC 7565 Section 7):
/// unreserved characters and sub-delims pass through.
pub fn percent_encode_acct_localpart(input : String) -> String {
  encode_with(input, fn(c) { is_unreserved(c) || is_sub_delim(c) })
}

///|
/// Internal: strict UTF-8 decoding of a byte array into a string.
/// Rejects truncated sequences, overlong encodings, surrogate code points
/// (U+D800..U+DFFF) and values above U+10FFFF. Returns a
/// `WebFingerError` on any violation.
fn decode_utf8_strict(bytes : Array[Byte]) -> String raise {
  let sb = StringBuilder::new(size_hint=bytes.length())
  let mut i = 0
  while i < bytes.length() {
    let b0 = bytes[i].to_int()
    if b0 < 0x80 {
      sb.write_char(b0.to_char().unwrap())
      i = i + 1
    } else if b0 < 0xC2 {
      // Continuation byte or overlong 2-byte lead.
      raise WebFingerError(
        Uri,
        InvalidPercentEncoding,
        None,
        "invalid UTF-8: bad leading byte",
      )
    } else if b0 < 0xE0 {
      if i + 1 >= bytes.length() {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: truncated 2-byte sequence",
        )
      }
      let b1 = bytes[i + 1].to_int()
      if b1 < 0x80 || b1 > 0xBF {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: bad continuation byte",
        )
      }
      let cp = ((b0 - 0xC0) << 6) | (b1 - 0x80)
      sb.write_char(cp.to_char().unwrap())
      i = i + 2
    } else if b0 < 0xF0 {
      if i + 2 >= bytes.length() {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: truncated 3-byte sequence",
        )
      }
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      if b1 < 0x80 || b1 > 0xBF || b2 < 0x80 || b2 > 0xBF {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: bad continuation byte",
        )
      }
      let cp = ((b0 - 0xE0) << 12) | ((b1 - 0x80) << 6) | (b2 - 0x80)
      if cp < 0x800 {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: overlong encoding",
        )
      }
      if cp >= 0xD800 && cp <= 0xDFFF {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: surrogate code point",
        )
      }
      sb.write_char(cp.to_char().unwrap())
      i = i + 3
    } else if b0 < 0xF5 {
      if i + 3 >= bytes.length() {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: truncated 4-byte sequence",
        )
      }
      let b1 = bytes[i + 1].to_int()
      let b2 = bytes[i + 2].to_int()
      let b3 = bytes[i + 3].to_int()
      if b1 < 0x80 ||
        b1 > 0xBF ||
        b2 < 0x80 ||
        b2 > 0xBF ||
        b3 < 0x80 ||
        b3 > 0xBF {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: bad continuation byte",
        )
      }
      let cp = ((b0 - 0xF0) << 18) |
        ((b1 - 0x80) << 12) |
        ((b2 - 0x80) << 6) |
        (b3 - 0x80)
      if cp < 0x10000 {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: overlong encoding",
        )
      }
      if cp > 0x10FFFF {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          None,
          "invalid UTF-8: above U+10FFFF",
        )
      }
      sb.write_char(cp.to_char().unwrap())
      i = i + 4
    } else {
      raise WebFingerError(
        Uri,
        InvalidPercentEncoding,
        None,
        "invalid UTF-8: invalid leading byte",
      )
    }
  }
  sb.to_string()
}

///|
/// Strictly percent-decode a string: every `%` must start a `%XX` escape
/// with two hex digits; raw non-ASCII characters are rejected (URIs are
/// ASCII; non-ASCII text must be percent-encoded); the decoded byte
/// stream must be valid UTF-8.
pub fn percent_decode(input : String) -> Result[String, WebFingerError] {
  try {
    let bytes : Array[Byte] = []
    let mut i = 0
    while i < input.length() {
      let u = input[i]
      if u == 37 {
        if i + 2 >= input.length() {
          raise WebFingerError(
            Uri,
            InvalidPercentEncoding,
            None,
            "malformed percent escape at end of input",
          )
        }
        match (hex_value_u16(input[i + 1]), hex_value_u16(input[i + 2])) {
          (Some(v1), Some(v2)) => {
            bytes.push((v1 * 16 + v2).to_byte())
            i = i + 3
          }
          _ =>
            raise WebFingerError(
              Uri,
              InvalidPercentEncoding,
              Some(i),
              "malformed percent escape",
            )
        }
      } else if u > 0x7F {
        raise WebFingerError(
          Uri,
          InvalidPercentEncoding,
          Some(i),
          "non-ASCII character must be percent-encoded",
        )
      } else {
        bytes.push(u.to_byte())
        i = i + 1
      }
    }
    Ok(decode_utf8_strict(bytes))
  } catch {
    e => Err(unwrap_webfinger_error(e))
  }
}
