# moon-webfinger

- Module: `qianfuzsc/moon-webfinger`
- Version: `0.1.0`
- Status: final-review release candidate
- Mooncakes: release target `qianfuzsc/moon-webfinger@0.1.0`
- Repository: <https://github.com/qianfuzsc/moon-webfinger>
- Applicant and maintainer: 赵士超
- GitHub: `qianfuzsc`

## Overview

`moon-webfinger` is a deterministic RFC 7033 WebFinger and JSON Resource Descriptor (JRD) parser, serializer, request builder, query, validation, and audit toolkit for MoonBit. It performs local data processing only and never makes network requests.

## Why WebFinger

WebFinger discovers information about a resource identified by a URI. A caller sends a `resource` value, optionally filters by one or more `rel` values, and receives an `application/jrd+json` descriptor. This library supplies the protocol data layer while leaving HTTP, TLS, redirects, and trust policy to the caller.

## RFC 7033 Scope

Implemented scope includes request-target construction, JRD parsing and deterministic serialization, extension-member preservation, semantic validation, response-context checks, relation queries, advisory auditing, configurable limits, structured errors, and common `acct:` helpers. See [docs/specification-map.md](docs/specification-map.md) for the normative mapping.

## WebFinger Request

```moonbit
let target = @wf.build_request_target_with_rels(
  "acct:alice@example.com",
  ["http://webfinger.net/rel/profile-page"],
)
```

Resources and relation filters are percent-encoded as query components. Rel order and duplicates are preserved unless `canonicalize_request` is explicitly used. `build_webfinger_url` accepts a caller-supplied HTTPS origin but performs no request.

## JSON Resource Descriptor

`JsonResourceDescriptor` represents `subject`, `aliases`, `properties`, `links`, and preserved unknown top-level members. `JrdLink` represents the required `rel` plus optional `type`, `href`, `titles`, `properties`, and preserved unknown members.

## Subject and Aliases

Subject and alias values are treated as absolute URI strings. The parser preserves their order; the validator reports semantic issues without rewriting them.

## Properties

JRD properties support both string and explicit null values through `PropertyValue`. Null and absence remain distinct.

## Links

Link array order is preserved because it may express preference. Hrefs are returned as inert data and are never followed.

## Localized Titles

`title`, `preferred_title`, and `fallback_title` support exact ASCII case-insensitive language-tag lookup and deterministic fallback. Full RFC 4647 negotiation and registry validation are outside this MVP.

## Query Helpers

Helpers find links by relation and media type, return hrefs, count relations, copy aliases, and inspect properties. Every query is local and deterministic.

## Response Validation

`validate_response_context` checks caller-observed HTTPS URLs, 2xx status, and the JRD media type. It does not validate certificates or remote identity.

## Serialization

Serialization is compact and deterministic. Standard and extension object members are emitted in stable order; arrays retain model order. This ordering is for reproducibility, not an RFC-mandated JSON member order.

## CLI

```text
webfinger-tool request --resource acct:alice@example.com
webfinger-tool parse --input-file smoke_jrd.json
webfinger-tool query --rel http://openid.net/specs/connect/1.0/issuer --input-file smoke_jrd.json
webfinger-tool audit --input-file smoke_jrd.json
```

Commands are `request`, `parse`, `validate`, `query`, `canonicalize`, `audit`, `stats`, `version`, and `help`. Output is deterministic JSON. The CLI does not accept URLs to fetch.

## Examples

The five local examples cover request construction, JRD parsing, JRD building, relation queries, and response auditing. Run them with `moon run examples/build_request` and the corresponding package paths.

## Testing

Run `moon test` for the current target or `powershell -File scripts/verify_all.ps1` for formatting, all three targets, CLI smoke tests, examples, metrics, and package listing. Details are in [docs/testing.md](docs/testing.md).

## Security

WebFinger is discovery, not authentication, authorization, identity proof, or a trust system. Treat every JRD value as untrusted. See [docs/security.md](docs/security.md).

## Limitations

There is no HTTP client or server, DNS, TLS, certificate validation, redirect engine, complete URI/IDNA stack, link dereferencing, account database, or cache. See [docs/limitations.md](docs/limitations.md).

## License

Apache License 2.0. See [LICENSE](LICENSE). Reconstructed RFC fixtures are attributed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Project Status

This is a mature MVP maintained by 赵士超 (`qianfuzsc`). Version `0.1.0` is the final-review release target for Mooncakes.
