# Contributing

This project is maintained by 赵士超 (`qianfuzsc`) at <https://github.com/qianfuzsc/moon-webfinger>. Proposed changes should stay within the documented RFC 7033/JRD scope and must not add implicit network access.

Format with `moon fmt`, add meaningful named tests, and run `scripts/verify_all.ps1`. Keep output deterministic, return structured errors for untrusted input, preserve unknown JRD members, and update the specification map when normative behavior changes.

Do not commit credentials, access tokens, or generated claims about test counts and code size. Use `scripts/count_code.py` for measured values.
