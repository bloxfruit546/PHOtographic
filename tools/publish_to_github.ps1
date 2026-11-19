param(
    [Parameter(Mandatory = $false)]
    [string]$RemoteUrl = ""
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Git CLI is not installed or not on PATH." -ForegroundColor Red
    Write-Host "Install Git for Windows via:" -ForegroundColor Yellow
    Write-Host "  winget install --id Git.Git -e" -ForegroundColor Cyan
    exit 1
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot

try {
    if (-not (Test-Path ".git")) {
        git init
        git branch -M main
    }

    if (-not (git config --get user.name)) {
        git config user.name "PS12 Developer"
    }
    if (-not (git config --get user.email)) {
        git config user.email "dev@ps12.local"
    }

    git add -A
    $status = git status --porcelain
    if ($status) {
        git commit -m "release: PhotographicStyles12 v2.0.0"
    } else {
        Write-Host "[INFO] Working tree clean; nothing new to commit." -ForegroundColor Yellow
    }

    if ($RemoteUrl -ne "") {
        $existingOrigin = git remote 2>$null | Where-Object { $_ -eq "origin" }
        if ($existingOrigin) {
            git remote set-url origin $RemoteUrl
        } else {
            git remote add origin $RemoteUrl
        }
        git push -u origin main
        Write-Host "[OK] Pushed to $RemoteUrl. Check GitHub Actions for the compiled .deb artifact!" -ForegroundColor Green
    } elseif (git remote 2>$null | Where-Object { $_ -eq "origin" }) {
        git push
        Write-Host "[OK] Pushed incremental commit to origin. Check GitHub Actions for the compiled .deb artifact!" -ForegroundColor Green
    } else {
        Write-Host "[OK] Local commit ready. Pass -RemoteUrl https://github.com/<user>/<repo>.git to push." -ForegroundColor Green
    }
} finally {
    Pop-Location
}
