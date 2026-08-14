// parse_jrd — parse the RFC 7033 Section 3.2 example JRD locally and
// render its members. The document never leaves the process.

///|
fn main {
  // Reconstructed from the RFC 7033 Section 3.2 example response (see
  // THIRD_PARTY_NOTICES.md).
  let input = "{\n" +
    "  \"subject\" : \"http://blog.example.com/article/id/314\",\n" +
    "  \"aliases\" :\n" +
    "  [\n" +
    "    \"http://blog.example.com/cool_new_thing\",\n" +
    "    \"http://blog.example.com/steve/article/7\"\n" +
    "  ],\n" +
    "  \"properties\" :\n" +
    "  {\n" +
    "    \"http://blgx.example.net/ns/version\" : \"1.3\",\n" +
    "    \"http://blgx.example.net/ns/ext\" : null\n" +
    "  },\n" +
    "  \"links\" :\n" +
    "  [\n" +
    "    {\n" +
    "      \"rel\" : \"copyright\",\n" +
    "      \"href\" : \"http://www.example.com/copyright\"\n" +
    "    },\n" +
    "    {\n" +
    "      \"rel\" : \"author\",\n" +
    "      \"href\" : \"http://blog.example.com/author/steve\",\n" +
    "      \"titles\" :\n" +
    "      {\n" +
    "        \"en-us\" : \"The Magical World of Steve\",\n" +
    "        \"fr\" : \"Le Monde Magique de Steve\"\n" +
    "      },\n" +
    "      \"properties\" :\n" +
    "      {\n" +
    "        \"http://example.com/role\" : \"editor\"\n" +
    "      }\n" +
    "    }\n" +
    "  ]\n" +
    "}"
  match @wf.parse_jrd(input) {
    Ok(jrd) => {
      let subject_text = match jrd.subject {
        Some(s) => s
        None => "(absent)"
      }
      println("subject:     \{subject_text}")
      println("aliases:     \{jrd.aliases.length()}")
      for alias in jrd.aliases {
        println("  - \{alias}")
      }
      println("properties:  \{jrd.properties.length()}")
      for link in jrd.links {
        let href_text = match link.href {
          Some(h) => h
          None => "(absent)"
        }
        println("link rel=\{link.rel} href=\{href_text}")
        for tag in ["en-us", "fr", "und"] {
          match link.title(tag) {
            Some(t) => println("  title[\{tag}] = \{t}")
            None => ()
          }
        }
        match link.preferred_title(["fr", "en-us"]) {
          Some(t) => println("  preferred(fr,en-us) = \{t}")
          None => ()
        }
      }
    }
    Err(e) => println("parse failed: \{e.to_display()}")
  }
}
