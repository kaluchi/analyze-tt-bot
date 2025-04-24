#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для конструктора и инициализации YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки корректности создания экземпляра YtDlpService и его инициализации.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "YtDlpService.Constructor Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
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
    }

    Context "Basic properties" {
        It "Should create an instance with correct properties" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                $ytDlpService.YtDlpPath | Should -Be "yt-dlp"
                $ytDlpService.FileSystemService | Should -Be $mockFileSystemService
                $ytDlpService.TimeoutSeconds | Should -Be 30
                $ytDlpService.DefaultFormat | Should -Be "best"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}