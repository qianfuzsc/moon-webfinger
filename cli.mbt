// Pure CLI core: argument normalization, option parsing and the
// `run_cli` dispatcher. Everything here is deterministic and testable
// without spawning a process.

///|
/// The parsed command-line options shared by all commands.
pub struct CliOptions {
  mut resource : String?
  rels : Array[String]
  mut origin : String?
  mut input : String?
  mut input_file : String?
  mut media_type : String?
}

///|
/// Drop leading program/runtime paths from the argument list. The argv
/// shape differs per backend:
///
///   native / wasm-gc: [program, args...]
///   js:               [node, program.js, args...]
///
/// Program paths are recognised by shape (a path ending in a program
/// extension, or a known runtime binary name) and dropped until the
/// first known command or the user's first argument is reached, so the
/// backend never leaks into `run_cli`.
pub fn normalize_cli_args(args : Array[String]) -> Array[String] {
  let known = [
    "request", "parse", "validate", "query", "canonicalize", "audit", "stats", "version",
    "help",
  ]
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    let mut is_command = false
    for k in known {
      if a == k || a == k.to_upper() {
        is_command = true
      }
    }
    if is_command {
      break
    }
    if !is_program_path(a) {
      break
    }
    i = i + 1
  }
  args[i:].to_owned()
}

///|
/// Whether a leading argument is the running program (or its runtime
/// binary) rather than a user-supplied command. Program paths carry a
/// directory separator and a known program extension; runtime binaries
/// are recognised by their bare names.
fn is_program_path(arg : String) -> Bool {
  let lower = arg.to_lower()
  if lower == "node" ||
    lower == "deno" ||
    lower == "bun" ||
    lower.has_suffix("/node") ||
    lower.has_suffix("/deno") ||
    lower.has_suffix("/bun") {
    return true
  }
  if !(arg.contains("/") || arg.contains("\\")) {
    return false
  }
  lower.has_suffix(".exe") ||
  lower.has_suffix(".js") ||
  lower.has_suffix(".cjs") ||
  lower.has_suffix(".mjs") ||
  lower.has_suffix(".wasm")
}

///|
/// Parse options after the command word. Fails with a message on unknown
/// options or missing values.
fn parse_options(args : Array[String]) -> Result[CliOptions, String] {
  let opts : CliOptions = {
    resource: None,
    rels: [],
    origin: None,
    input: None,
    input_file: None,
    media_type: None,
  }
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if i + 1 >= args.length() {
      return Err("option \{a} requires a value")
    }
    let value = args[i + 1]
    if a == "--resource" {
      opts.resource = Some(value)
    } else if a == "--rel" {
      opts.rels.push(value)
    } else if a == "--origin" {
      opts.origin = Some(value)
    } else if a == "--input" {
      opts.input = Some(value)
    } else if a == "--input-file" {
      opts.input_file = Some(value)
    } else if a == "--type" {
      opts.media_type = Some(value)
    } else {
      return Err("unknown option: \{a}")
    }
    i = i + 2
  }
  Ok(opts)
}

///|
/// Run the CLI on already-normalized arguments and return the complete
/// JSON output line. Pure: never exits, never panics.
pub fn run_cli(args : Array[String]) -> String {
  let args = normalize_cli_args(args)
  if args.length() == 0 {
    return cli_err_json(
      "", "MissingCommand", "no command given; run 'webfinger-tool help'",
    )
  }
  let command = args[0].to_lower()
  let rest : Array[String] = args[1:].to_owned()
  match parse_options(rest) {
    Err(msg) => cli_err_json(command, "BadOption", msg)
    Ok(opts) => dispatch(command, opts)
  }
}

///|
/// Dispatch to a command implementation.
fn dispatch(command : String, opts : CliOptions) -> String {
  match command {
    "request" => cmd_request(opts)
    "parse" => cmd_parse(opts)
    "validate" => cmd_validate(opts)
    "query" => cmd_query(opts)
    "canonicalize" => cmd_canonicalize(opts)
    "audit" => cmd_audit(opts)
    "stats" => cmd_stats(opts)
    "version" => cmd_version()
    "help" => cmd_help()
    _ =>
      cli_err_json(
        command,
        "UnknownCommand",
        "unknown command '\{command}'; run 'webfinger-tool help'",
      )
  }
}
