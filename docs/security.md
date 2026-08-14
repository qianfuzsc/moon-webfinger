# Security

WebFinger is a resource-discovery mechanism. It is not authentication, authorization, identity proof, or a trust system. A syntactically valid JRD does not establish that its subject, aliases, properties, links, titles, or extension members are accurate or trustworthy.

`moon-webfinger` does not access the network, validate TLS or certificates, validate remote sites, follow redirects, dereference hrefs, or resolve aliases. URI values are inert data. Callers that add networking must independently enforce HTTPS, certificate validation, redirect policy, DNS and IP restrictions, response-size limits, timeouts, and application-specific trust rules.

Do not treat a caller-supplied or JRD-derived URL as safe merely because parsing succeeds. In particular, blindly fetching a subject, alias, or href can create SSRF exposure. Establish an allowlist or equivalent destination policy before any external component dereferences such data.

Parsing and building are bounded by `Limits` and return structured errors. Limits reduce resource-exhaustion risk but do not replace isolation, total request budgets, or caller-side input controls.
