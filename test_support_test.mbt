// Shared helpers for the moon-webfinger blackbox test suite.
//
// All `*_test.mbt` files compile into one shared blackbox test package,
// so helpers defined here are visible in every other test file.

///|
/// Deterministic Park–Miller PRNG (a=48271, m=2147483647, Schrage
/// method to avoid overflow). Fixed seed: identical sequences on every
/// machine and every target. No system randomness, no wall clock.
pub struct Prng {
  mut state : Int
}

///|
pub fn prng_new(seed : Int) -> Prng {
  { state: seed % 2147483647 + 1 }
}

///|
/// Next value in 1..2147483646.
pub fn prng_next(prng : Prng) -> Int {
  let hi = prng.state / 48271
  let lo = prng.state % 48271
  let mut next = 48271 * lo - 3399 * hi
  if next <= 0 {
    next = next + 2147483647
  }
  prng.state = next
  next
}

///|
/// Random Int in [lo, hi] inclusive.
pub fn prng_int(prng : Prng, lo : Int, hi : Int) -> Int {
  lo + prng_next(prng) % (hi - lo + 1)
}

///|
/// Random ASCII string from the given alphabet with length in
/// [min_len, max_len].
pub fn random_string_from(
  prng : Prng,
  alphabet : String,
  min_len : Int,
  max_len : Int,
) -> String {
  let len = prng_int(prng, min_len, max_len)
  let sb = StringBuilder::new(size_hint=len)
  let mut i = 0
  while i < len {
    let idx = prng_int(prng, 0, alphabet.length() - 1)
    sb.write_char(alphabet[idx].to_int().to_char().unwrap())
    i = i + 1
  }
  sb.to_string()
}

///|
pub fn random_alnum(prng : Prng, min_len : Int, max_len : Int) -> String {
  random_string_from(
    prng, "abcdefghijklmnopqrstuvwxyz0123456789", min_len, max_len,
  )
}

///|
/// Parse helper: abort with a readable message when parsing fails.
pub fn expect_parse(input : String) -> JsonResourceDescriptor {
  match parse_jrd(input) {
    Ok(jrd) => jrd
    Err(e) => abort("expect_parse failed: \{e.to_display()}")
  }
}

///|
/// Parse helper: abort when parsing unexpectedly succeeds.
pub fn expect_parse_error(input : String) -> WebFingerError {
  match parse_jrd(input) {
    Ok(_) => abort("expect_parse_error: input unexpectedly parsed")
    Err(e) => e
  }
}

///|
/// Whether a JSON string is valid JSON (any value) — used by the
/// truncation tests to double check core parser behavior.
pub fn is_valid_json(input : String) -> Bool {
  try {
    ignore(@json.parse(input))
    true
  } catch {
    _ => false
  }
}
