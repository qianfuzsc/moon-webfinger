// Local file reading for `webfinger-tool --input-file`.
//
// The library performs no network access, and the CLI likewise reads
// only local files. Target support:
//
//   native (Windows) - `_wfopen`/`fgetc`/`fclose` from the C runtime.
//       MoonBit strings are UTF-16 in memory, which is exactly
//       `wchar_t*` on Windows, so the path is passed straight through.
//       FILE* values travel as Int64 (pointer-sized integer), matching
//       the 64-bit Windows calling convention; bytes are read one at a
//       time and re-decoded as UTF-8.
//   native (other)   - not implemented; reported as unavailable.
//   js               - Node `fs.readFileSync` (utf-8).
//   wasm-gc          - not supported; callers receive a clear error.

///|
/// Read a local file as UTF-8 text, or `None` when the file cannot be
/// read or is not valid UTF-8. The caller enforces the size limit.
#cfg(all(target="native", platform="windows"))
fn cli_read_file(path : String) -> String? {
  let file = c_wfopen(path, "rb")
  if file == 0 {
    return None
  }
  let bytes : Array[Byte] = []
  let mut ok = true
  while true {
    let b = c_fgetc(file)
    if b == -1 {
      break
    }
    if b < 0 || b > 255 {
      ok = false
      break
    }
    bytes.push(b.to_byte())
  }
  ignore(c_fclose(file))
  if !ok {
    return None
  }
  Some(decode_utf8_strict(strip_utf8_bom(bytes))) catch {
    _ => None
  }
}

///|
/// Internal: drop a leading UTF-8 byte-order mark (EF BB BF), if present,
/// before strict decoding. Only the native Windows reader needs it.
#cfg(all(target="native", platform="windows"))
fn strip_utf8_bom(bytes : Array[Byte]) -> Array[Byte] {
  if bytes.length() >= 3 &&
    bytes[0].to_int() == 0xEF &&
    bytes[1].to_int() == 0xBB &&
    bytes[2].to_int() == 0xBF {
    bytes[3:].to_owned()
  } else {
    bytes
  }
}

///|
#cfg(all(target="native", platform="windows"))
#borrow(path, mode)
extern "c" fn c_wfopen(path : String, mode : String) -> Int64 = "_wfopen"

///|
#cfg(all(target="native", platform="windows"))
extern "c" fn c_fgetc(file : Int64) -> Int = "fgetc"

///|
#cfg(all(target="native", platform="windows"))
extern "c" fn c_fclose(file : Int64) -> Int = "fclose"

///|
/// Non-Windows native has no file input in this MVP.
#cfg(all(target="native", not(platform="windows")))
fn cli_read_file(_path : String) -> String? {
  None
}

///|
/// Read a local file as UTF-8 text, or `None` when the file cannot be
/// read.
#cfg(target="js")
extern "js" fn cli_read_file(path : String) -> String? =
  #| function(path) {
  #|   try {
  #|     if (typeof require !== "function") {
  #|       return null;
  #|     }
  #|     const fs = require("fs");
  #|     return fs.readFileSync(path, "utf8");
  #|   } catch (e) {
  #|     return null;
  #|   }
  #| }

///|
/// The wasm-gc target has no local file access; report unavailability.
#cfg(target="wasm-gc")
fn cli_read_file(_path : String) -> String? {
  None
}

///|
/// Whether `--input-file` is available on this target.
#cfg(all(target="native", platform="windows"))
pub fn cli_file_input_supported() -> Bool {
  true
}

///|
#cfg(all(target="native", not(platform="windows")))
pub fn cli_file_input_supported() -> Bool {
  false
}

///|
#cfg(target="js")
pub fn cli_file_input_supported() -> Bool {
  true
}

///|
#cfg(target="wasm-gc")
pub fn cli_file_input_supported() -> Bool {
  false
}
