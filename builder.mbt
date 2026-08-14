///|
/// Fluent builders for JRDs and links.
///
/// The builders collect members step by step and validate everything on
/// `build()`, which always returns a `Result` — no `unwrap`, no panic.
/// Validation applies the RFC constraints plus `Limits::default()`
/// bounds:
///
/// * subject and aliases must be absolute URIs (RFC 7033 Sections 4.4.1
///   and 4.4.2);
/// * property identifiers must be URIs (Sections 4.4.3 and 4.4.4.5);
/// * rel must be exactly one URI or registered relation type (Section
///   4.4.4.1);
/// * href must be an absolute URI (Section 4.4.4.3);
/// * title keys must be plausible language tags or `und` (Section
///   4.4.4.4);
/// * extension member names must not collide with reserved members
///   (DuplicateReservedExtension).
///
/// Setters store values without validation so callers can build
/// incrementally; only `build()` reports problems.

///|
/// Builds a `JsonResourceDescriptor` fluently.
pub struct JrdBuilder {
  mut subject : String?
  aliases : Array[String]
  properties : Map[String, PropertyValue]
  links : Array[JrdLink]
  extensions : Map[String, Json]
}

///|
/// Start an empty JRD builder.
pub fn JrdBuilder::new() -> JrdBuilder {
  {
    subject: None,
    aliases: [],
    properties: Map([]),
    links: [],
    extensions: Map([]),
  }
}

///|
/// Set the subject (validated on build).
pub fn JrdBuilder::subject(self : JrdBuilder, s : String) -> JrdBuilder {
  self.subject = Some(s)
  self
}

///|
/// Add an alias (validated on build).
pub fn JrdBuilder::alias(self : JrdBuilder, a : String) -> JrdBuilder {
  self.aliases.push(a)
  self
}

///|
/// Add a subject-level property with an explicit value (name validated
/// on build).
pub fn JrdBuilder::property(
  self : JrdBuilder,
  uri : String,
  value : PropertyValue,
) -> JrdBuilder {
  self.properties.set(uri, value)
  self
}

///|
/// Add a subject-level string property (name validated on build).
pub fn JrdBuilder::property_string(
  self : JrdBuilder,
  uri : String,
  s : String,
) -> JrdBuilder {
  self.properties.set(uri, StringValue(s))
  self
}

///|
/// Add a subject-level null property (name validated on build).
pub fn JrdBuilder::property_null(self : JrdBuilder, uri : String) -> JrdBuilder {
  self.properties.set(uri, NullValue)
  self
}

///|
/// Add a link (the link itself is validated on build).
pub fn JrdBuilder::link(self : JrdBuilder, link : JrdLink) -> JrdBuilder {
  self.links.push(link)
  self
}

///|
/// Add an unknown (extension) top-level member, preserved for
/// round-tripping. The name must not collide with a reserved member
/// (checked on build).
pub fn JrdBuilder::extension(
  self : JrdBuilder,
  name : String,
  value : Json,
) -> JrdBuilder {
  self.extensions.set(name, value)
  self
}

///|
/// Build the JRD, validating subject, aliases, property names, links and
/// extension names, and enforcing `Limits::default()` bounds.
pub fn JrdBuilder::build(
  self : JrdBuilder,
) -> Result[JsonResourceDescriptor, WebFingerError] {
  let limits = Limits::default()
  match self.subject {
    None => ()
    Some(s) =>
      match check_absolute_uri(s) {
        Ok(_) =>
          if utf8_byte_length(s) > limits.max_subject_bytes {
            return Err(
              WebFingerError(
                Subject,
                LimitExceeded,
                None,
                "subject exceeds \{limits.max_subject_bytes} bytes",
              ),
            )
          }
        Err(_) =>
          return Err(
            WebFingerError(
              Subject,
              InvalidUri,
              None,
              "subject must be an absolute URI",
            ),
          )
      }
  }
  if self.aliases.length() > limits.max_aliases {
    return Err(
      WebFingerError(
        Alias,
        LimitExceeded,
        None,
        "too many aliases (\{self.aliases.length()} > \{limits.max_aliases})",
      ),
    )
  }
  for alias in self.aliases {
    match check_absolute_uri(alias) {
      Ok(_) =>
        if utf8_byte_length(alias) > limits.max_alias_bytes {
          return Err(
            WebFingerError(
              Alias,
              LimitExceeded,
              None,
              "alias exceeds \{limits.max_alias_bytes} bytes",
            ),
          )
        }
      Err(_) =>
        return Err(
          WebFingerError(
            Alias,
            InvalidUri,
            None,
            "alias must be an absolute URI: \{alias}",
          ),
        )
    }
  }
  if self.properties.length() > limits.max_properties {
    return Err(
      WebFingerError(
        Property,
        LimitExceeded,
        None,
        "too many properties (\{self.properties.length()} > \{limits.max_properties})",
      ),
    )
  }
  for name, value in self.properties {
    match check_absolute_uri(name) {
      Ok(_) => ()
      Err(_) =>
        return Err(
          WebFingerError(
            Property,
            InvalidProperty,
            None,
            "property name must be a URI: \{name}",
          ),
        )
    }
    match value {
      StringValue(s) =>
        if utf8_byte_length(s) > limits.max_property_value_bytes {
          return Err(
            WebFingerError(
              Property,
              LimitExceeded,
              None,
              "property value exceeds \{limits.max_property_value_bytes} bytes",
            ),
          )
        }
      NullValue => ()
    }
  }
  if self.links.length() > limits.max_links {
    return Err(
      WebFingerError(
        Link,
        LimitExceeded,
        None,
        "too many links (\{self.links.length()} > \{limits.max_links})",
      ),
    )
  }
  for link in self.links {
    match check_link_model(link, limits) {
      Ok(_) => ()
      Err(e) => return Err(e)
    }
  }
  if self.extensions.length() > limits.max_extension_members {
    return Err(
      WebFingerError(
        Builder,
        LimitExceeded,
        None,
        "too many extension members (\{self.extensions.length()} > \{limits.max_extension_members})",
      ),
    )
  }
  for name in self.extensions.keys() {
    if is_reserved(name, reserved_top_level()) {
      return Err(
        WebFingerError(
          Builder,
          DuplicateReservedExtension,
          None,
          "extension member name is reserved: \{name}",
        ),
      )
    }
  }
  Ok({
    subject: self.subject,
    aliases: self.aliases,
    properties: self.properties,
    links: self.links,
    extensions: self.extensions,
  })
}

///|
/// Internal: validate a link model (used by JrdBuilder and by the CLI's
/// validation paths). Checks rel, href, title keys, property names,
/// extension names and link-level limits.
fn check_link_model(
  link : JrdLink,
  limits : Limits,
) -> Result[Unit, WebFingerError] {
  match check_rel_value(link.rel) {
    Ok(_) => ()
    Err(_) =>
      return Err(
        WebFingerError(
          Link,
          InvalidRelValue,
          None,
          "rel must be a URI or a registered relation type: \{link.rel}",
        ),
      )
  }
  match link.href {
    None => ()
    Some(href) =>
      match check_absolute_uri(href) {
        Ok(_) =>
          if utf8_byte_length(href) > limits.max_string_bytes {
            return Err(
              WebFingerError(
                Link,
                LimitExceeded,
                None,
                "href exceeds \{limits.max_string_bytes} bytes",
              ),
            )
          }
        Err(_) =>
          return Err(
            WebFingerError(
              Link,
              InvalidUri,
              None,
              "href must be an absolute URI: \{href}",
            ),
          )
      }
  }
  if link.titles.length() > limits.max_titles_per_link {
    return Err(
      WebFingerError(
        Link,
        LimitExceeded,
        None,
        "too many titles (\{link.titles.length()} > \{limits.max_titles_per_link})",
      ),
    )
  }
  for tag, text in link.titles {
    if !is_plausible_language_tag(tag) {
      return Err(
        WebFingerError(
          Link,
          InvalidLanguageTag,
          None,
          "title key is not a plausible language tag or 'und': \{tag}",
        ),
      )
    }
    if utf8_byte_length(text) > limits.max_string_bytes {
      return Err(
        WebFingerError(
          Link,
          LimitExceeded,
          None,
          "title text exceeds \{limits.max_string_bytes} bytes",
        ),
      )
    }
  }
  if link.properties.length() > limits.max_properties_per_link {
    return Err(
      WebFingerError(
        Link,
        LimitExceeded,
        None,
        "too many link properties (\{link.properties.length()} > \{limits.max_properties_per_link})",
      ),
    )
  }
  for name, value in link.properties {
    match check_absolute_uri(name) {
      Ok(_) => ()
      Err(_) =>
        return Err(
          WebFingerError(
            Property,
            InvalidProperty,
            None,
            "link property name must be a URI: \{name}",
          ),
        )
    }
    match value {
      StringValue(s) =>
        if utf8_byte_length(s) > limits.max_property_value_bytes {
          return Err(
            WebFingerError(
              Property,
              LimitExceeded,
              None,
              "link property value exceeds \{limits.max_property_value_bytes} bytes",
            ),
          )
        }
      NullValue => ()
    }
  }
  for name in link.extensions.keys() {
    if is_reserved(name, reserved_link_members()) {
      return Err(
        WebFingerError(
          Builder,
          DuplicateReservedExtension,
          None,
          "extension member name is reserved: \{name}",
        ),
      )
    }
  }
  Ok(())
}

///|
/// Builds a `JrdLink` fluently.
pub struct JrdLinkBuilder {
  rel : String
  mut media_type : String?
  mut href : String?
  titles : Map[String, String]
  properties : Map[String, PropertyValue]
  extensions : Map[String, Json]
}

///|
/// Start a link builder with its (required) relation type, validated on
/// build.
pub fn JrdLinkBuilder::new(rel : String) -> JrdLinkBuilder {
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
/// Set the target media type (the `type` member).
pub fn JrdLinkBuilder::media_type(
  self : JrdLinkBuilder,
  t : String,
) -> JrdLinkBuilder {
  self.media_type = Some(t)
  self
}

///|
/// Set the target URI (validated on build).
pub fn JrdLinkBuilder::href(
  self : JrdLinkBuilder,
  h : String,
) -> JrdLinkBuilder {
  self.href = Some(h)
  self
}

///|
/// Add a title in a language (key validated on build; `und` allowed).
pub fn JrdLinkBuilder::title(
  self : JrdLinkBuilder,
  language : String,
  text : String,
) -> JrdLinkBuilder {
  self.titles.set(language, text)
  self
}

///|
/// Add a link property with an explicit value (name validated on build).
pub fn JrdLinkBuilder::property(
  self : JrdLinkBuilder,
  uri : String,
  value : PropertyValue,
) -> JrdLinkBuilder {
  self.properties.set(uri, value)
  self
}

///|
/// Add a string link property.
pub fn JrdLinkBuilder::property_string(
  self : JrdLinkBuilder,
  uri : String,
  s : String,
) -> JrdLinkBuilder {
  self.properties.set(uri, StringValue(s))
  self
}

///|
/// Add a null link property.
pub fn JrdLinkBuilder::property_null(
  self : JrdLinkBuilder,
  uri : String,
) -> JrdLinkBuilder {
  self.properties.set(uri, NullValue)
  self
}

///|
/// Add an unknown link member, preserved for round-tripping (name
/// checked on build).
pub fn JrdLinkBuilder::extension(
  self : JrdLinkBuilder,
  name : String,
  value : Json,
) -> JrdLinkBuilder {
  self.extensions.set(name, value)
  self
}

///|
/// Build the link, validating rel, href, title keys, property names and
/// extension names.
pub fn JrdLinkBuilder::build(
  self : JrdLinkBuilder,
) -> Result[JrdLink, WebFingerError] {
  let link : JrdLink = {
    rel: self.rel,
    media_type: self.media_type,
    href: self.href,
    titles: self.titles,
    properties: self.properties,
    extensions: self.extensions,
  }
  match check_link_model(link, Limits::default()) {
    Ok(_) => Ok(link)
    Err(e) => Err(e)
  }
}
