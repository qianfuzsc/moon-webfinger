# Third-Party Notices

The MoonBit implementation in this project is original and does not copy source code from a third-party WebFinger library.

The project implements and documents concepts from these Internet standards:

- RFC 7033, “WebFinger,” by P. Jones, G. Salgueiro, M. Jones, and J. Smarr. The small fixtures in `rfc_examples_test.mbt` are reconstructed for interoperability tests from examples in Sections 3.1, 3.2, and 4.3.
- RFC 3986, “Uniform Resource Identifier (URI): Generic Syntax,” for the lightweight URI checks and percent-encoding boundary.
- RFC 3987, “Internationalized Resource Identifiers (IRIs),” consulted only to document the MVP's non-ASCII boundary.
- RFC 7565, “The 'acct' URI Scheme,” for `acct:` convenience helpers.
- RFC 8259, “The JavaScript Object Notation (JSON) Data Interchange Format,” via MoonBit core JSON parsing.
- RFC 9110, “HTTP Semantics,” for status and media-type context terminology.

RFC documents are published by the IETF and are subject to the IETF Trust Legal Provisions. The fixtures are used only for standards-conformance testing and source sections are identified above.
