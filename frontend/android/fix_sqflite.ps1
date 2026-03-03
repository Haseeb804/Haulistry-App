# Fix sqflite_android Utils.java compatibility issues with Android API 35
$filePath = "$env:LOCALAPPDATA\Pub\Cache\hosted\pub.dev\sqflite_android-2.4.2+2\android\src\main\java\com\tekartik\sqflite\Utils.java"

if (-not (Test-Path $filePath)) {
    Write-Host "Utils.java not found at: $filePath" -ForegroundColor Red
    exit 1
}

Write-Host "Reading Utils.java..." -ForegroundColor Cyan
$content = Get-Content $filePath -Raw

# Backup original file
$backupPath = "$filePath.backup"
if (-not (Test-Path $backupPath)) {
    Copy-Item $filePath $backupPath
    Write-Host "Created backup at: $backupPath" -ForegroundColor Green
}

# Fix 1: Replace Build.VERSION_CODES.BAKLAVA with Build.VERSION_CODES.UPSIDE_DOWN_CAKE (API 34)
$content = $content -replace 'Build\.VERSION_CODES\.BAKLAVA', 'Build.VERSION_CODES.UPSIDE_DOWN_CAKE'

# Fix 2: Replace Locale.of() with new Locale() for compatibility
$content = $content -replace 'return Locale\.of\(language, country, variant\);', 'return new Locale(language, country, variant);'

# Fix 3: Replace thread.threadId() with thread.getId() for compatibility
$content = $content -replace 'return thread\.threadId\(\);', 'return thread.getId();'

# Save the patched file
Set-Content $filePath $content -NoNewline

Write-Host "Successfully patched Utils.java" -ForegroundColor Green
Write-Host "Changes made:" -ForegroundColor Yellow
Write-Host "  - BAKLAVA changed to UPSIDE_DOWN_CAKE (API 34)" -ForegroundColor White
Write-Host "  - Locale.of() changed to new Locale()" -ForegroundColor White
Write-Host "  - thread.threadId() changed to thread.getId()" -ForegroundColor White
