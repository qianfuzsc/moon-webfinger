# RFC 7033 Specification Map

| RFC section | Normative requirement | Implementation | Tests |
|---|---|---|---|
| 4, 4.1 | WebFinger queries use `/.well-known/webfinger` with one `resource` parameter and optional repeated `rel` parameters. | `request.mbt`, `percent_codec.mbt` | `request_test.mbt`, `property_test.mbt`, `rfc_examples_test.mbt` |
| 4.2, 9.1 | WebFinger uses HTTPS; clients do not fall back to HTTP and must apply TLS validation when networking. | `context.mbt` validates caller-observed URLs; networking and TLS are deliberately absent. | `context_test.mbt`, `audit_test.mbt` |
| 4.3 | Multiple `rel` values are represented by repeated query parameters; response links are filtered by relation type. | `request.mbt`, `query.mbt` | `request_test.mbt`, `query_test.mbt`, `rfc_examples_test.mbt` |
| 4.4 | JRD is a JSON object; unknown members must be ignored by consumers. | `parser.mbt`, `json_adapter.mbt` preserve unknown members for forward-compatible round trips. | `parser_test.mbt`, `invalid_test.mbt` |
| 4.4.1 | `subject` is a URI and should be present; it may differ from the queried resource. | `validator.mbt`, `uri.mbt` | `validator_test.mbt`, `uri_test.mbt` |
| 4.4.2 | `aliases` is an array of URI strings. | `json_adapter.mbt`, `validator.mbt` | `parser_test.mbt`, `invalid_test.mbt` |
| 4.4.3 | `properties` maps URI names to string or null values. | `model.mbt`, `json_adapter.mbt` | `model_test.mbt`, `parser_test.mbt` |
| 4.4.4 | `links` is an ordered array; each link requires `rel` and may contain `type`, `href`, `titles`, and `properties`. | `model.mbt`, `json_adapter.mbt`, `builder.mbt` | `builder_test.mbt`, `query_test.mbt`, `rfc_examples_test.mbt` |
| 4.4.4.4 | `titles` maps language tags to strings; consumers may select a preferred title. | `model.mbt`, `validator.mbt` | `model_test.mbt`, `validator_test.mbt` |
| 8.2 | JRD responses use `application/jrd+json`. | `context.mbt` | `context_test.mbt` |
| 9 | Retrieved information is not inherently trusted and implementations must account for security risks. | Local-only design, limits, structured errors, `docs/security.md` | `limits_test.mbt`, `invalid_test.mbt`, `truncation_test.mbt` |

Object member sorting in `serializer.mbt` is a reproducibility choice, not a requirement imposed by RFC 7033.
