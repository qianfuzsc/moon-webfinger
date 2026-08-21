param(
    [string]$MoonBin
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $ProjectRoot

function Resolve-MoonExecutable {
    if ($MoonBin) {
        if (-not (Test-Path -LiteralPath $MoonBin -PathType Leaf)) {
            throw "Moon executable not found: $MoonBin"
        }
        return (Resolve-Path -LiteralPath $MoonBin).Path
    }
    if ($env:MOON_BIN) {
        if (-not (Test-Path -LiteralPath $env:MOON_BIN -PathType Leaf)) {
            throw "MOON_BIN does not name a file: $env:MOON_BIN"
        }
        return (Resolve-Path -LiteralPath $env:MOON_BIN).Path
    }
    $OnPath = Get-Command moon -ErrorAction SilentlyContinue
    if ($OnPath) {
        return $OnPath.Source
    }
    $Fallback = 'D:\Moonbit\bin\moon.exe'
    if (Test-Path -LiteralPath $Fallback -PathType Leaf) {
        return $Fallback
    }
    throw "Moon executable not found via -MoonBin, MOON_BIN, PATH, or fallback"
}

function Invoke-Checked {
    param(
        [string]$Label,
        [string]$Executable,
        [string[]]$Arguments
    )
    Write-Host "==> $Label"
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Error "$Label failed with exit code $LASTEXITCODE"
        exit 1
    }
}

function Invoke-Smoke {
    param(
        [string]$Label,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$Expected
    )
    Write-Host "==> $Label"
    $Output = & $Executable @Arguments
    $ExitCode = $LASTEXITCODE
    $Output | Write-Host
    if ($ExitCode -ne 0 -or (($Output -join "`n") -notlike "*$Expected*")) {
        Write-Error "$Label failed: exit=$ExitCode, missing expected text '$Expected'"
        exit 1
    }
}

$Moon = Resolve-MoonExecutable
Write-Host "Moon: $Moon"

Invoke-Checked "clean" $Moon @("clean")
Invoke-Checked "format check" $Moon @("fmt", "--check")

foreach ($Target in @("wasm-gc", "js", "native")) {
    Invoke-Checked "$Target check" $Moon @("check", "--target", $Target, "--deny-warn")
    Invoke-Checked "$Target test" $Moon @("test", "--target", $Target, "--deny-warn")
}

foreach ($Target in @("wasm-gc", "js")) {
    Invoke-Smoke "$Target CLI version" $Moon @("run", "--target", $Target, "cmd/webfinger-tool", "version") '"version":"0.1.0"'
}

Invoke-Checked "native release build" $Moon @("build", "--target", "native", "--release", "--deny-warn")
$NativeCli = Join-Path $ProjectRoot '_build\native\release\build\cmd\webfinger-tool\webfinger-tool.exe'
if (-not (Test-Path -LiteralPath $NativeCli -PathType Leaf)) {
    Write-Error "Native CLI was not generated at $NativeCli"
    exit 1
}
$Fixture = Join-Path $ProjectRoot 'smoke_jrd.json'
Invoke-Smoke "native CLI version" $NativeCli @("version") '"version":"0.1.0"'
Invoke-Smoke "native CLI request" $NativeCli @("request", "--resource", "acct:alice@example.com") 'acct%3Aalice%40example.com'
Invoke-Smoke "native CLI parse" $NativeCli @("parse", "--input-file", $Fixture) '"command":"parse"'
Invoke-Smoke "native CLI validate" $NativeCli @("validate", "--input-file", $Fixture) '"valid":true'
Invoke-Smoke "native CLI query" $NativeCli @("query", "--rel", "http://openid.net/specs/connect/1.0/issuer", "--input-file", $Fixture) '"count":1'
Invoke-Smoke "native CLI audit" $NativeCli @("audit", "--input-file", $Fixture) '"command":"audit"'

& $NativeCli "no-such-command" | Write-Host
if ($LASTEXITCODE -ne 1) {
    Write-Error "Native CLI error command must exit 1; got $LASTEXITCODE"
    exit 1
}

foreach ($Example in @("build_request", "parse_jrd", "query_links", "audit_response", "build_jrd")) {
    Invoke-Checked "example $Example" $Moon @("run", "--target", "wasm-gc", "examples/$Example")
}

$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) {
    Write-Error "Python 3 is required for scripts/count_code.py"
    exit 1
}
Invoke-Checked "code metrics" $Python.Source @("scripts/count_code.py")
Invoke-Checked "package list" $Moon @("package", "--list")

Write-Host "ALL CHECKS PASSED"
exit 0
