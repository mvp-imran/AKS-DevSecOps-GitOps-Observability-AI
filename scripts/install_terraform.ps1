# Install Terraform binary on Windows
# This script downloads the latest Terraform (1.7.x) zip, extracts it, and adds it to PATH for the current session.
$version = "1.7.5"
$zipUrl = "https://releases.hashicorp.com/terraform/$version/terraform_${version}_windows_amd64.zip"
$destDir = "$env:USERPROFILE\terraform"
$zipPath = "$destDir\terraform.zip"

# Ensure destination directory exists
if (-Not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir | Out-Null
}

# Download zip
Write-Host "Downloading Terraform $version..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

# Extract zip
Write-Host "Extracting Terraform..."
Expand-Archive -Path $zipPath -DestinationPath $destDir -Force

# Clean up zip file
Remove-Item $zipPath -Force

# Add to PATH for current session
$env:Path = "$destDir;$env:Path"
Write-Host "Terraform installed to $destDir and added to PATH."
# Verify installation
terraform version
