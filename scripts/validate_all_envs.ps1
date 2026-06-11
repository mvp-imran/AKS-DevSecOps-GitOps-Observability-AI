# Validate all Terraform environments without breaking existing code
# This script uses the locally installed Terraform binary (path added by install_terraform.ps1)
$terraform = "$env:USERPROFILE\terraform\terraform.exe"
if (-Not (Test-Path $terraform)) {
    Write-Error "Terraform binary not found at $terraform. Ensure install_terraform.ps1 ran successfully."
    exit 1
}

# List of environment directories relative to the repo root
$envDirs = @(
    "platform-infra/terraform/environments/dev",
    "platform-infra/terraform/environments/qa",
    "platform-infra/terraform/environments/uat",
    "platform-infra/terraform/environments/prod"
)

foreach ($dir in $envDirs) {
    Write-Host "=== Validating $dir ==="
    # Resolve absolute path based on script location
    $repoRoot = (Resolve-Path "$PSScriptRoot/.." ).Path
    $targetPath = Join-Path $repoRoot $dir
    Set-Location $targetPath
    & $terraform init -backend-config=../backend.tf -input=false -reconfigure
    if ($LASTEXITCODE -ne 0) {
        Write-Error "terraform init failed for $dir"
        exit $LASTEXITCODE
    }
    & $terraform validate
    if ($LASTEXITCODE -ne 0) {
        Write-Error "terraform validate failed for $dir"
        exit $LASTEXITCODE
    }
    Write-Host "✅ $dir passed validation"
    Set-Location $repoRoot
}

Write-Host "All environments validated successfully."
