
<#
.SYNOPSIS
Подсчитывает количество строк в каждом тестовом файле проекта.

.DESCRIPTION
Этот скрипт анализирует все тестовые файлы (*.Tests.ps1) в указанном каталоге,
подсчитывает количество строк кода в каждом файле и выводит статистику.

.PARAMETER TestsRootPath
Путь к корневому каталогу с тестами. По умолчанию: '..\tests'

.EXAMPLE
.\Get-TestLinesCount.ps1
Анализирует все тесты в каталоге по умолчанию.

.EXAMPLE
.\Get-TestLinesCount.ps1 -TestsRootPath "D:\Projects\MyModule\tests"
Анализирует все тесты в указанном каталоге.

.NOTES
Автор: QA Pester Специалист
Дата: 21.04.2025
#>

[CmdletBinding()]
param (
    [string]$TestsRootPath = (Join-Path $PSScriptRoot '..\tests')
)

# Функция для получения всех тестовых файлов рекурсивно
function Get-AllTestFiles {
    param (
        [string]$Path
    )

    Get-ChildItem -Path $Path -Recurse -Filter "*.Tests.ps1" -File
}

# Функция для подсчета строк в файле
function Get-FileLineCount {
    param (
        [System.IO.FileInfo]$File
    )

    $content = Get-Content -Path $File.FullName
    return @{
        TotalLines = $content.Count
        NonEmptyLines = ($content | Where-Object { $_ -match '\S' }).Count
        NonCommentLines = ($content | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#' }).Count
    }
}

# Основная логика скрипта
function Get-TestStatistics {
    param (
        [string]$RootPath
    )

    Write-Host "Анализ тестовых файлов в каталоге: $RootPath" -ForegroundColor Cyan
    
    # Получаем все тестовые файлы
    $testFiles = Get-AllTestFiles -Path $RootPath
    $totalFiles = $testFiles.Count
    
    if ($totalFiles -eq 0) {
        Write-Host "Тестовые файлы не найдены в указанном каталоге." -ForegroundColor Yellow
        return
    }
    
    Write-Host "Найдено тестовых файлов: $totalFiles" -ForegroundColor Green
    
    # Создаем таблицу результатов
    $results = @()
    $totalLines = 0
    $totalNonEmptyLines = 0
    $totalNonCommentLines = 0
    
    foreach ($file in $testFiles) {
        $relativePath = $file.FullName.Replace($RootPath, "").TrimStart("\")
        $lineStats = Get-FileLineCount -File $file
        
        # Добавляем результаты в массив
        $results += [PSCustomObject]@{
            TestFile = $relativePath
            TotalLines = $lineStats.TotalLines
            NonEmptyLines = $lineStats.NonEmptyLines
            CodeLines = $lineStats.NonCommentLines
        }
        
        # Суммируем для общей статистики
        $totalLines += $lineStats.TotalLines
        $totalNonEmptyLines += $lineStats.NonEmptyLines
        $totalNonCommentLines += $lineStats.NonCommentLines
    }
    
    # Сортируем результаты по количеству строк кода (по убыванию)
    $sortedResults = $results | Sort-Object -Property CodeLines -Descending
    
    # Выводим таблицу результатов
    Write-Host "`nСтатистика по тестовым файлам (сортировка по количеству строк кода):" -ForegroundColor Cyan
    $sortedResults | Format-Table -AutoSize
    
    # Выводим общую статистику
    Write-Host "Общая статистика:" -ForegroundColor Cyan
    Write-Host "Всего тестовых файлов: $totalFiles" -ForegroundColor Green
    Write-Host "Всего строк: $totalLines" -ForegroundColor Green
    Write-Host "Всего непустых строк: $totalNonEmptyLines" -ForegroundColor Green
    Write-Host "Всего строк кода: $totalNonCommentLines" -ForegroundColor Green
    Write-Host "Среднее количество строк кода на файл: $([math]::Round($totalNonCommentLines / $totalFiles, 2))" -ForegroundColor Green
    
    # Находим файлы с наибольшим и наименьшим количеством строк
    $maxLinesFile = $sortedResults[0]
    $minLinesFile = ($sortedResults | Sort-Object -Property CodeLines)[0]
    
    Write-Host "`nФайл с наибольшим количеством строк кода:" -ForegroundColor Yellow
    Write-Host "$($maxLinesFile.TestFile) - $($maxLinesFile.CodeLines) строк" -ForegroundColor Yellow
    
    Write-Host "`nФайл с наименьшим количеством строк кода:" -ForegroundColor Yellow
    Write-Host "$($minLinesFile.TestFile) - $($minLinesFile.CodeLines) строк" -ForegroundColor Yellow
    
   
}

# Запуск анализа
Get-TestStatistics -RootPath $TestsRootPath

