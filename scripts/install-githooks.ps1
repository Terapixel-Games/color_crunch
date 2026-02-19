$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

Push-Location $RepoRoot
try {
	& git config core.hooksPath .githooks
	$exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { [int]$LASTEXITCODE }
	if ($exitCode -ne 0) {
		throw "Failed to set core.hooksPath to .githooks"
	}
}
finally {
	Pop-Location
}

Write-Host "Git hooks installed: core.hooksPath=.githooks"
