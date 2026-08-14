// audit_response — audit a parsed JRD plus a caller-observed response
// context, showing how transport facts feed the advisory audit without
// any network access.

///|
fn main {
  let jrd_text = "{\n" +
    "  \"subject\" : \"acct:alice@example.com\",\n" +
    "  \"links\" :\n" +
    "  [\n" +
    "    { \"rel\" : \"self\", \"href\" : \"http://example.com/alice\" },\n" +
    "    { \"rel\" : \"self\", \"href\" : \"https://example.com/alice\" }\n" +
    "  ]\n" +
    "}"
  match @wf.parse_jrd(jrd_text) {
    Ok(jrd) => {
      println("JRD audit findings:")
      for finding in @wf.audit_jrd(jrd) {
        println(
          "  [\{finding.severity_name()}] \{finding.code}: \{finding.message}",
        )
      }
      let ctx = @wf.WebFingerResponseContext::new(
        Some(
          "https://example.com/.well-known/webfinger?resource=acct%3Aalice%40example.com",
        ),
        "https://webfinger.example.net/redirect?resource=acct%3Aalice%40example.com",
        200,
        Some("application/jrd+json"),
        Some(1024),
      )
      println("response context validation:")
      match @wf.validate_response_context(ctx) {
        Ok(_) => println("  context: ok")
        Err(e) => println("  context error: \{e.to_display()}")
      }
      println("response audit findings:")
      for finding in @wf.audit_response(ctx) {
        println(
          "  [\{finding.severity_name()}] \{finding.code}: \{finding.message}",
        )
      }
    }
    Err(e) => println("parse failed: \{e.to_display()}")
  }
}
