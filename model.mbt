///|
/// The JRD data model: `JsonResourceDescriptor`, `JrdLink`,
/// `PropertyValue`, and semantic-equality helpers.
///
/// The model follows RFC 7033 Section 4.4:
///
/// * `subject` — OPTIONAL per the RFC (SHOULD be present); a URI string.
/// * `aliases` — OPTIONAL; array of URI strings.
/// * `properties` — OPTIONAL; property URI mapped to a string or null.
/// * `links` — OPTIONAL; array of link relation objects; array order MAY
///   indicate preference (first link is the preferred one).
///
/// In addition, unknown members (top level and per link) are preserved in
/// `extensions` maps: RFC 7033 Section 4.4 requires that clients MUST
/// ignore unknown members and not treat them as errors, so the parser
/// keeps them for forward-compatible round-tripping instead of dropping
/// them. Unknown members never influence validation or queries.
///
/// `rel` is REQUIRED by RFC 7033 in every link relation object, so
/// `JrdLink.rel` is a plain `String` (not optional) — a parsed model can
/// only ever contain links that had a rel member.

///|
/// A JRD property value: RFC 7033 allows properties (both subject-level
/// and link-level) to hold either a string or JSON null.
pub enum PropertyValue {
  StringValue(String)
  NullValue
} derive(Eq)

///|
/// Construct a string property value. Provided because the enum variants
/// themselves are read-only for consumer packages.
pub fn PropertyValue::string(s : String) -> PropertyValue {
  StringValue(s)
}

///|
/// Construct a null property value. Provided because the enum variants
/// themselves are read-only for consumer packages.
pub fn PropertyValue::null() -> PropertyValue {
  NullValue
}

///|
/// Whether this property value is null.
pub fn PropertyValue::is_null(self : PropertyValue) -> Bool {
  match self {
    NullValue => true
    _ => false
  }
}

///|
/// The string payload, or `None` for a null value.
pub fn PropertyValue::as_string(self : PropertyValue) -> String? {
  match self {
    StringValue(s) => Some(s)
    NullValue => None
  }
}

///|
/// A stable display form for tests and CLI output.
pub fn PropertyValue::to_display(self : PropertyValue) -> String {
  match self {
    StringValue(s) => s
    NullValue => "<null>"
  }
}

///|
/// A link relation object as defined by RFC 7033 Section 4.4.4.
///
/// Members:
///
/// * `rel` — REQUIRED; exactly one URI or registered relation type.
/// * `media_type` — OPTIONAL; the media type of the link target (`type`).
/// * `href` — OPTIONAL; the target URI.
/// * `titles` — OPTIONAL; language tag (or `"und"`) to human-readable
///   title. RFC 7033 says a JRD SHOULD NOT repeat a language tag, but
///   repetition MUST NOT be treated as an error; the underlying JSON
///   parser collapses duplicate object keys before the library sees them
///   (see `docs/limitations.md`).
/// * `properties` — OPTIONAL; property URI to string-or-null value.
/// * `extensions` — unknown link members, preserved for round-tripping.
pub struct JrdLink {
  rel : String
  media_type : String?
  href : String?
  titles : Map[String, String]
  properties : Map[String, PropertyValue]
  extensions : Map[String, Json]
}

///|
/// Create an empty link with the given (non-validated) relation type.
pub fn JrdLink::new(rel : String) -> JrdLink {
  {
    rel,
    media_type: None,
    href: None,
    titles: Map([]),
    properties: Map([]),
    extensions: Map([]),
  }
}

///|
/// Case-insensitive (ASCII) lookup of a title by language tag. Used after
/// an exact lookup missed; if several keys differ only by case, the first
/// one in map order wins.
fn find_title_ci(titles : Map[String, String], tag : String) -> String? {
  let wanted = tag.to_lower()
  for k, v in titles {
    if k.to_lower() == wanted {
      return Some(v)
    }
  }
  None
}

///|
/// Whether this link carries a title for exactly the given language tag.
/// The match is exact first, then ASCII case-insensitive; full RFC 4647
/// language negotiation is out of scope (see `docs/limitations.md`).
pub fn JrdLink::has_title(self : JrdLink, language : String) -> Bool {
  self.titles.contains(language) ||
  find_title_ci(self.titles, language) is Some(_)
}

///|
/// The title for exactly the given language tag (exact match preferred,
/// then ASCII case-insensitive), or `None`.
pub fn JrdLink::title(self : JrdLink, language : String) -> String? {
  match self.titles.get(language) {
    Some(t) => Some(t)
    None => find_title_ci(self.titles, language)
  }
}

///|
/// The first title whose language tag appears in `languages`, in the
/// caller-given priority order, or `None`. Exact, ASCII case-insensitive
/// matching; no RFC 4647 negotiation.
pub fn JrdLink::preferred_title(
  self : JrdLink,
  languages : Array[String],
) -> String? {
  for lang in languages {
    match self.title(lang) {
      Some(t) => return Some(t)
      None => continue
    }
  }
  None
}

///|
/// A deterministic fallback title when the caller has no language
/// preference: the `"und"` title if present, otherwise the title with the
/// lexicographically smallest language tag, otherwise `None`.
pub fn JrdLink::fallback_title(self : JrdLink) -> String? {
  match self.titles.get("und") {
    Some(t) => return Some(t)
    None => ()
  }
  let tags : Array[String] = []
  for k in self.titles.keys() {
    tags.push(k)
  }
  if tags.length() == 0 {
    return None
  }
  tags.sort()
  self.titles.get(tags[0])
}

///|
/// Whether this link has a title in any language.
pub fn JrdLink::has_any_title(self : JrdLink) -> Bool {
  !self.titles.is_empty()
}

///|
/// A link property value, or `None` if absent.
pub fn JrdLink::property(self : JrdLink, uri : String) -> PropertyValue? {
  self.properties.get(uri)
}

///|
/// Whether this link has a property with the given URI.
pub fn JrdLink::has_property(self : JrdLink, uri : String) -> Bool {
  self.properties.contains(uri)
}

///|
/// The library version. Mirrors `version` in moon.mod; both must be
/// updated together (single source discipline documented in
/// `docs/reproduction.md`).
pub fn library_version() -> String {
  "0.1.0"
}

///|
/// A JSON Resource Descriptor as defined by RFC 7033 Section 4.4.
pub struct JsonResourceDescriptor {
  subject : String?
  aliases : Array[String]
  properties : Map[String, PropertyValue]
  links : Array[JrdLink]
  extensions : Map[String, Json]
}

///|
/// Create an empty JRD (no subject, no aliases, no properties, no links).
pub fn JsonResourceDescriptor::empty() -> JsonResourceDescriptor {
  {
    subject: None,
    aliases: [],
    properties: Map([]),
    links: [],
    extensions: Map([]),
  }
}

///|
/// The number of links in this JRD.
pub fn JsonResourceDescriptor::link_count(self : JsonResourceDescriptor) -> Int {
  self.links.length()
}

///|
/// A subject-level property value, or `None` if absent.
pub fn JsonResourceDescriptor::property(
  self : JsonResourceDescriptor,
  uri : String,
) -> PropertyValue? {
  self.properties.get(uri)
}

///|
/// Whether this JRD has a subject-level property with the given URI.
pub fn JsonResourceDescriptor::has_property(
  self : JsonResourceDescriptor,
  uri : String,
) -> Bool {
  self.properties.contains(uri)
}

///|
/// Whether this JRD carries any unknown (extension) top-level members.
pub fn JsonResourceDescriptor::has_extensions(
  self : JsonResourceDescriptor,
) -> Bool {
  !self.extensions.is_empty()
}

///|
/// Semantic equality of two property maps: same keys, and for each key
/// equal values. Key order is irrelevant.
fn property_maps_equal(
  a : Map[String, PropertyValue],
  b : Map[String, PropertyValue],
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for k, v in a {
    match b.get(k) {
      Some(w) => if v != w { return false }
      None => return false
    }
  }
  true
}

///|
/// Semantic equality of two title maps (key order irrelevant).
fn title_maps_equal(a : Map[String, String], b : Map[String, String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for k, v in a {
    match b.get(k) {
      Some(w) => if v != w { return false }
      None => return false
    }
  }
  true
}

///|
/// Element-wise equality of string arrays (MoonBit `Array` has no
/// structural `==`, so this helper exists).
pub fn same_strings(a : Array[String], b : Array[String]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    if a[i] != b[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Semantic equality of two links: all members compared structurally,
/// with map and array key/element order ignored.
pub fn jrd_link_semantic_equal(a : JrdLink, b : JrdLink) -> Bool {
  a.rel == b.rel &&
  a.media_type == b.media_type &&
  a.href == b.href &&
  title_maps_equal(a.titles, b.titles) &&
  property_maps_equal(a.properties, b.properties) &&
  a.extensions == b.extensions
}

///|
/// Semantic equality of two links arrays (order matters: RFC 7033 says
/// links array order MAY indicate preference, so it is semantic).
pub fn jrd_links_semantic_equal(a : Array[JrdLink], b : Array[JrdLink]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let mut i = 0
  while i < a.length() {
    if !jrd_link_semantic_equal(a[i], b[i]) {
      return false
    }
    i = i + 1
  }
  true
}

///|
/// Semantic equality of two JRDs. Used by the deterministic property
/// tests (model -> serialize -> parse -> compare). Member order inside
/// JSON objects is ignored; `links` array order is preserved because it
/// can carry preference information.
pub fn jrd_semantic_equal(
  a : JsonResourceDescriptor,
  b : JsonResourceDescriptor,
) -> Bool {
  a.subject == b.subject &&
  same_strings(a.aliases, b.aliases) &&
  property_maps_equal(a.properties, b.properties) &&
  jrd_links_semantic_equal(a.links, b.links) &&
  a.extensions == b.extensions
}
