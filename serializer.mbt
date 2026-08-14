///|
/// Deterministic JRD serialization and canonicalization.
///
/// `serialize_jrd` emits a valid `application/jrd+json` document with a
/// stable, documented layout:
///
/// * top-level members in the order subject, aliases, properties,
///   links, then preserved extension members;
/// * object members (including inside extensions) in lexically sorted
///   key order;
/// * links arrays in model order (RFC 7033 says links array order MAY
///   indicate preference, so it is never reordered);
/// * minimal escaping (quotes, backslashes, control characters);
///   non-ASCII text is emitted as UTF-8, which RFC 8259 permits.
///
/// JSON object member order carries no semantics; the fixed order exists
/// only so that the same model always serializes to the same bytes, which
/// is what makes round-trip and canonicalization properties testable.
///
/// `canonicalize_jrd` applies exactly those rules (stable member order,
/// stable whitespace, stable escaping) and nothing else: it never
/// changes URI character case, drops aliases, merges links, reorders
/// link arrays, or rewrites titles or hrefs, because any of those could
/// change application-level semantics.

///|
/// Internal: write a JSON string with minimal escaping.
fn write_json_string(s : String, sb : StringBuilder) -> Unit {
  sb.write_char('"')
  for c in s {
    let cp = c.to_int()
    if c == '"' {
      sb.write_string("\\\"")
    } else if c == '\\' {
      sb.write_string("\\\\")
    } else if c == '\n' {
      sb.write_string("\\n")
    } else if c == '\r' {
      sb.write_string("\\r")
    } else if c == '\t' {
      sb.write_string("\\t")
    } else if c == '\b' {
      sb.write_string("\\b")
    } else if c == '\f' {
      sb.write_string("\\f")
    } else if cp < 0x20 {
      sb.write_string("\\u00")
      sb.write_char(hex_digit_upper(cp / 16))
      sb.write_char(hex_digit_upper(cp % 16))
    } else {
      sb.write_char(c)
    }
  }
  sb.write_char('"')
}

///|
/// Internal: keys of a JSON object in lexically sorted order.
fn sorted_keys(members : Map[String, Json]) -> Array[String] {
  let keys : Array[String] = []
  for k in members.keys() {
    keys.push(k)
  }
  keys.sort()
  keys
}

///|
/// Internal: render a number. Prefer the original literal representation
/// when the value was parsed (so round-trips keep e.g. `3.50`); otherwise
/// use the platform's shortest round-trip form. NaN and infinities have
/// no JSON representation and become `null`.
fn format_double(n : Double, repr : String?) -> String {
  match repr {
    Some(r) => r
    None => {
      if n != n {
        return "null"
      }
      if n > 1.7976931348623157e308 {
        return "null"
      }
      if n < -1.7976931348623157e308 {
        return "null"
      }
      n.to_string()
    }
  }
}

///|
/// Internal: compact JSON writer (no whitespace). Object keys are
/// written in sorted order.
fn write_json_compact(j : Json, sb : StringBuilder) -> Unit {
  match j {
    Null => sb.write_string("null")
    True => sb.write_string("true")
    False => sb.write_string("false")
    Number(n, repr~) => sb.write_string(format_double(n, repr))
    String(s) => write_json_string(s, sb)
    Array(arr) => {
      sb.write_char('[')
      let mut i = 0
      while i < arr.length() {
        if i > 0 {
          sb.write_char(',')
        }
        write_json_compact(arr[i], sb)
        i = i + 1
      }
      sb.write_char(']')
    }
    Object(members) => {
      sb.write_char('{')
      let keys = sorted_keys(members)
      let mut i = 0
      while i < keys.length() {
        if i > 0 {
          sb.write_char(',')
        }
        write_json_string(keys[i], sb)
        sb.write_char(':')
        match members.get(keys[i]) {
          Some(v) => write_json_compact(v, sb)
          None => abort("internal error: sorted key missing from object")
        }
        i = i + 1
      }
      sb.write_char('}')
    }
  }
}

///|
/// Internal: write indentation of `depth` levels, `width` spaces each.
fn write_pad(sb : StringBuilder, depth : Int, width : Int) -> Unit {
  let mut i = 0
  let total = depth * width
  while i < total {
    sb.write_char(' ')
    i = i + 1
  }
}

///|
/// Internal: indented JSON writer. Object keys are written in sorted
/// order.
fn write_json_indented(
  j : Json,
  sb : StringBuilder,
  width : Int,
  depth : Int,
) -> Unit {
  match j {
    Array(arr) =>
      if arr.length() == 0 {
        sb.write_string("[]")
      } else {
        sb.write_string("[\n")
        let mut i = 0
        while i < arr.length() {
          if i > 0 {
            sb.write_string(",\n")
          }
          write_pad(sb, depth + 1, width)
          write_json_indented(arr[i], sb, width, depth + 1)
          i = i + 1
        }
        sb.write_char('\n')
        write_pad(sb, depth, width)
        sb.write_char(']')
      }
    Object(members) =>
      if members.is_empty() {
        sb.write_string("{}")
      } else {
        sb.write_string("{\n")
        let keys = sorted_keys(members)
        let mut i = 0
        while i < keys.length() {
          if i > 0 {
            sb.write_string(",\n")
          }
          write_pad(sb, depth + 1, width)
          write_json_string(keys[i], sb)
          sb.write_string(": ")
          match members.get(keys[i]) {
            Some(v) => write_json_indented(v, sb, width, depth + 1)
            None => abort("internal error: sorted key missing from object")
          }
          i = i + 1
        }
        sb.write_char('\n')
        write_pad(sb, depth, width)
        sb.write_char('}')
      }
    other => write_json_compact(other, sb)
  }
}

///|
/// Serialize any core `Json` value to a compact JSON string with object
/// keys in sorted order. Used by the CLI for deterministic output.
pub fn stringify_json(j : Json) -> String {
  let sb = StringBuilder::new()
  write_json_compact(j, sb)
  sb.to_string()
}

///|
/// Serialize any core `Json` value to an indented JSON string with
/// object keys in sorted order. `indent` is the number of spaces per
/// nesting level.
pub fn stringify_json_with_indent(j : Json, indent : Int) -> String {
  if indent <= 0 {
    return stringify_json(j)
  }
  let sb = StringBuilder::new()
  write_json_indented(j, sb, indent, 0)
  sb.to_string()
}

///|
/// Serialize a JRD model to a compact, deterministic
/// `application/jrd+json` document.
pub fn serialize_jrd(jrd : JsonResourceDescriptor) -> String {
  stringify_json(jrd_to_json(jrd))
}

///|
/// Serialize a JRD model to an indented, deterministic
/// `application/jrd+json` document.
pub fn serialize_jrd_with_indent(
  jrd : JsonResourceDescriptor,
  indent : Int,
) -> String {
  stringify_json_with_indent(jrd_to_json(jrd), indent)
}

///|
/// Canonicalize a JRD model: stable member order, stable whitespace
/// (compact), stable escaping. Nothing else is changed — no URI case
/// folding, no alias dropping, no link merging or reordering.
pub fn canonicalize_jrd(jrd : JsonResourceDescriptor) -> String {
  serialize_jrd(jrd)
}

///|
/// Canonicalize a raw JRD document (parse, then re-serialize
/// canonically). Fails with a structured error on invalid JSON or on an
/// invalid JRD.
pub fn canonicalize_jrd_text(input : String) -> Result[String, WebFingerError] {
  match parse_jrd(input) {
    Ok(jrd) => Ok(canonicalize_jrd(jrd))
    Err(e) => Err(e)
  }
}
