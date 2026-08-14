// `webfinger-tool` entry point. The command surface lives in the library
// (cli.mbt / cli_commands.mbt) so it is testable as a blackbox consumer;
// this main package only wires argv, stdout and the exit code.

///|
fn main {
  let args = @env.args()
  let out = @wf.run_cli(args)
  println(out)
  if out.has_prefix("{\"ok\":false") {
    cli_exit(1)
  }
}
