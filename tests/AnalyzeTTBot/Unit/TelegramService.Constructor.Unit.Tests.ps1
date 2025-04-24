#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для конструктора и инициализации TelegramService.
.DESCRIPTION
    Модульные тесты для проверки корректности создания экземпляра TelegramService и его инициализации.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "TelegramService.Constructor Tests" {
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
        
        # Устанавливаем тестовые параметры
        $script:testToken = "test_token_123456789"
        $script:testMaxFileSizeMB = 50
    }

    Context "Constructor and initialization" {
        It "Should create an instance with correct token and max file size" {
            InModuleScope AnalyzeTTBot -Parameters @{token = $script:testToken; maxFileSizeMB = $script:testMaxFileSizeMB} {                
                $service = [TelegramService]::new($token, $maxFileSizeMB)
                $service.Token | Should -Be $token
                $service.MaxFileSizeMB | Should -Be $maxFileSizeMB
            }
        }
    }
    
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}