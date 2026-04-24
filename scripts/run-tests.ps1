param(
	[ValidateSet("all", "unit", "uat")]
	[string]$Suite = "all",
	[string]$GodotBin = "godot"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Resolve-GodotCommand([string]$RequestedBin) {
	$command = Get-Command $RequestedBin -ErrorAction Stop
	$resolved = $command.Source
	if ([System.IO.Path]::GetFileName($resolved).ToLowerInvariant() -eq "godot.exe") {
		$consoleBin = Join-Path (Split-Path $resolved -Parent) "godot_console.exe"
		if (Test-Path $consoleBin) {
			return $consoleBin
		}
	}
	return $resolved
}

$ResolvedGodotBin = Resolve-GodotCommand $GodotBin

function Run-Suite([string]$TargetSuite) {
	Write-Host "Running $TargetSuite tests..."
	$previousErrorActionPreference = $ErrorActionPreference
	$nativePreferenceWasPresent = $null -ne (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue)
	$previousNativePreference = $false
	if ($nativePreferenceWasPresent) {
		$previousNativePreference = $PSNativeCommandUseErrorActionPreference
	}
	try {
		$ErrorActionPreference = "Continue"
		if ($nativePreferenceWasPresent) {
			$PSNativeCommandUseErrorActionPreference = $false
		}
		$output = & $ResolvedGodotBin --headless --path $ProjectRoot --script res://tests/framework/TestRunner.gd -- --suite=$TargetSuite 2>&1
		$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
	}
	finally {
		$ErrorActionPreference = $previousErrorActionPreference
		if ($nativePreferenceWasPresent) {
			$PSNativeCommandUseErrorActionPreference = $previousNativePreference
		}
	}
	$outputText = ($output | Out-String).Trim()
	if ($outputText -ne "") {
		Write-Host $outputText
	}
	$compileErrors = ($outputText -match "Compile Error:" -or $outputText -match "Identifier not found:" -or $outputText -match "Parse Error:")
	$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
	if ($exitCode -ne 0) {
		throw "Test suite failed: $TargetSuite"
	}
	if ($compileErrors) {
		throw "Test suite emitted compile or parse errors: $TargetSuite"
	}
}

if ($Suite -eq "all") {
	Run-Suite "unit"
	Run-Suite "uat"
}
else {
	Run-Suite $Suite
}

Write-Host "All requested tests passed."
