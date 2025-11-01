# Install Foundry Dependencies Script
# Run this script to set up the project for compilation

Write-Host "Setting up Foundry project..." -ForegroundColor Green

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Git is required but not found. Please install Git first." -ForegroundColor Red
    Write-Host "Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# Navigate to project directory
$projectDir = $PSScriptRoot
Set-Location $projectDir

# Check if forge-std exists
if (-not (Test-Path "lib\forge-std")) {
    Write-Host "Installing forge-std..." -ForegroundColor Yellow
    git submodule add https://github.com/foundry-rs/forge-std lib/forge-std 2>$null
    if (-not $?) {
        git clone https://github.com/foundry-rs/forge-std lib/forge-std
    }
}

# Check if openzeppelin-contracts exists
if (-not (Test-Path "lib\openzeppelin-contracts")) {
    Write-Host "Installing OpenZeppelin contracts..." -ForegroundColor Yellow
    git submodule add https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin-contracts 2>$null
    if (-not $?) {
        git clone https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin-contracts
    }
}

Write-Host "`nDependencies installed successfully!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Install Foundry from: https://getfoundry.sh/" -ForegroundColor White
Write-Host "   OR run in Git Bash: curl -L https://foundry.paradigm.xyz | bash && foundryup" -ForegroundColor White
Write-Host "2. Run: forge build" -ForegroundColor White
Write-Host "3. Run tests: forge test" -ForegroundColor White

