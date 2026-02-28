param(
	[ValidateSet("all", "unit", "uat")]
	[string]$Suite = "all",
	[string]$GodotBin = "godot"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

function Run-Suite([string]$TargetSuite) {
	Write-Host "Running $TargetSuite tests..."
	& $GodotBin --headless --path $ProjectRoot --script res://tests/framework/TestRunner.gd -- --suite=$TargetSuite
	$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
	if ($exitCode -ne 0) {
		throw "Test suite failed: $TargetSuite"
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
