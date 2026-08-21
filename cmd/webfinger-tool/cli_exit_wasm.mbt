// wasm-gc exit-code support for `webfinger-tool`.

///|
/// Terminates the process with the given exit code.
#cfg(any(target="wasm", target="wasm-gc"))
fn cli_process_exit(code : Int) -> Unit = "__moonbit_sys_unstable" "exit"

///|
#cfg(any(target="wasm", target="wasm-gc"))
fn cli_exit(code : Int) -> Unit {
  cli_process_exit(code)
}
