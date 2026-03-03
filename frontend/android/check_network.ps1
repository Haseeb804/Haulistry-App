# Network connectivity checker for Gradle builds
Write-Host "Checking network connectivity for Gradle dependencies..." -ForegroundColor Cyan

$hostsList = @(
    "dl.google.com",
    "repo.maven.apache.org",
    "services.gradle.org"
)

foreach ($hostname in $hostsList) {
    Write-Host "`nTesting: $hostname" -ForegroundColor Yellow
    try {
        $result = Test-Connection -ComputerName $hostname -Count 2 -ErrorAction Stop
        Write-Host "✓ $hostname is reachable" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ $hostname is NOT reachable" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n" -NoNewline
Write-Host "Checking DNS resolution..." -ForegroundColor Cyan
foreach ($hostname in $hostsList) {
    try {
        $dns = Resolve-DnsName $hostname -ErrorAction Stop
        Write-Host "✓ DNS resolves $hostname" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ DNS cannot resolve $hostname" -ForegroundColor Red
    }
}

Write-Host "`nIf hosts are unreachable, check:" -ForegroundColor Yellow
Write-Host "1. VPN/Firewall settings" -ForegroundColor White
Write-Host "2. Network proxy configuration" -ForegroundColor White
Write-Host "3. DNS settings" -ForegroundColor White
Write-Host "4. Internet connection" -ForegroundColor White
