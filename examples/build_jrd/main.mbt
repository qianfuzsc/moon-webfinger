// build_jrd — build a JRD fluently, serialize it deterministically, and
// parse it back to prove the round trip.

///|
fn main {
  let link_result = @wf.JrdLinkBuilder::new(
      "http://webfinger.example/rel/profile-page",
    )
    .href("https://www.example.com/~bob/")
    .media_type("text/html")
    .title("en-us", "Bob's profile page")
    .title("fr", "Page de profil de Bob")
    .property_string("http://example.com/ns/role", "employee")
    .build()
  let link = match link_result {
    Ok(l) => l
    Err(e) => {
      println("link build failed: \{e.to_display()}")
      return
    }
  }
  let jrd = @wf.JrdBuilder::new()
    .subject("acct:bob@example.com")
    .alias("https://www.example.com/~bob/")
    .property_string("http://example.com/ns/role", "employee")
    .link(link)
    .build()
  match jrd {
    Ok(model) => {
      println("built and serialized:")
      println(@wf.serialize_jrd(model))
      match @wf.parse_jrd(@wf.serialize_jrd(model)) {
        Ok(round) =>
          println(
            "round trip semantic equality: \{@wf.jrd_semantic_equal(model, round)}",
          )
        Err(e) => println("round trip failed: \{e.to_display()}")
      }
    }
    Err(e) => println("jrd build failed: \{e.to_display()}")
  }
}
