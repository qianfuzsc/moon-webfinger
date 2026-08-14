///|
test "cli normalization covers native js and wasm argv layouts" {
  assert_eq(
    normalize_cli_args(["C:\\tool.exe", "version"]),
    ["version"],
    msg="native argv",
  )
  assert_eq(
    normalize_cli_args(["node", "D:/tool.js", "help"]),
    ["help"],
    msg="js argv",
  )
  assert_eq(
    normalize_cli_args(["D:/tool.wasm", "stats", "--input", "{}"]),
    ["stats", "--input", "{}"],
    msg="wasm argv",
  )
}

///|
test "cli outputs are exact deterministic json" {
  inspect(
    run_cli(["version"]),
    content="{\"ok\":true,\"module\":\"qianfuzsc/moon-webfinger\",\"command\":\"version\",\"version\":\"0.1.0-dev\"}",
  )
  inspect(
    run_cli(["request", "--resource", "acct:alice@example.com"]),
    content="{\"ok\":true,\"rels\":[],\"command\":\"request\",\"resource\":\"acct:alice@example.com\",\"request_target\":\"/.well-known/webfinger?resource=acct%3Aalice%40example.com\"}",
  )
  inspect(
    run_cli(["parse", "--input", "{\"subject\":\"acct:alice@example.com\"}"]),
    content="{\"ok\":true,\"jrd\":{\"subject\":\"acct:alice@example.com\"},\"links\":0,\"aliases\":0,\"command\":\"parse\"}",
  )
  inspect(
    run_cli(["no-cmd-here"]),
    content="{\"ok\":false,\"error\":{\"code\":\"UnknownCommand\",\"message\":\"unknown command 'no-cmd-here'; run 'webfinger-tool help'\"},\"command\":\"no-cmd-here\"}",
  )
}
