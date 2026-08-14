# Limitations

This MVP intentionally provides no HTTP client, HTTP server, sockets, DNS, TLS, certificate validation, redirect handling, ActivityPub implementation, OAuth, OpenID Connect implementation, WebAuthn, complete URI resolver, complete IDNA implementation, remote link dereferencing, account database, or caching.

URI checks are lightweight checks needed for the documented WebFinger scope, not a full RFC 3986 parser or normalizer. Language tags receive a basic syntax check and simple exact case-insensitive lookup, not full RFC 4647 negotiation or registry validation. `acct:` helpers cover the project's common local use cases, not email-address semantics or SMTP validation.

The MoonBit core JSON parser applies its own nesting guard before the library's bounded traversal. MoonBit `String` values are valid Unicode strings, so the public string parser cannot be fed an ill-formed UTF-8 byte buffer directly. Callers decoding bytes must handle decoder errors before `parse_jrd`.
