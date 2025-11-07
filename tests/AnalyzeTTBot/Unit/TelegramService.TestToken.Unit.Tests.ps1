#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода TestToken в TelegramService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода TestToken сервиса TelegramService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

#region TelegramService.TestToken.Unit.Tests

Describe 'TelegramService.TestToken' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..')
        $manifestPath = Join-Path $projectRoot 'src/AnalyzeTTBot/AnalyzeTTBot.psd1'
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Возвращает ошибку, если токен пустой' {
        InModuleScope AnalyzeTTBot {
            # Мок для предотвращения реальных HTTP запросов
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { throw 'Mocked error' }
            $service = [TelegramService]::new('', 50)
            $result = $service.TestToken($false)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Токен Telegram не настроен'
            $result.Data.Valid | Should -BeFalse
        }
    }
    It 'Возвращает ошибку, если токен YOUR_BOT_TOKEN_HERE' {
        InModuleScope AnalyzeTTBot {
            # Мок для предотвращения реальных HTTP запросов
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { throw 'Mocked error' }
            $service = [TelegramService]::new('YOUR_BOT_TOKEN_HERE', 50)
            $result = $service.TestToken($false)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Токен Telegram не настроен'
            $result.Data.Valid | Should -BeFalse
        }
    }
    It 'Возвращает успех, если SkipTokenValidation' {
        InModuleScope AnalyzeTTBot {
            $service = [TelegramService]::new('SOME_TOKEN', 50)
            $result = $service.TestToken($true)
            $result.Success | Should -BeTrue
            $result.Data.Valid | Should -BeTrue
            $result.Data.Description | Should -Match 'Валидация токена пропущена'
        }
    }
    It 'Возвращает ошибку, если токен PLACE_YOUR_REAL_TOKEN_HERE' {
        InModuleScope AnalyzeTTBot {
            # Мок для предотвращения реальных HTTP запросов
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { throw 'Mocked error' }
            $service = [TelegramService]::new('PLACE_YOUR_REAL_TOKEN_HERE', 50)
            $result = $service.TestToken($false)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Токен Telegram не настроен'
            $result.Data.Valid | Should -BeFalse
        }
    }
    It 'Возвращает ошибку при невалидном токене (мокаем Invoke-CurlMethod)' {
        InModuleScope AnalyzeTTBot {
            $service = [TelegramService]::new('INVALID_TOKEN', 50)
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { throw '401 Unauthorized' }
            $result = $service.TestToken($false)
            $result.Success | Should -BeFalse
            $result.Data.Valid | Should -BeFalse
            $result.Data.Description | Should -Match 'Не удалось подключиться к API Telegram'
        }
    }
    It 'Возвращает успех при валидном токене (мокаем Invoke-CurlMethod)' {
        InModuleScope AnalyzeTTBot {
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            $mockResponse = @{ ok = $true; result = @{ username = 'test_bot' } }
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { $mockResponse }
            $result = $service.TestToken($false)
            $result.Success | Should -BeTrue
            $result.Data.Valid | Should -BeTrue
            $result.Data.Version | Should -Be '@test_bot'
            $result.Data.Description | Should -Match 'Бот @test_bot активен'
        }
    }
}
#endregion
