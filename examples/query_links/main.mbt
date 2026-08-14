// query_links — query a local JRD for links by rel and by rel+type, and
// show relation counts. Hrefs are printed as data only; nothing is
// fetched.

///|
fn main {
  let input = "{\n" +
    "  \"subject\" : \"acct:bob@example.com\",\n" +
    "  \"aliases\" : [ \"https://www.example.com/~bob/\" ],\n" +
    "  \"properties\" : { \"http://example.com/ns/role\" : \"employee\" },\n" +
    "  \"links\" :\n" +
    "  [\n" +
    "    { \"rel\" : \"http://webfinger.example/rel/profile-page\",\n" +
    "      \"href\" : \"https://www.example.com/~bob/\" },\n" +
    "    { \"rel\" : \"http://webfinger.example/rel/businesscard\",\n" +
    "      \"href\" : \"https://www.example.com/~bob/bob.vcf\",\n" +
    "      \"type\" : \"text/vcard\" },\n" +
    "    { \"rel\" : \"self\", \"href\" : \"https://www.example.com/~bob/\" }\n" +
    "  ]\n" +
    "}"
  match @wf.parse_jrd(input) {
    Ok(jrd) => {
      let rel = "http://webfinger.example/rel/profile-page"
      println("links with rel 'profile-page':")
      for link in @wf.find_links_by_rel(jrd, rel) {
        let href_text = match link.href {
          Some(h) => h
          None => "(no href)"
        }
        println("  \{href_text}")
      }
      let first = match @wf.first_href(jrd, rel) {
        Some(h) => h
        None => "(none)"
      }
      println("first href for 'profile-page': \{first}")
      let matches = @wf.find_links_by_rel_and_type(
        jrd, "http://webfinger.example/rel/businesscard", "text/vcard",
      )
      println("rel+type matches: \{matches.length()}")
      println("relation summary:")
      for entry in @wf.relation_summary(jrd) {
        println("  \{entry.rel}: \{entry.count}")
      }
    }
    Err(e) => println("parse failed: \{e.to_display()}")
  }
}
