# Скрипт оптимизации Docker на Windows
Write-Host "Оптимизация Docker для Windows..." -ForegroundColor Green

# Закрытие ненужных приложений
Get-Process | Where-Object { $_.Name -in @("OneDrive", "Teams", "Skype") } | Stop-Process -Force -ErrorAction SilentlyContinue

# Очистка неиспользуемых образов и контейнеров
Write-Host "Очистка неиспользуемых Docker ресурсов..." -ForegroundColor Yellow
docker system prune -f

# Настройка WSL 2
Write-Host "Оптимизация WSL 2..." -ForegroundColor Yellow
$wslConfigPath = "$env:USERPROFILE\.wslconfig"

$wslConfig = @"
[wsl2]
memory=8GB
processors=4
swap=4GB
localhostForwarding=true
kernelCommandLine = "sysctl.vm.swappiness=10"
"@

Set-Content -Path $wslConfigPath -Value $wslConfig -Force

Write-Host "Конфигурация WSL сохранена в $wslConfigPath" -ForegroundColor Green
Write-Host "Для применения изменений рекомендуется перезапустить Docker Desktop" -ForegroundColor Cyan 