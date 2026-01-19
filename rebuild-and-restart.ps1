#!/usr/bin/env pwsh
# Полная пересборка и перезапуск AI Web Agent

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "AI Web Agent - Rebuild and Restart" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

# 1. Остановить прокси-сервер
Write-Host "[1/4] Остановка прокси-сервера..." -ForegroundColor Yellow
Get-NetTCPConnection -LocalPort 3131 -ErrorAction SilentlyContinue | ForEach-Object { 
    Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 1
Write-Host "✓ Сервер остановлен`n" -ForegroundColor Green

# 2. Сборка расширения
Write-Host "[2/4] Сборка Chrome расширения..." -ForegroundColor Yellow
Set-Location "d:\browser 2.0"
$result = npm run build 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Расширение собрано`n" -ForegroundColor Green
} else {
    Write-Host "✗ Ошибка сборки расширения`n" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}

# 3. Сборка прокси
Write-Host "[3/4] Сборка прокси-сервера..." -ForegroundColor Yellow
Set-Location "d:\browser 2.0\agent-proxy"
$result = npm run build 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Прокси собран`n" -ForegroundColor Green
} else {
    Write-Host "✗ Ошибка сборки прокси`n" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}

# 4. Запуск прокси
Write-Host "[4/4] Запуск прокси-сервера..." -ForegroundColor Yellow
Start-Process pwsh -ArgumentList "-NoExit", "-Command", "cd 'd:\browser 2.0\agent-proxy'; npm start" -WindowStyle Normal
Start-Sleep -Seconds 3
Write-Host "✓ Сервер запущен`n" -ForegroundColor Green

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "✅ ВСЁ ГОТОВО!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Cyan

Write-Host "Следующие шаги:" -ForegroundColor Yellow
Write-Host "1. Откройте chrome://extensions" -ForegroundColor White
Write-Host "2. Нажмите 'Обновить' (↻) на расширении AI Web Agent" -ForegroundColor White
Write-Host "3. Откройте любой сайт (например hh.ru)" -ForegroundColor White
Write-Host "4. Запустите задачу в расширении`n" -ForegroundColor White

Write-Host "Прокси работает: http://localhost:3131" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan
