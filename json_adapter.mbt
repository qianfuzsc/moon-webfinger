///|
/// Conversion between core `Json` values and the JRD model.
///
/// This module is the parsing heart of the library:
///
/// * it enforces RFC 7033 member types on known members (a JRD is a JSON
///   object whose `subject` is a string, `aliases` an array of strings,
///   `properties` an object of string-or-null values, and `links` an
///   array of link relation objects; RFC 7033 defines no licence to
///   silently accept other shapes, so wrong types are structured errors);
/// * it enforces every `Limits` bound (counts, byte lengths, extension
///   members, nesting depth) — never by silent truncation;
/// * it preserves unknown members as extension `Json` values because
///   RFC 7033 Section 4.4 requires clients to ignore unknown members
///   rather than treat them as errors;
/// * it deliberately does NOT judge URI validity or rel semantics —
///   that belongs to the validator (`validator.mbt`).
///
/// Known members are:
///
/// * top level: `subject`, `aliases`, `properties`, `links`;
/// * per link: `rel`, `type`, `href`, `titles`, `properties`.

///|
/// Internal: the reserved top-level JRD member names.
fn reserved_top_level() -> Array[String] {
  ["subject", "aliases", "properties", "links"]
}

///|
/// Internal: the reserved link member names.
fn reserved_link_members() -> Array[String] {
  ["rel", "type", "href", "titles", "properties"]
}

///|
/// Internal: whether `name` is one of `names`.
fn is_reserved(name : String, names : Array[String]) -> Bool {
  let mut i = 0
  while i < names.length() {
    if name == names[i] {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Internal: byte-length check with a Limit error.
fn check_string_len(s : String, limit : Int, what : String) -> Unit raise {
  if utf8_byte_length(s) > limit {
    raise WebFingerError(
      Limit,
      LimitExceeded,
      None,
      "\{what} exceeds \{limit} bytes",
    )
  }
}

///|
/// Internal: convert a core JSON object member into the model's property
/// map. Keys are property URIs; values must be strings or null per RFC
/// 7033 Section 4.4.3. Enforces count, name-length and value-length
/// limits.
fn json_properties_to_map(
  members : Map[String, Json],
  max_properties : Int,
  max_name_bytes : Int,
  max_value_bytes : Int,
  where_ : String,
) -> Map[String, PropertyValue] raise {
  if members.length() > max_properties {
    raise WebFingerError(
      Limit,
      LimitExceeded,
      None,
      "\{where_}: too many properties (\{members.length()} > \{max_properties})",
    )
  }
  let result : Map[String, PropertyValue] = Map([])
  for name, value in members {
    check_string_len(name, max_name_bytes, "\{where_} property name")
    match value {
      String(s) => {
        check_string_len(s, max_value_bytes, "\{where_} property value")
        result.set(name, StringValue(s))
      }
      Null => result.set(name, NullValue)
      _ =>
        raise WebFingerError(
          Property,
          WrongMemberType,
          None,
          "\{where_}: property value must be a string or null",
        )
    }
  }
  result
}

///|
/// Internal: convert the `titles` object of a link. Keys are language
/// tags or `"und"`; values must be strings (RFC 7033 Section 4.4.4.4).
fn json_titles_to_map(
  members : Map[String, Json],
  max_titles : Int,
  max_string_bytes : Int,
) -> Map[String, String] raise {
  if members.length() > max_titles {
    raise WebFingerError(
      Limit,
      LimitExceeded,
      None,
      "link: too many titles (\{members.length()} > \{max_titles})",
    )
  }
  let result : Map[String, String] = Map([])
  for name, value in members {
    check_string_len(name, max_string_bytes, "title language tag")
    match value {
      String(s) => {
        check_string_len(s, max_string_bytes, "title text")
        result.set(name, s)
      }
      _ =>
        raise WebFingerError(
          Link,
          WrongMemberType,
          None,
          "title value must be a string",
        )
    }
  }
  result
}

///|
/// Internal: extract unknown members of a JSON object as preserved
/// extensions, enforcing the extension-member count limit.
fn json_extensions(
  members : Map[String, Json],
  reserved : Array[String],
  max_extensions : Int,
  where_ : String,
) -> Map[String, Json] raise {
  let result : Map[String, Json] = Map([])
  let mut count = 0
  for name, value in members {
    if !is_reserved(name, reserved) {
      count = count + 1
      if count > max_extensions {
        raise WebFingerError(
          Limit,
          LimitExceeded,
          None,
          "\{where_}: too many unknown members (\{count} > \{max_extensions})",
        )
      }
      result.set(name, value)
    }
  }
  result
}

///|
/// Internal: parse one link relation object.
fn json_to_link(j : Json, limits : Limits, depth : Int) -> JrdLink raise {
  let members = match j {
    Object(m) => m
    _ =>
      raise WebFingerError(
        Link,
        WrongMemberType,
        None,
        "links entries must be objects",
      )
  }
  if depth > limits.max_nesting_depth {
    raise WebFingerError(
      Limit,
      LimitExceeded,
      None,
      "JSON nesting exceeds \{limits.max_nesting_depth} levels",
    )
  }
  // rel: REQUIRED by RFC 7033 Section 4.4.4.1.
  let rel = match members.get("rel") {
    None =>
      raise WebFingerError(
        Link,
        MissingRequiredMember,
        None,
        "link is missing the required 'rel' member",
      )
    Some(String(s)) => {
      check_string_len(s, limits.max_string_bytes, "link rel value")
      s
    }
    Some(_) =>
      raise WebFingerError(
        Link,
        InvalidLink,
        None,
        "link 'rel' must be a string",
      )
  }
  let media_type = match members.get("type") {
    None => None
    Some(String(s)) => {
      check_string_len(s, limits.max_string_bytes, "link type value")
      Some(s)
    }
    Some(_) =>
      raise WebFingerError(
        Link,
        WrongMemberType,
        None,
        "link 'type' must be a string",
      )
  }
  let href = match members.get("href") {
    None => None
    Some(String(s)) => {
      check_string_len(s, limits.max_string_bytes, "link href value")
      Some(s)
    }
    Some(_) =>
      raise WebFingerError(
        Link,
        WrongMemberType,
        None,
        "link 'href' must be a string",
      )
  }
  let titles = match members.get("titles") {
    None => Map([])
    Some(Object(t)) =>
      json_titles_to_map(t, limits.max_titles_per_link, limits.max_string_bytes)
    Some(_) =>
      raise WebFingerError(
        Link,
        WrongMemberType,
        None,
        "link 'titles' must be an object",
      )
  }
  let properties = match members.get("properties") {
    None => Map([])
    Some(Object(p)) =>
      json_properties_to_map(
        p,
        limits.max_properties_per_link,
        limits.max_property_name_bytes,
        limits.max_property_value_bytes,
        "link",
      )
    Some(_) =>
      raise WebFingerError(
        Link,
        WrongMemberType,
        None,
        "link 'properties' must be an object",
      )
  }
  let extensions = json_extensions(
    members,
    reserved_link_members(),
    limits.max_extension_members,
    "link",
  )
  { rel, media_type, href, titles, properties, extensions }
}

///|
/// Internal: JSON to JRD conversion (raise-based; public boundary is in
/// `parser.mbt`). `depth` starts at 1 for the root object.
fn json_to_jrd_inner(
  j : Json,
  limits : Limits,
  depth : Int,
) -> JsonResourceDescriptor raise {
  if depth > limits.max_nesting_depth {
    raise WebFingerError(
      Limit,
      LimitExceeded,
      None,
      "JSON nesting exceeds \{limits.max_nesting_depth} levels",
    )
  }
  let members = match j {
    Object(m) => m
    _ =>
      raise WebFingerError(
        Jrd,
        RootNotObject,
        None,
        "JRD root must be a JSON object",
      )
  }
  let subject = match members.get("subject") {
    None => None
    Some(String(s)) => {
      check_string_len(s, limits.max_subject_bytes, "subject")
      Some(s)
    }
    Some(_) =>
      raise WebFingerError(
        Subject,
        WrongMemberType,
        None,
        "subject must be a string",
      )
  }
  let aliases : Array[String] = []
  match members.get("aliases") {
    None => ()
    Some(Array(arr)) => {
      if arr.length() > limits.max_aliases {
        raise WebFingerError(
          Limit,
          LimitExceeded,
          None,
          "too many aliases (\{arr.length()} > \{limits.max_aliases})",
        )
      }
      for item in arr {
        match item {
          String(s) => {
            check_string_len(s, limits.max_alias_bytes, "alias")
            aliases.push(s)
          }
          _ =>
            raise WebFingerError(
              Alias,
              WrongMemberType,
              None,
              "aliases entries must be strings",
            )
        }
      }
    }
    Some(_) =>
      raise WebFingerError(
        Alias,
        WrongMemberType,
        None,
        "aliases must be an array",
      )
  }
  let properties = match members.get("properties") {
    None => Map([])
    Some(Object(p)) =>
      json_properties_to_map(
        p,
        limits.max_properties,
        limits.max_property_name_bytes,
        limits.max_property_value_bytes,
        "jrd",
      )
    Some(_) =>
      raise WebFingerError(
        Property,
        WrongMemberType,
        None,
        "properties must be an object",
      )
  }
  let links : Array[JrdLink] = []
  match members.get("links") {
    None => ()
    Some(Array(arr)) => {
      if arr.length() > limits.max_links {
        raise WebFingerError(
          Limit,
          LimitExceeded,
          None,
          "too many links (\{arr.length()} > \{limits.max_links})",
        )
      }
      for item in arr {
        links.push(json_to_link(item, limits, depth + 1))
      }
    }
    Some(_) =>
      raise WebFingerError(
        Link,
        WrongMemberType,
        None,
        "links must be an array",
      )
  }
  let extensions = json_extensions(
    members,
    reserved_top_level(),
    limits.max_extension_members,
    "jrd",
  )
  { subject, aliases, properties, links, extensions }
}

///|
/// Convert a parsed core `Json` value into the JRD model under the given
/// limits. Public, but `parse_jrd` is the usual entry point.
pub fn json_to_jrd(
  j : Json,
  limits : Limits,
) -> Result[JsonResourceDescriptor, WebFingerError] {
  Ok(json_to_jrd_inner(j, limits, 1)) catch {
    e => Err(unwrap_webfinger_error(e))
  }
}

///|
/// The nesting depth of a JSON value: `1` for a scalar, one more for
/// each enclosing container. Implemented iteratively so that deeply
/// nested inputs cannot overflow the stack.
pub fn json_depth(j : Json) -> Int {
  let mut max_depth = 1
  let stack : Array[(Json, Int)] = [(j, 1)]
  while stack.length() > 0 {
    let top = stack[stack.length() - 1]
    let (value, depth) = top
    ignore(stack.pop())
    if depth > max_depth {
      max_depth = depth
    }
    match value {
      Array(arr) =>
        for item in arr {
          stack.push((item, depth + 1))
        }
      Object(members) =>
        for _k, v in members {
          stack.push((v, depth + 1))
        }
      _ => ()
    }
  }
  max_depth
}

///|
/// Internal: model property map to core JSON object.
fn property_map_to_json(m : Map[String, PropertyValue]) -> Json {
  let members : Map[String, Json] = Map([])
  for name, value in m {
    match value {
      StringValue(s) => members.set(name, Json::string(s))
      NullValue => members.set(name, Json::null())
    }
  }
  Json::object(members)
}

///|
/// Internal: model title map to core JSON object.
fn title_map_to_json(m : Map[String, String]) -> Json {
  let members : Map[String, Json] = Map([])
  for name, value in m {
    members.set(name, Json::string(value))
  }
  Json::object(members)
}

///|
/// Internal: a link model to core JSON with the canonical member order
/// rel, type, href, titles, properties, then preserved extensions.
fn link_to_json(link : JrdLink) -> Json {
  let members : Map[String, Json] = Map([])
  members.set("rel", Json::string(link.rel))
  match link.media_type {
    Some(t) => members.set("type", Json::string(t))
    None => ()
  }
  match link.href {
    Some(h) => members.set("href", Json::string(h))
    None => ()
  }
  if !link.titles.is_empty() {
    members.set("titles", title_map_to_json(link.titles))
  }
  if !link.properties.is_empty() {
    members.set("properties", property_map_to_json(link.properties))
  }
  for name, value in link.extensions {
    members.set(name, value)
  }
  Json::object(members)
}

///|
/// A single link model as a core `Json` value with the canonical member
/// order (rel, type, href, titles, properties, extensions). Useful for
/// CLI output and tooling.
pub fn link_model_to_json(link : JrdLink) -> Json {
  link_to_json(link)
}

///|
/// The model as a core `Json` value with the canonical member order:
/// subject, aliases, properties, links, then preserved extensions. Note
/// that JSON object member order carries no semantics; this order exists
/// only to make serialization deterministic.
pub fn jrd_to_json(jrd : JsonResourceDescriptor) -> Json {
  let members : Map[String, Json] = Map([])
  match jrd.subject {
    Some(s) => members.set("subject", Json::string(s))
    None => ()
  }
  if jrd.aliases.length() > 0 {
    let alias_json : Array[Json] = []
    for a in jrd.aliases {
      alias_json.push(Json::string(a))
    }
    members.set("aliases", Json::array(alias_json))
  }
  if !jrd.properties.is_empty() {
    members.set("properties", property_map_to_json(jrd.properties))
  }
  if jrd.links.length() > 0 {
    let link_json : Array[Json] = []
    for link in jrd.links {
      link_json.push(link_to_json(link))
    }
    members.set("links", Json::array(link_json))
  }
  for name, value in jrd.extensions {
    members.set(name, value)
  }
  Json::object(members)
}
