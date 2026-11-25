$ErrorActionPreference = 'Stop'

Write-Host 'BMS Offline Android build' -ForegroundColor Cyan

Write-Host "`n[1/4] Resolving Flutter packages..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }

Write-Host "`n[2/4] Analyzing Dart code..." -ForegroundColor Yellow
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed. Fix the listed issues before APK build.' }

Write-Host "`n[3/4] Running automated tests..." -ForegroundColor Yellow
flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed. Fix the listed test failures before APK build.' }

Write-Host "`n[4/4] Building release APK..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'Flutter APK build failed.' }

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (!(Test-Path $apk)) { throw "Build command completed but APK was not found at: $apk" }
Write-Host "`nAPK ready: $apk" -ForegroundColor Green
