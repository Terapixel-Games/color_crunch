param(
	[string]$GodotBin = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Runner = Join-Path $ProjectRoot "addons\gdUnit4\runtest.cmd"

function Normalize-GodotBinary([string]$Path) {
	$resolved = (Resolve-Path $Path).Path
	$folder = Split-Path -Path $resolved -Parent
	$name = [System.IO.Path]::GetFileName($resolved).ToLowerInvariant()
	if ($name -eq "godot.exe") {
		$consolePath = Join-Path $folder "godot_console.exe"
		if (Test-Path $consolePath) {
			return (Resolve-Path $consolePath).Path
		}
	}
	return $resolved
}

function Resolve-GodotBinary([string]$Requested) {
	if (-not [string]::IsNullOrWhiteSpace($Requested)) {
		if (-not (Test-Path $Requested)) {
			throw "Godot binary not found: $Requested"
		}
		return Normalize-GodotBinary $Requested
	}

	if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
		if (-not (Test-Path $env:GODOT_BIN)) {
			throw "GODOT_BIN is set but does not exist: $env:GODOT_BIN"
		}
		return Normalize-GodotBinary $env:GODOT_BIN
	}

	foreach ($candidate in @("godot_console", "godot", "godot4")) {
		$cmd = Get-Command $candidate -ErrorAction SilentlyContinue
		if ($null -ne $cmd) {
			return Normalize-GodotBinary $cmd.Source
		}
	}

	throw "Godot binary was not found. Set GODOT_BIN or pass -GodotBin <path>."
}

if (-not (Test-Path $Runner)) {
	throw "gdUnit test runner not found: $Runner"
}

$ResolvedGodot = Resolve-GodotBinary $GodotBin
Write-Host "Running pre-push tests for color_crunch..."
Write-Host "Using Godot binary: $ResolvedGodot"

Push-Location $ProjectRoot
try {
	& $Runner --godot_binary $ResolvedGodot -a tests --ignoreHeadlessMode
	$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
	if ($exitCode -ne 0) {
		throw "Pre-push tests failed with exit code $exitCode."
	}
}
finally {
	Pop-Location
}

Write-Host "Pre-push tests passed."
