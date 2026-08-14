///|
/// Query helpers over the local JRD model.
///
/// Everything here reads the in-memory model only. Link hrefs, aliases
/// and property URIs are returned strictly as data: the library never
/// dereferences or follows them, and the caller is responsible for any
/// network access policy (see `docs/security.md`).
///
/// rel matching is exact string comparison. RFC 7033 Section 4.4.4.1
/// compares URI relation types with RFC 3986 Section 6.2.1 Simple String
/// Comparison (case-insensitive scheme and host); token relation types
/// are conventionally compared case-insensitively too, but this library
/// deliberately exposes exact matching and leaves normalization policy
/// to the caller.

///|
/// A relation type and how many links carry it. Produced by
/// `relation_summary` in lexically sorted rel order.
pub struct RelationCount {
  rel : String
  count : Int
}

///|
/// A copy of the links array (model order preserved; RFC 7033 says links
/// array order MAY indicate preference).
pub fn links(jrd : JsonResourceDescriptor) -> Array[JrdLink] {
  let copy : Array[JrdLink] = []
  for link in jrd.links {
    copy.push(link)
  }
  copy
}

///|
/// All links whose rel equals `rel` exactly, in model order.
pub fn find_links_by_rel(
  jrd : JsonResourceDescriptor,
  rel : String,
) -> Array[JrdLink] {
  let found : Array[JrdLink] = []
  for link in jrd.links {
    if link.rel == rel {
      found.push(link)
    }
  }
  found
}

///|
/// All links whose rel equals `rel` exactly and whose type equals
/// `media_type` exactly, in model order.
pub fn find_links_by_rel_and_type(
  jrd : JsonResourceDescriptor,
  rel : String,
  media_type : String,
) -> Array[JrdLink] {
  let found : Array[JrdLink] = []
  for link in jrd.links {
    if link.rel == rel {
      match link.media_type {
        Some(t) => if t == media_type { found.push(link) }
        None => ()
      }
    }
  }
  found
}

///|
/// The first link with the given rel (model order — i.e. the preferred
/// one when the server uses order to express preference), or `None`.
pub fn first_link_by_rel(
  jrd : JsonResourceDescriptor,
  rel : String,
) -> JrdLink? {
  for link in jrd.links {
    if link.rel == rel {
      return Some(link)
    }
  }
  None
}

///|
/// The hrefs of all links with the given rel, in model order. Links
/// without an href are skipped.
pub fn hrefs_by_rel(
  jrd : JsonResourceDescriptor,
  rel : String,
) -> Array[String] {
  let found : Array[String] = []
  for link in jrd.links {
    if link.rel == rel {
      match link.href {
        Some(h) => found.push(h)
        None => ()
      }
    }
  }
  found
}

///|
/// The href of the first link with the given rel, or `None`. The href is
/// returned as data only; it is never fetched.
pub fn first_href(jrd : JsonResourceDescriptor, rel : String) -> String? {
  match first_link_by_rel(jrd, rel) {
    Some(link) => link.href
    None => None
  }
}

///|
/// All links whose type equals `media_type` exactly, in model order.
pub fn links_by_type(
  jrd : JsonResourceDescriptor,
  media_type : String,
) -> Array[JrdLink] {
  let found : Array[JrdLink] = []
  for link in jrd.links {
    match link.media_type {
      Some(t) => if t == media_type { found.push(link) }
      None => ()
    }
  }
  found
}

///|
/// A copy of the aliases array (model order preserved).
pub fn all_aliases(jrd : JsonResourceDescriptor) -> Array[String] {
  let copy : Array[String] = []
  for alias in jrd.aliases {
    copy.push(alias)
  }
  copy
}

///|
/// A subject-level property value, or `None`. A null property returns
/// `Some(PropertyValue::null())`; use `is_null` to distinguish it from
/// an absent property.
pub fn property_value(
  jrd : JsonResourceDescriptor,
  uri : String,
) -> PropertyValue? {
  jrd.properties.get(uri)
}

///|
/// A subject-level property rendered for display: the string value, or
/// `"null"` for an explicit null, or `None` when absent.
pub fn property_string(jrd : JsonResourceDescriptor, uri : String) -> String? {
  match jrd.properties.get(uri) {
    None => None
    Some(StringValue(s)) => Some(s)
    Some(NullValue) => Some("null")
  }
}

///|
/// Per-rel link counts, sorted lexically by rel.
pub fn relation_summary(jrd : JsonResourceDescriptor) -> Array[RelationCount] {
  let counts : Map[String, Int] = Map([])
  for link in jrd.links {
    match counts.get(link.rel) {
      Some(n) => counts.set(link.rel, n + 1)
      None => counts.set(link.rel, 1)
    }
  }
  let rels : Array[String] = []
  for k in counts.keys() {
    rels.push(k)
  }
  rels.sort()
  let summary : Array[RelationCount] = []
  for rel in rels {
    match counts.get(rel) {
      Some(n) => summary.push({ rel, count: n })
      None => ()
    }
  }
  summary
}

///|
/// The number of links with the given rel.
pub fn link_count_by_rel(jrd : JsonResourceDescriptor, rel : String) -> Int {
  find_links_by_rel(jrd, rel).length()
}
