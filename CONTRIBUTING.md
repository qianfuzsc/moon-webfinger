# Contributing

This project is in local development and has no assigned repository or final maintainer namespace. Proposed changes should stay within the documented local RFC 7033/JRD scope and must not add implicit network access.

Format with `moon fmt`, add meaningful named tests, and run `scripts/verify_all.ps1`. Keep output deterministic, return structured errors for untrusted input, preserve unknown JRD members, and update the specification map when normative behavior changes.

Do not add personal identities, repository metadata, publication credentials, or generated claims about test counts and code size. Use `scripts/count_code.py` for measured values.
