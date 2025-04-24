<#
.SYNOPSIS
    Анализирует покрытие кода тестами для сервисов AnalyzeTTBot.
.DESCRIPTION
    Скрипт выполняет запуск всех тестов и анализирует покрытие кода для каждого сервиса.
    Показывает общее покрытие и детальную информацию по каждому файлу.
.PARAMETER TestPath
    Путь к каталогу с тестами. По умолчанию ".\tests".
.PARAMETER ServicePath
    Путь к каталогу с сервисами. По умолчанию ".\src\AnalyzeTTBot\Services".
.PARAMETER MinCoverage
    Минимальный рекомендуемый процент покрытия. По умолчанию 80%.
.EXAMPLE
    .\Get-TestCoverage.ps1
    Запускает анализ с параметрами по умолчанию.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 20.04.2025
#>
[CmdletBinding()]
param (
    [string]$TestPath = ".\tests",
    [string]$ServicePath = ".\src\AnalyzeTTBot\Services",
    [int]$MinCoverage = 80,
    [string]$TempDir = $null
)

# Проверка наличия Pester
if (-not (Get-Module -Name Pester -ListAvailable)) {
    Write-Host "Модуль Pester не установлен. Установка..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck
}

# Создаем каталог для временных файлов, если не указан явно
if ([string]::IsNullOrEmpty($TempDir)) {
    $TempDir = Join-Path (Get-Location) "temp"
}
if (-not (Test-Path $TempDir)) {
    Write-Host "Создание временного каталога: $TempDir" -ForegroundColor Yellow
    New-Item -Path $TempDir -ItemType Directory -Force | Out-Null
}
Write-Host "Используем временный каталог: $TempDir" -ForegroundColor Cyan

Import-Module Pester -ErrorAction Stop

# Проверка и вывод путей для диагностики
Write-Host "Проверка путей:" -ForegroundColor Cyan
Write-Host "Поиск TestPath: $TestPath" -ForegroundColor Yellow
if (Test-Path -Path $TestPath) {
    $TestPath = (Resolve-Path -Path $TestPath -ErrorAction Stop).Path
    Write-Host "TestPath найден: $TestPath" -ForegroundColor Green
} else {
    Write-Host "ВНИМАНИЕ: TestPath не найден: $TestPath" -ForegroundColor Red
    Write-Host "Текущий каталог: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Доступные каталоги:" -ForegroundColor Yellow
    Get-ChildItem -Directory | ForEach-Object { Write-Host "  - $($_.FullName)" }
    throw "Каталог с тестами не найден"
}

Write-Host "Поиск ServicePath: $ServicePath" -ForegroundColor Yellow
if (Test-Path -Path $ServicePath) {
    $ServicePath = (Resolve-Path -Path $ServicePath -ErrorAction Stop).Path
    Write-Host "ServicePath найден: $ServicePath" -ForegroundColor Green
} else {
    Write-Host "ВНИМАНИЕ: ServicePath не найден: $ServicePath" -ForegroundColor Red
    Write-Host "Текущий каталог: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Доступные каталоги:" -ForegroundColor Yellow
    Get-ChildItem -Directory | ForEach-Object { Write-Host "  - $($_.FullName)" }
    throw "Каталог с сервисами не найден"
}

Write-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "     АНАЛИЗ ПОКРЫТИЯ КОДА ТЕСТАМИ" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Запуск всех тестов и анализ покрытия кода..." -ForegroundColor Yellow
Write-Host "Это может занять некоторое время..." -ForegroundColor Yellow
Write-Host

$services = Get-ChildItem -Path "$ServicePath\*.ps1"
$totalServices = $services.Count

# Общий анализ покрытия
$overallCoverageFile = Join-Path $TempDir ("coverage_all_" + [guid]::NewGuid().Guid + ".xml")
Write-Host "Файл общего покрытия: $overallCoverageFile" -ForegroundColor Cyan
$pesterConfig = [PesterConfiguration]@{
    Run = @{ 
        Path = "$TestPath\*Unit.Tests.ps1"
        PassThru = $true
    }
    CodeCoverage = @{
        Enabled = $true
        Path = "$ServicePath\*.ps1"
        OutputFormat = 'JaCoCo'
        OutputPath = $overallCoverageFile
    }
    Output = @{ 
        Verbosity = 'Normal'
    }
}

try {
    $result = Invoke-Pester -Configuration $pesterConfig
    Write-Host "Результат запуска Pester: $($result.Result)" -ForegroundColor Green
} catch {
    Write-Host "Ошибка при запуске Pester: $_" -ForegroundColor Red
    throw $_
}

# Проверка результатов покрытия
if (Test-Path $overallCoverageFile) {
    Write-Host "Чтение файла покрытия: $overallCoverageFile" -ForegroundColor Green
    try {
        [xml]$coverageXml = Get-Content $overallCoverageFile -ErrorAction Stop
    } catch {
        Write-Host "Ошибка при чтении файла покрытия: $_" -ForegroundColor Red
        throw "Файл покрытия недействителен или поврежден"
    }
} else {
    Write-Host "ОШИБКА: Файл покрытия не найден: $overallCoverageFile" -ForegroundColor Red
    throw "Файл покрытия не создан. Возможно, проблема с правами доступа или Pester не смог сгенерировать отчет."
}

# Анализ данных покрытия
$allClasses = $coverageXml.report.package.class
$totalCommands = 0
$executedCommands = 0
foreach ($class in $allClasses) {
    foreach ($counter in $class.counter) {
        if ($counter.type -eq 'INSTRUCTION') {
            $totalCommands += [int]$counter.missed + [int]$counter.covered
            $executedCommands += [int]$counter.covered
        }
    }
}
$overallCoverage = if ($totalCommands -gt 0) {
    [math]::Round(($executedCommands / $totalCommands) * 100, 2)
} else { 0 }

Write-Host "Готово!" -ForegroundColor Green
Write-Host
Write-Host "ОБЩЕЕ ПОКРЫТИЕ ВСЕХ СЕРВИСОВ:" -ForegroundColor White
Write-Host "Покрытие: $overallCoverage% ($executedCommands из $totalCommands команд)" -ForegroundColor Cyan

$barWidth = 50
$filledChars = [math]::Round($barWidth * ($overallCoverage / 100))
$emptyChars = $barWidth - $filledChars
$barColor = if ($overallCoverage -lt 50) { "Red" }
            elseif ($overallCoverage -lt 70) { "Yellow" }
            elseif ($overallCoverage -lt 85) { "Cyan" }
            else { "Green" }
Write-Host "[" -NoNewline
Write-Host ("#" * $filledChars) -ForegroundColor $barColor -NoNewline
Write-Host (" " * $emptyChars) -NoNewline
Write-Host "] $overallCoverage%" -ForegroundColor $barColor

Write-Host
Write-Host "АНАЛИЗ ОТДЕЛЬНЫХ СЕРВИСОВ:" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Сервис                                   Покрытие     Команд"
Write-Host "------                                   --------     ------" -ForegroundColor Cyan

# Обработка данных из общего файла покрытия вместо создания отдельных
$results = @()
foreach ($service in $services) {
    Write-Host "Анализ $($service.Name)... " -ForegroundColor Yellow -NoNewline
    
    # Используем информацию из общего файла покрытия
    $fileCommands = 0
    $fileExecuted = 0
    
    # Имя файла без пути для сопоставления с данными в отчете
    $fileName = $service.Name
    
    # Ищем классы, соответствующие этому файлу в отчете покрытия
    $serviceClasses = $allClasses | Where-Object { $_.sourcefile -eq $fileName -or $_.name -like "*$($service.BaseName)*" }
    
    if ($serviceClasses) {
        foreach ($class in $serviceClasses) {
            foreach ($counter in $class.counter) {
                if ($counter.type -eq 'INSTRUCTION') {
                    $fileCommands += [int]$counter.missed + [int]$counter.covered
                    $fileExecuted += [int]$counter.covered
                }
            }
        }
        
        $fileCoverage = if ($fileCommands -gt 0) {
            [math]::Round(($fileExecuted / $fileCommands) * 100, 2)
        } else { 0 }
        
        $results += [PSCustomObject]@{
            Name = $service.Name
            Coverage = $fileCoverage
            Commands = $fileCommands
            Executed = $fileExecuted
            Path = $service.FullName
        }
        
        Write-Host "Обработано из общего отчета: $fileExecuted из $fileCommands команд ($fileCoverage%)" -ForegroundColor Green
    } else {
        Write-Host "Не найдено покрытие для данного сервиса" -ForegroundColor Yellow
        $results += [PSCustomObject]@{
            Name = $service.Name
            Coverage = 0
            Commands = 0
            Executed = 0
            Path = $service.FullName
        }
    }
}

$sortedResults = $results | Sort-Object -Property Coverage
foreach ($item in $sortedResults) {
    $coverageColor = if ($item.Coverage -lt 50) { "Red" }
                    elseif ($item.Coverage -lt 70) { "Yellow" }
                    elseif ($item.Coverage -lt 85) { "Cyan" }
                    else { "Green" }
    $serviceName = $item.Name.PadRight(35)
    $coverageStr = ("{0:N2}%" -f $item.Coverage).PadRight(10)
    $commandsStr = "$($item.Executed)/$($item.Commands)"
    Write-Host $serviceName -NoNewline
    Write-Host $coverageStr -ForegroundColor $coverageColor -NoNewline
    Write-Host $commandsStr -ForegroundColor Gray
}

Write-Host
Write-Host "РЕКОМЕНДАЦИИ ПО УЛУЧШЕНИЮ ПОКРЫТИЯ:" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor Cyan

$lowCoverageServices = $sortedResults | Where-Object { $_.Coverage -lt $MinCoverage }
if ($lowCoverageServices.Count -eq 0) {
    Write-Host "Все сервисы имеют покрытие более $MinCoverage%. Отличная работа!" -ForegroundColor Green
} else {
    Write-Host "Следующие сервисы имеют покрытие ниже рекомендуемого ($MinCoverage%):" -ForegroundColor Yellow
    foreach ($service in $lowCoverageServices) {
        Write-Host "  - $($service.Name): " -NoNewline
        Write-Host "$($service.Coverage)%" -ForegroundColor Red
    }
}

Write-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "     АНАЛИЗ ЗАВЕРШЕН" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host
Write-Host "Файл покрытия сохранен в: $overallCoverageFile" -ForegroundColor Cyan
# Не удаляем файл для возможности дальнейшего анализа