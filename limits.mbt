///|
/// Resource limits applied while parsing and building JRDs.
///
/// WebFinger data is untrusted input, so every bounded dimension of a JRD
/// (input size, member counts, string lengths, nesting depth) is checked
/// against a `Limits` value. Limits are enforced by *returning errors*,
/// never by silently truncating data.
///
/// `Limits::default()` is the recommended setting for general use;
/// `Limits::strict()` is suitable for constrained or hostile-input
/// environments; `Limits::permissive()` trades memory for flexibility.
///
/// Note on nesting depth: the MoonBit core JSON parser always parses with
/// its own internal depth guard (1024 levels), so `max_nesting_depth` is
/// enforced by a bounded traversal after JSON parsing, as documented in
/// `docs/limitations.md`.

///|
/// All tunable bounds of JRD processing.
pub struct Limits {
  /// Maximum UTF-8 byte length of the JSON input.
  max_input_bytes : Int
  /// Maximum UTF-8 byte length of the `subject` value.
  max_subject_bytes : Int
  /// Maximum number of `aliases` entries.
  max_aliases : Int
  /// Maximum UTF-8 byte length of a single alias URI.
  max_alias_bytes : Int
  /// Maximum number of subject-level properties.
  max_properties : Int
  /// Maximum UTF-8 byte length of a property URI (member name).
  max_property_name_bytes : Int
  /// Maximum UTF-8 byte length of a string property value.
  max_property_value_bytes : Int
  /// Maximum number of links.
  max_links : Int
  /// Maximum number of titles per link.
  max_titles_per_link : Int
  /// Maximum number of properties per link.
  max_properties_per_link : Int
  /// Maximum UTF-8 byte length of any other string member (rel, href,
  /// type, title text, language tag).
  max_string_bytes : Int
  /// Maximum number of unknown top-level members preserved as extensions.
  max_extension_members : Int
  /// Maximum JSON nesting depth accepted by the bounded traversal.
  max_nesting_depth : Int
}

///|
/// Recommended limits for general local processing.
pub fn Limits::default() -> Limits {
  {
    max_input_bytes: 262144,
    max_subject_bytes: 2048,
    max_aliases: 32,
    max_alias_bytes: 2048,
    max_properties: 128,
    max_property_name_bytes: 2048,
    max_property_value_bytes: 65536,
    max_links: 64,
    max_titles_per_link: 16,
    max_properties_per_link: 64,
    max_string_bytes: 65536,
    max_extension_members: 32,
    max_nesting_depth: 32,
  }
}

///|
/// Tight limits for constrained or hostile-input environments.
pub fn Limits::strict() -> Limits {
  {
    max_input_bytes: 16384,
    max_subject_bytes: 512,
    max_aliases: 4,
    max_alias_bytes: 512,
    max_properties: 16,
    max_property_name_bytes: 512,
    max_property_value_bytes: 4096,
    max_links: 8,
    max_titles_per_link: 4,
    max_properties_per_link: 8,
    max_string_bytes: 4096,
    max_extension_members: 4,
    max_nesting_depth: 8,
  }
}

///|
/// Wide limits for large but still bounded descriptors.
pub fn Limits::permissive() -> Limits {
  {
    max_input_bytes: 4194304,
    max_subject_bytes: 16384,
    max_aliases: 1024,
    max_alias_bytes: 16384,
    max_properties: 1024,
    max_property_name_bytes: 16384,
    max_property_value_bytes: 1048576,
    max_links: 1024,
    max_titles_per_link: 64,
    max_properties_per_link: 256,
    max_string_bytes: 1048576,
    max_extension_members: 128,
    max_nesting_depth: 64,
  }
}

///|
/// The UTF-8 byte length of a string, counted without materializing the
/// encoded copy of the whole string. Used to enforce byte limits cheaply
/// before any other processing.
pub fn utf8_byte_length(s : String) -> Int {
  let mut total = 0
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      total = total + 1
    } else if cp < 0x800 {
      total = total + 2
    } else if cp < 0x10000 {
      total = total + 3
    } else {
      total = total + 4
    }
  }
  total
}

///|
/// Whether `s` fits within `limit` UTF-8 bytes.
pub fn within_byte_limit(s : String, limit : Int) -> Bool {
  utf8_byte_length(s) <= limit
}
