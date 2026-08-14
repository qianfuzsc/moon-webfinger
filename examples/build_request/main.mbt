// build_request — build WebFinger request targets (and a full URL) for an
// acct resource with rel filters. No network access happens.

///|
fn main {
  let resource = "acct:alice@example.com"
  let rels = [
    "http://webfinger.net/rel/profile-page", "http://webfinger.net/rel/businesscard",
  ]
  match @wf.build_request_target(resource) {
    Ok(target) => {
      println("resource:          \{resource}")
      println("request target:    \{target}")
    }
    Err(e) => {
      println("error: \{e.to_display()}")
      return
    }
  }
  match @wf.build_request_target_with_rels(resource, rels) {
    Ok(target) => println("with rel filters:  \{target}")
    Err(e) => println("error: \{e.to_display()}")
  }
  match @wf.build_webfinger_url("https://example.com", resource, rels) {
    Ok(url) => println("full URL:          \{url}")
    Err(e) => println("error: \{e.to_display()}")
  }
  match @wf.canonicalize_request(resource, rels) {
    Ok(target) => println("canonical request: \{target}")
    Err(e) => println("error: \{e.to_display()}")
  }
}
