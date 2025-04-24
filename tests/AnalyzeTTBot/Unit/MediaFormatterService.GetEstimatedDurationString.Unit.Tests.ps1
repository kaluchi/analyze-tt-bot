#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода GetEstimatedDurationString сервиса MediaFormatterService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода GetEstimatedDurationString сервиса MediaFormatterService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "MediaFormatterService.GetEstimatedDurationString Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        # Строчка ниже устраняет эту ошибку
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")

        # Импортируем основной модуль
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
        
        # Вспомогательные модули для тестирования
        $helperPath = Join-Path $PSScriptRoot "..\Helpers\TestResponseHelper.psm1"
        if (Test-Path $helperPath) {
            Import-Module -Name $helperPath -Force -ErrorAction Stop
        }
    }

    Context "Duration Estimation" {
        It "Should return default duration when filesize is missing" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем данные без размера файла
                $mediaInfo = @{
                    success = $true
                    data = @{
                        FileSize = 0
                        FileSizeMB = 0
                        VideoBitRate = 1000000
                        AudioBitRate = 128000
                    }
                }
                
                # Вызываем метод
                $result = $mediaFormatterService.GetEstimatedDurationString($mediaInfo)
                
                # Проверяем результат
                $result | Should -BeExactly "Duration: 15 s 0 ms`n"
            }
        }
    }

    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
        if (Get-Module -Name TestResponseHelper) {
            Remove-Module -Name TestResponseHelper -Force -ErrorAction SilentlyContinue
        }
    }
}