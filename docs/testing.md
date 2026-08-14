# Testing

The named black-box suite covers models, URI and percent encoding, requests, parser and serializer behavior, builders, queries, validation, contexts, auditing, limits, malformed and truncated inputs, RFC-derived fixtures, deterministic properties, and the pure CLI core.

`property_test.mbt` uses a fixed PRNG seed for 800 model round-trip/canonicalization cases and 200 request-determinism cases. It does not use the clock, system randomness, or network access. `truncation_test.mbt` parses every character-boundary prefix of five multilingual complex fixtures; MoonBit strings cannot represent ill-formed UTF-8 byte sequences, so raw mid-code-unit construction is outside the string API.

Run one target with `moon test --target wasm-gc`, `moon test --target js`, or `moon test --target native`. Run the complete reproducible matrix with `scripts/verify_all.ps1`.
