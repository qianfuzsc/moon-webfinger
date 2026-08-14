# Architecture

The root package contains the reusable library. `model.mbt` defines JRD data, `parser.mbt` and `json_adapter.mbt` convert core JSON into bounded models, and `serializer.mbt` produces deterministic JSON. Request, validation, context, query, audit, builder, URI, percent-codec, account, error, and limit concerns remain separate modules.

The CLI core also lives in the root library so `normalize_cli_args` and `run_cli` can be black-box tested on every target. `cmd/webfinger-tool` only connects environment arguments, stdout, and target-specific process exit. Examples are separate executable packages consuming the public API.

No layer performs network access. Data flows from caller-owned strings or local CLI files into parsing, validation, querying, serialization, or audit results.
