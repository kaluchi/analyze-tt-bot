#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для конструктора и инициализации BotService.
.DESCRIPTION
    Модульные тесты для проверки корректности создания экземпляра BotService и его инициализации.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "BotService.Constructor Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
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
    }

    Context "Constructor and initialization" {
        It "Should create an instance with all dependencies correctly injected" {
            InModuleScope -ModuleName AnalyzeTTBot {
                $mockTelegramService = [ITelegramService]::new()
                $mockFileSystemService = [IFileSystemService]::new()
                $mockYtDlpService = [IYtDlpService]::new()
                $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
                $mockMediaFormatterService = [IMediaFormatterService]::new()
                $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
                $botService = New-Object -TypeName BotService -ArgumentList @(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoExtractorService,
                    $mockMediaFormatterService,
                    $mockHashtagGeneratorService,
                    $mockFileSystemService
                )
                $botService.TelegramService | Should -Be $mockTelegramService
                $botService.YtDlpService | Should -Be $mockYtDlpService
                $botService.MediaInfoExtractorService | Should -Be $mockMediaInfoExtractorService
                $botService.MediaFormatterService | Should -Be $mockMediaFormatterService
                $botService.HashtagGeneratorService | Should -Be $mockHashtagGeneratorService
                $botService.FileSystemService | Should -Be $mockFileSystemService
            }
        }
    }

    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}