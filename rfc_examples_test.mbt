// Tests reconstructed from RFC 7033 examples. The fixture documents are
// re-built from the RFC's example responses (Sections 3.1, 3.2 and 4.3);
// see THIRD_PARTY_NOTICES.md for the source attribution.

///|
/// The RFC 7033 Section 3.1 OpenID Connect issuer response.
fn rfc_3_1_jrd() -> String {
  "{\n" +
  "  \"subject\" : \"acct:carol@example.com\",\n" +
  "  \"links\" :\n" +
  "  [\n" +
  "    {\n" +
  "      \"rel\" : \"http://openid.net/specs/connect/1.0/issuer\",\n" +
  "      \"href\" : \"https://openid.example.com\"\n" +
  "    }\n" +
  "  ]\n" +
  "}"
}

///|
/// The RFC 7033 Section 3.2 blog example response.
fn rfc_3_2_jrd() -> String {
  "{\n" +
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
}

///|
/// The RFC 7033 Section 4.3 two-rel example response.
fn rfc_4_3_jrd() -> String {
  "{\n" +
  "  \"subject\" : \"acct:bob@example.com\",\n" +
  "  \"aliases\" :\n" +
  "  [\n" +
  "    \"https://www.example.com/~bob/\"\n" +
  "  ],\n" +
  "  \"properties\" :\n" +
  "  {\n" +
  "    \"http://example.com/ns/role\" : \"employee\"\n" +
  "  },\n" +
  "  \"links\" :\n" +
  "  [\n" +
  "    {\n" +
  "      \"rel\" : \"http://webfinger.example/rel/profile-page\",\n" +
  "      \"href\" : \"https://www.example.com/~bob/\"\n" +
  "    },\n" +
  "    {\n" +
  "      \"rel\" : \"http://webfinger.example/rel/businesscard\",\n" +
  "      \"href\" : \"https://www.example.com/~bob/bob.vcf\"\n" +
  "    }\n" +
  "  ]\n" +
  "}"
}

///|
test "rfc 7033 3.1 issuer discovery parses" {
  let jrd = expect_parse(rfc_3_1_jrd())
  assert_eq(jrd.subject, Some("acct:carol@example.com"), msg="subject")
  assert_eq(jrd.links.length(), 1, msg="links")
  assert_eq(
    jrd.links[0].rel,
    "http://openid.net/specs/connect/1.0/issuer",
    msg="rel",
  )
  assert_eq(jrd.links[0].href, Some("https://openid.example.com"), msg="href")
}

///|
test "rfc 7033 3.1 request target matches the RFC example" {
  match
    build_request_target_with_rels("acct:carol@example.com", [
      "http://openid.net/specs/connect/1.0/issuer",
    ]) {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=acct%3Acarol%40example.com&rel=http%3A%2F%2Fopenid.net%2Fspecs%2Fconnect%2F1.0%2Fissuer",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "rfc 7033 3.2 blog example parses" {
  let jrd = expect_parse(rfc_3_2_jrd())
  assert_eq(
    jrd.subject,
    Some("http://blog.example.com/article/id/314"),
    msg="subject",
  )
  assert_eq(jrd.aliases.length(), 2, msg="aliases")
  assert_eq(jrd.properties.length(), 2, msg="properties")
  assert_eq(jrd.links.length(), 2, msg="links")
  let author = jrd.links[1]
  assert_eq(author.rel, "author", msg="rel")
  assert_eq(author.titles.length(), 2, msg="titles")
  assert_eq(
    author.title("en-us"),
    Some("The Magical World of Steve"),
    msg="title en-us",
  )
  assert_eq(
    author.title("fr"),
    Some("Le Monde Magique de Steve"),
    msg="title fr",
  )
  match jrd.property("http://blgx.example.net/ns/ext") {
    Some(v) => assert_eq(v.is_null(), true, msg="null property")
    None => assert_true(false, msg="missing ext property")
  }
}

///|
test "rfc 7033 4.3 two-rel example parses" {
  let jrd = expect_parse(rfc_4_3_jrd())
  assert_eq(jrd.links.length(), 2, msg="links")
  assert_eq(
    jrd.links[0].rel,
    "http://webfinger.example/rel/profile-page",
    msg="first rel",
  )
  assert_eq(
    jrd.links[1].rel,
    "http://webfinger.example/rel/businesscard",
    msg="second rel",
  )
}

///|
test "rfc 7033 4.3 request target with two rels" {
  match
    build_request_target_with_rels("acct:bob@example.com", [
      "http://webfinger.example/rel/profile-page", "http://webfinger.example/rel/businesscard",
    ]) {
    Ok(target) =>
      inspect(
        target,
        content="/.well-known/webfinger?resource=acct%3Abob%40example.com&rel=http%3A%2F%2Fwebfinger.example%2Frel%2Fprofile-page&rel=http%3A%2F%2Fwebfinger.example%2Frel%2Fbusinesscard",
      )
    Err(e) => assert_true(false, msg="unexpected error: \{e.to_display()}")
  }
}

///|
test "rfc 7033 4.3 example validates clean" {
  let jrd = expect_parse(rfc_4_3_jrd())
  assert_eq(validate_jrd_all(jrd), true, msg="valid")
}
