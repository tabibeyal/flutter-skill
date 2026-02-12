# Flutter Skill Uninstall Script (Windows PowerShell)

$ErrorActionPreference = "Continue"

Write-Host "Flutter Skill Uninstall" -ForegroundColor Blue
Write-Host ""

$removed = 0

# 1. Remove npm global package
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $npmList = npm list -g flutter-skill 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Removing npm package flutter-skill..." -ForegroundColor Yellow
        npm uninstall -g flutter-skill
        Write-Host "  Removed npm package" -ForegroundColor Green
        $removed++
    }
}

# 2. Remove Scoop package
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    $scoopList = scoop list flutter-skill 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Removing Scoop package flutter-skill..." -ForegroundColor Yellow
        scoop uninstall flutter-skill
        Write-Host "  Removed Scoop package" -ForegroundColor Green
        $removed++
    }
}

# 3. Remove source installation
$srcDir = "$env:USERPROFILE\.flutter-skill-src"
if (Test-Path $srcDir) {
    Write-Host "Removing source installation..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $srcDir
    Write-Host "  Removed $srcDir" -ForegroundColor Green
    $removed++
}

# 4. Remove wrapper script
$wrapperPath = "$env:USERPROFILE\bin\flutter-skill.bat"
if (Test-Path $wrapperPath) {
    Write-Host "Removing wrapper script..." -ForegroundColor Yellow
    Remove-Item -Force $wrapperPath
    Write-Host "  Removed $wrapperPath" -ForegroundColor Green
    $removed++
}

# 5. Remove cached files
$cacheDir = "$env:USERPROFILE\.flutter-skill"
if (Test-Path $cacheDir) {
    Write-Host "Removing cached files..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $cacheDir
    Write-Host "  Removed $cacheDir" -ForegroundColor Green
    $removed++
}

# 6. Remove Dart global activation
if (Get-Command dart -ErrorAction SilentlyContinue) {
    $dartList = dart pub global list 2>$null
    if ($dartList -match "flutter_skill") {
        Write-Host "Removing Dart global activation..." -ForegroundColor Yellow
        dart pub global deactivate flutter_skill 2>$null
        Write-Host "  Removed Dart global package" -ForegroundColor Green
        $removed++
    }
}

# 7. Remove tool priority rules
$rulesFile = "$env:USERPROFILE\.claude\prompts\flutter-tool-priority.md"
if (Test-Path $rulesFile) {
    Write-Host "Removing tool priority rules..." -ForegroundColor Yellow
    Remove-Item -Force $rulesFile
    Write-Host "  Removed $rulesFile" -ForegroundColor Green
    $removed++
}

# 8. Clean up PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -like "*flutter-skill*") {
    Write-Host "Cleaning flutter-skill from PATH..." -ForegroundColor Yellow
    $newPath = ($UserPath.Split(';') | Where-Object { $_ -notlike "*flutter-skill*" }) -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "  Cleaned PATH" -ForegroundColor Green
    $removed++
}

Write-Host ""
if ($removed -eq 0) {
    Write-Host "No flutter-skill installation found."
} else {
    Write-Host "Uninstall complete! Removed $removed items." -ForegroundColor Green
    Write-Host "You may need to restart your terminal for changes to take effect." -ForegroundColor Yellow
}
