# Read-only preflight for the search-api-version-cut skill.
param(
    [string]$CliPath = (Resolve-Path "$PSScriptRoot\..\..\..\..").Path,
    [string]$AazPath = (Join-Path (Split-Path $CliPath -Parent) 'aaz'),
    [string]$SpecsPath = (Join-Path (Split-Path $CliPath -Parent) 'azure-rest-api-specs')
)

function Check($name, $ok, $hint) {
    $mark = if ($ok) { 'OK     ' } else { 'MISSING' }
    Write-Host "[$mark] $name$(if (-not $ok) { " -> $hint" })"
}

Check 'azure-cli clone' (Test-Path "$CliPath\.git") 'clone Azure/azure-cli'
Check 'aaz repo' (Test-Path "$AazPath\.git") "git clone https://github.com/Azure/aaz $AazPath"
Check 'azure-rest-api-specs repo' (Test-Path "$SpecsPath\.git") "git clone https://github.com/Azure/azure-rest-api-specs $SpecsPath (use --depth 1 --filter=blob:none --sparse for speed)"
Check 'python' ([bool](Get-Command python -ErrorAction SilentlyContinue)) 'install Python 3.10-3.14'
Check 'virtualenv active' ([bool]$env:VIRTUAL_ENV) 'create and activate a venv'
Check 'azdev' ([bool](Get-Command azdev -ErrorAction SilentlyContinue)) 'pip install azdev'
Check 'aaz-dev' ([bool](Get-Command aaz-dev -ErrorAction SilentlyContinue)) 'pip install aaz-dev'

$create = Join-Path $CliPath 'src\azure-cli\azure\cli\command_modules\search\aaz\latest\search\service\_create.py'
if (Test-Path $create) {
    $v = (Select-String -Path $create -Pattern '"version":\s*"([^"]+)"' | Select-Object -First 1).Matches.Groups[1].Value
    Write-Host "Current generated search service API version: $v"
}
