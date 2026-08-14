# Reproduction

Requirements are a current MoonBit toolchain compatible with the module and Python 3 for metrics. Native verification additionally requires the compiler/linker configured by MoonBit.

From the project root, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/verify_all.ps1
```

An explicit Moon executable may be passed as `-MoonBin`. Resolution order is the parameter, `MOON_BIN`, `moon` on `PATH`, then `D:\Moonbit\bin\moon.exe`. The script cleans generated artifacts, checks formatting, checks and tests `wasm-gc`, `js`, and `native`, runs CLI smoke commands and all examples, measures code, and lists the package. Any failed command terminates the run with exit code 1.
