# Скрипт для сборки и тестирования проекта с оптимизацией кеширования

# Если мешает - то отключаем BuildKit установкой в 0
$env:DOCKER_BUILDKIT=1

# Функция для отображения статуса
function Write-Status {
    param ([string]$Message)
    Write-Host ""
    Write-Host "🚀 $Message" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor DarkCyan
}

# Создание директорий для временных файлов и результатов тестов
if (-not (Test-Path ".\temp")) {
    New-Item -Path ".\temp" -ItemType Directory | Out-Null
}
if (-not (Test-Path ".\temp\test-results")) {
    New-Item -Path ".\temp\test-results" -ItemType Directory | Out-Null
}
if (-not (Test-Path ".\temp\logs")) {
    New-Item -Path ".\temp\logs" -ItemType Directory | Out-Null
}

# Сборка тестового образа
Write-Status "Сборка образов"
docker build -f Dockerfile .

Write-Status "Сборка завершена успешно!"
Write-Host "Доступные образы:" -ForegroundColor Green
docker images | Where-Object { $_ -match 'analyze-tt-bot' }

# Инструкции по запуску
Write-Host ""
Write-Host "Запуск приложения:" -ForegroundColor Yellow
Write-Host "docker run --rm -e TELEGRAM_BOT_TOKEN=your_token -t analyze-tt-bot"

Write-Host ""
Write-Host "Запуск тестов:" -ForegroundColor Yellow
Write-Host "docker run --rm -t analyze-tt-bot-test"