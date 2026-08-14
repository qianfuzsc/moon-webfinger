// Command implementations for `webfinger-tool`. Every command returns a
// single-line deterministic JSON object on stdout:
//
//   {"ok":true,"command":<name>, ...result fields...}
//   {"ok":false,"command":<name>,"error":{"code":...,"message":...}}      (CLI usage)
//   {"ok":false,"command":<name>,"error":{"stage":...,"kind":..., ...}}  (library error)

///|
/// The tool usage text.
fn usage_text() -> String {
  "webfinger-tool — RFC 7033 WebFinger / JRD command-line toolkit (local tooling only; no network access).\n\n" +
  "usage:\n" +
  "  webfinger-tool request --resource <uri> [--rel <rel>]... [--origin <https-origin>]\n" +
  "  webfinger-tool parse (--input <json> | --input-file <path>)\n" +
  "  webfinger-tool validate (--input <json> | --input-file <path>)\n" +
  "  webfinger-tool query --rel <rel> [--type <media-type>] (--input <json> | --input-file <path>)\n" +
  "  webfinger-tool canonicalize (--input <json> | --input-file <path>)\n" +
  "  webfinger-tool audit (--input <json> | --input-file <path>)\n" +
  "  webfinger-tool stats (--input <json> | --input-file <path>)\n" +
  "  webfinger-tool version\n" +
  "  webfinger-tool help\n\n" +
  "options:\n" +
  "  --resource <uri>    the WebFinger query target (absolute URI)\n" +
  "  --rel <rel>         link relation filter (repeatable; URI or registered relation type)\n" +
  "  --origin <url>      HTTPS origin for full URL construction (e.g. https://example.com)\n" +
  "  --input <json>      inline JRD JSON\n" +
  "  --input-file <path> read the JRD JSON from a local file (native and js targets)\n" +
  "  --type <media-type> media type filter for the query command\n\n" +
  "all output is deterministic JSON; failed commands exit with status 1."
}

///|
/// Build the standard ok envelope.
fn ok_json(command : String, fields : Map[String, Json]) -> String {
  let members : Map[String, Json] = Map([])
  members.set("ok", Json::boolean(true))
  members.set("command", Json::string(command))
  for k, v in fields {
    members.set(k, v)
  }
  stringify_json(Json::object(members))
}

///|
/// Build a CLI-level error envelope.
fn cli_err_json(command : String, code : String, message : String) -> String {
  let members : Map[String, Json] = Map([])
  members.set("ok", Json::boolean(false))
  members.set("command", Json::string(command))
  let err : Map[String, Json] = Map([])
  err.set("code", Json::string(code))
  err.set("message", Json::string(message))
  members.set("error", Json::object(err))
  stringify_json(Json::object(members))
}

///|
/// Build a library-error envelope.
fn lib_err_json(command : String, e : WebFingerError) -> String {
  let members : Map[String, Json] = Map([])
  members.set("ok", Json::boolean(false))
  members.set("command", Json::string(command))
  let err : Map[String, Json] = Map([])
  err.set("stage", Json::string(e.stage_name()))
  err.set("kind", Json::string(e.kind_name()))
  match e.offset() {
    Some(n) => err.set("offset", Json::number(n.to_double()))
    None => err.set("offset", Json::null())
  }
  err.set("context", Json::string(e.context()))
  members.set("error", Json::object(err))
  stringify_json(Json::object(members))
}

///|
/// Int as JSON number.
fn int_json(n : Int) -> Json {
  Json::number(n.to_double())
}

///|
/// String array as JSON array.
fn strings_json(values : Array[String]) -> Json {
  let arr : Array[Json] = []
  for v in values {
    arr.push(Json::string(v))
  }
  Json::array(arr)
}

///|
/// Resolve the JRD input text from --input or --input-file.
fn input_text(opts : CliOptions) -> Result[String, String] {
  match (opts.input, opts.input_file) {
    (Some(_), Some(_)) => Err("use only one of --input or --input-file")
    (None, None) => Err("--input or --input-file is required")
    (Some(s), None) => Ok(s)
    (None, Some(path)) => {
      if !cli_file_input_supported() {
        return Err("--input-file is not supported on this target")
      }
      match cli_read_file(path) {
        Some(content) => Ok(content)
        None => Err("cannot read input file: \{path}")
      }
    }
  }
}

///|
/// Parse the JRD text; return the JRD or the error envelope.
fn parse_input(
  command : String,
  opts : CliOptions,
) -> Result[JsonResourceDescriptor, String] {
  match input_text(opts) {
    Err(msg) => Err(cli_err_json(command, "MissingInput", msg))
    Ok(text) =>
      match parse_jrd(text) {
        Ok(jrd) => Ok(jrd)
        Err(e) => Err(lib_err_json(command, e))
      }
  }
}

///|
/// `webfinger-tool version`
fn cmd_version() -> String {
  let fields : Map[String, Json] = Map([])
  fields.set("version", Json::string(library_version()))
  fields.set("module", Json::string("qianfuzsc/moon-webfinger"))
  ok_json("version", fields)
}

///|
/// `webfinger-tool help`
fn cmd_help() -> String {
  let fields : Map[String, Json] = Map([])
  fields.set("usage", Json::string(usage_text()))
  ok_json("help", fields)
}

///|
/// `webfinger-tool request`
fn cmd_request(opts : CliOptions) -> String {
  match opts.resource {
    None => cli_err_json("request", "MissingOption", "--resource is required")
    Some(resource) =>
      match build_request_target_with_rels(resource, opts.rels) {
        Err(e) => lib_err_json("request", e)
        Ok(target) => {
          let fields : Map[String, Json] = Map([])
          fields.set("resource", Json::string(resource))
          fields.set("rels", strings_json(opts.rels))
          fields.set("request_target", Json::string(target))
          match opts.origin {
            None => ()
            Some(origin) =>
              match build_webfinger_url(origin, resource, opts.rels) {
                Ok(url) => fields.set("url", Json::string(url))
                Err(e) => return lib_err_json("request", e)
              }
          }
          ok_json("request", fields)
        }
      }
  }
}

///|
/// `webfinger-tool parse`
fn cmd_parse(opts : CliOptions) -> String {
  match parse_input("parse", opts) {
    Err(out) => out
    Ok(jrd) => {
      let fields : Map[String, Json] = Map([])
      fields.set("jrd", jrd_to_json(jrd))
      fields.set("links", int_json(jrd.links.length()))
      fields.set("aliases", int_json(jrd.aliases.length()))
      ok_json("parse", fields)
    }
  }
}

///|
/// `webfinger-tool validate`
fn cmd_validate(opts : CliOptions) -> String {
  match parse_input("validate", opts) {
    Err(out) => out
    Ok(jrd) => {
      let issues = validate_jrd(jrd)
      let arr : Array[Json] = []
      let mut errors = 0
      let mut warnings = 0
      let mut infos = 0
      for issue in issues {
        match issue.severity_name() {
          "Error" => errors = errors + 1
          "Warning" => warnings = warnings + 1
          _ => infos = infos + 1
        }
        let entry : Map[String, Json] = Map([])
        entry.set("severity", Json::string(issue.severity_name()))
        entry.set("code", Json::string(issue.code))
        entry.set("message", Json::string(issue.message))
        arr.push(Json::object(entry))
      }
      let fields : Map[String, Json] = Map([])
      fields.set("valid", Json::boolean(errors == 0))
      fields.set("errors", int_json(errors))
      fields.set("warnings", int_json(warnings))
      fields.set("infos", int_json(infos))
      fields.set("issues", Json::array(arr))
      ok_json("validate", fields)
    }
  }
}

///|
/// `webfinger-tool query`
fn cmd_query(opts : CliOptions) -> String {
  match opts.media_type {
    None => query_impl(opts, None)
    Some(t) => query_impl(opts, Some(t))
  }
}

///|
/// Query implementation shared by both media-type modes.
fn query_impl(opts : CliOptions, media_type : String?) -> String {
  if opts.rels.length() == 0 {
    return cli_err_json("query", "MissingOption", "--rel is required")
  }
  let rel = opts.rels[0]
  match parse_input("query", opts) {
    Err(out) => out
    Ok(jrd) => {
      let matches = match media_type {
        None => find_links_by_rel(jrd, rel)
        Some(t) => find_links_by_rel_and_type(jrd, rel, t)
      }
      let hrefs : Array[String] = []
      let link_json : Array[Json] = []
      for link in matches {
        match link.href {
          Some(h) => hrefs.push(h)
          None => ()
        }
        link_json.push(link_model_to_json(link))
      }
      let fields : Map[String, Json] = Map([])
      fields.set("rel", Json::string(rel))
      match media_type {
        Some(t) => fields.set("type", Json::string(t))
        None => ()
      }
      fields.set("count", int_json(matches.length()))
      match first_href(jrd, rel) {
        Some(h) => fields.set("first_href", Json::string(h))
        None => fields.set("first_href", Json::null())
      }
      fields.set("hrefs", strings_json(hrefs))
      fields.set("links", Json::array(link_json))
      ok_json("query", fields)
    }
  }
}

///|
/// `webfinger-tool canonicalize`
fn cmd_canonicalize(opts : CliOptions) -> String {
  match input_text(opts) {
    Err(msg) => cli_err_json("canonicalize", "MissingInput", msg)
    Ok(text) =>
      match canonicalize_jrd_text(text) {
        Ok(output) => {
          let fields : Map[String, Json] = Map([])
          fields.set("output", Json::string(output))
          ok_json("canonicalize", fields)
        }
        Err(e) => lib_err_json("canonicalize", e)
      }
  }
}

///|
/// `webfinger-tool audit`
fn cmd_audit(opts : CliOptions) -> String {
  match parse_input("audit", opts) {
    Err(out) => out
    Ok(jrd) => {
      let findings = audit_jrd(jrd)
      let arr : Array[Json] = []
      let mut warnings = 0
      let mut infos = 0
      for finding in findings {
        match finding.severity_name() {
          "Warning" => warnings = warnings + 1
          _ => infos = infos + 1
        }
        let entry : Map[String, Json] = Map([])
        entry.set("severity", Json::string(finding.severity_name()))
        entry.set("code", Json::string(finding.code))
        entry.set("message", Json::string(finding.message))
        arr.push(Json::object(entry))
      }
      let fields : Map[String, Json] = Map([])
      fields.set("warnings", int_json(warnings))
      fields.set("infos", int_json(infos))
      fields.set("findings", Json::array(arr))
      ok_json("audit", fields)
    }
  }
}

///|
/// `webfinger-tool stats`
fn cmd_stats(opts : CliOptions) -> String {
  match input_text(opts) {
    Err(msg) => cli_err_json("stats", "MissingInput", msg)
    Ok(text) =>
      match parse_jrd(text) {
        Err(e) => lib_err_json("stats", e)
        Ok(jrd) => {
          let mut titles = 0
          let mut link_properties = 0
          for link in jrd.links {
            titles = titles + link.titles.length()
            link_properties = link_properties + link.properties.length()
          }
          let fields : Map[String, Json] = Map([])
          let has_subject = match jrd.subject {
            Some(_) => true
            None => false
          }
          fields.set("input_bytes", int_json(utf8_byte_length(text)))
          fields.set("has_subject", Json::boolean(has_subject))
          fields.set("aliases", int_json(jrd.aliases.length()))
          fields.set("properties", int_json(jrd.properties.length()))
          fields.set("links", int_json(jrd.links.length()))
          fields.set("titles", int_json(titles))
          fields.set("link_properties", int_json(link_properties))
          fields.set("extensions", int_json(jrd.extensions.length()))
          fields.set(
            "serialized_bytes",
            int_json(utf8_byte_length(serialize_jrd(jrd))),
          )
          ok_json("stats", fields)
        }
      }
  }
}
