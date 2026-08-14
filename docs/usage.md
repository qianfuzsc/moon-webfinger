# Usage

Parse JRD text with `parse_jrd`; use `parse_jrd_with_limits` for caller-selected limits. Serialize with `serialize_jrd`, or normalize accepted text with `canonicalize_jrd_text`.

Construct request targets with `build_request_target` or `build_request_target_with_rels`. Use `build_webfinger_url` only when the caller already knows the HTTPS origin. It joins strings after validation and does not connect to the origin.

Use `JrdBuilder` and `JrdLinkBuilder` when constructing models. Both return `Result` from `build`. Query with `find_links_by_rel`, `find_links_by_rel_and_type`, `first_href`, `relation_summary`, and property helpers.

For a response already obtained by the caller, populate `WebFingerResponseContext` and call `validate_response_context` or `audit_response`. Validation enforces checkable protocol invariants; audit returns deterministic advisory findings.
