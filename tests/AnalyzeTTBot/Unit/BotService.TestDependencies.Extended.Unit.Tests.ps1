#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода TestDependencies в BotService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода TestDependencies в BotService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "BotService.TestDependencies Extended Tests" {
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

    Context "Testing dependencies" {
        It "Should check all dependencies" {
            InModuleScope -ModuleName AnalyzeTTBot {
                $mockTelegramService = [ITelegramService]::new()
                $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $true; Version = '1.0'; Description = 'OK' } } } -Force
                $mockYtDlpService = [IYtDlpService]::new()
                $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                    return New-SuccessResponse -Data @{
                        Name = "yt-dlp"
                        Valid = $true
                        Version = "2023.03.04"
                        Description = "yt-dlp version 2023.03.04 найден"
                    }
                } -Force
                $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
                $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                    return New-SuccessResponse -Data @{
                        Name = "MediaInfo"
                        Valid = $true
                        Version = "MediaInfo CLI 21.09"
                        Description = "MediaInfo CLI 21.09 найден"
                    }
                } -Force
                $botService = New-Object -TypeName BotService -ArgumentList @(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoExtractorService,
                    $null, $null, $null
                )
                $result = $botService.TestDependencies($true, $false)
                $result.Success | Should -BeTrue
                $result.Data.Dependencies.Count | Should -BeGreaterThan 0
                $result.Data.AllValid | Should -BeTrue
            }
        }
        
        It "Should detect invalid dependencies" {
            InModuleScope -ModuleName AnalyzeTTBot {
                $mockTelegramService = [ITelegramService]::new()
                $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $false; Version = 'Н/Д'; Description = 'Токен не валиден' } } } -Force
                $mockYtDlpService = [IYtDlpService]::new()
                $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                    return New-SuccessResponse -Data @{
                        Name = "yt-dlp"
                        Valid = $false
                        Version = "Не найден"
                        Description = "yt-dlp не найден в системе"
                    }
                } -Force
                $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
                $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                    return New-SuccessResponse -Data @{
                        Name = "MediaInfo"
                        Valid = $false
                        Version = "Не найден"
                        Description = "MediaInfo не найден в системе"
                    }
                } -Force
                $botService = New-Object -TypeName BotService -ArgumentList @(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoExtractorService,
                    $null, $null, $null
                )
                $result = $botService.TestDependencies($true, $false)
                $result.Success | Should -BeTrue # результат возвращается как успешный, так как это не ошибка
                $result.Data.Dependencies.Count | Should -BeGreaterThan 0
                $result.Data.AllValid | Should -BeFalse # но зависимости не валидны
            }
        }
    }

    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}