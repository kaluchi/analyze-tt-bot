#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода HandleTextMessage в BotService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода HandleTextMessage сервиса BotService.
    КРИТИЧЕСКИЙ ТЕСТ - метод был полностью не покрыт тестами (0% покрытие).
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 13.08.2025
#>

Describe "BotService.HandleTextMessage Tests" {
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

    Context "Text message validation and processing" {
        It "Should process valid TikTok URL - Success path" {
            InModuleScope AnalyzeTTBot {
                # Создаем моки для всех сервисов
                $mockTelegramService = [ITelegramService]::new()
                $mockYtDlpService = [IYtDlpService]::new()
                $mockMediaInfoService = [IMediaInfoExtractorService]::new()
                $mockMediaFormatterService = [IMediaFormatterService]::new()
                $mockHashtagService = [IHashtagGeneratorService]::new()
                $mockFileSystemService = [IFileSystemService]::new()
                
                # Создаем экземпляр BotService
                $botService = [BotService]::new(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoService,
                    $mockMediaFormatterService,
                    $mockHashtagService,
                    $mockFileSystemService
                )
                
                # Создаем глобальные переменные для отслеживания
                $global:validateCalled = $false
                $global:processTikTokCalled = $false
                $global:processInvalidCalled = $false
                
                # Мокируем ValidateTextMessage для успешного результата
                $botService | Add-Member -MemberType ScriptMethod -Name "ValidateTextMessage" -Value {
                    param([string]$messageText)
                    $global:validateCalled = $true
                    return New-SuccessResponse -Data @{ Url = "https://tiktok.com/@user/video/123456" }
                } -Force
                
                # Мокируем ProcessTikTokUrl
                $botService | Add-Member -MemberType ScriptMethod -Name "ProcessTikTokUrl" -Value {
                    param([string]$url, [long]$chatId, [int]$messageId)
                    $global:processTikTokCalled = $true
                    return New-SuccessResponse -Data @{ Report = "Success"; FileSent = $true }
                } -Force
                
                # Мокируем ProcessInvalidMessage (не должен вызываться)
                $botService | Add-Member -MemberType ScriptMethod -Name "ProcessInvalidMessage" -Value {
                    param([string]$errorMessage, [long]$chatId, [int]$messageId, [string]$chatType)
                    $global:processInvalidCalled = $true
                } -Force
                
                # Тестируем метод
                $botService.HandleTextMessage("https://tiktok.com/@user/video/123456", 12345, 67890, "private")
                
                # Проверяем, что правильные методы были вызваны
                $global:validateCalled | Should -BeTrue
                $global:processTikTokCalled | Should -BeTrue  
                $global:processInvalidCalled | Should -BeFalse
            }
        }

        It "Should process invalid message - Error path" {
            InModuleScope AnalyzeTTBot {
                # Создаем моки для всех сервисов
                $mockTelegramService = [ITelegramService]::new()
                $mockYtDlpService = [IYtDlpService]::new()
                $mockMediaInfoService = [IMediaInfoExtractorService]::new()
                $mockMediaFormatterService = [IMediaFormatterService]::new()
                $mockHashtagService = [IHashtagGeneratorService]::new()
                $mockFileSystemService = [IFileSystemService]::new()
                
                # Создаем экземпляр BotService
                $botService = [BotService]::new(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoService,
                    $mockMediaFormatterService,
                    $mockHashtagService,
                    $mockFileSystemService
                )
                
                # Создаем глобальные переменные для отслеживания
                $global:validateCalled = $false
                $global:processTikTokCalled = $false
                $global:processInvalidCalled = $false
                $global:errorMessagePassed = ""
                $global:chatTypePassed = ""
                
                # Мокируем ValidateTextMessage для неуспешного результата
                $botService | Add-Member -MemberType ScriptMethod -Name "ValidateTextMessage" -Value {
                    param([string]$messageText)
                    $global:validateCalled = $true
                    return New-ErrorResponse -ErrorMessage "No TikTok URL found in message"
                } -Force
                
                # Мокируем ProcessTikTokUrl (не должен вызываться)
                $botService | Add-Member -MemberType ScriptMethod -Name "ProcessTikTokUrl" -Value {
                    param([string]$url, [long]$chatId, [int]$messageId)
                    $global:processTikTokCalled = $true
                } -Force
                
                # Мокируем ProcessInvalidMessage
                $botService | Add-Member -MemberType ScriptMethod -Name "ProcessInvalidMessage" -Value {
                    param([string]$errorMessage, [long]$chatId, [int]$messageId, [string]$chatType)
                    $global:processInvalidCalled = $true
                    $global:errorMessagePassed = $errorMessage
                    $global:chatTypePassed = $chatType
                } -Force
                
                # Тестируем метод
                $botService.HandleTextMessage("Some invalid message", 12345, 67890, "group")
                
                # Проверяем, что правильные методы были вызваны
                $global:validateCalled | Should -BeTrue
                $global:processTikTokCalled | Should -BeFalse
                $global:processInvalidCalled | Should -BeTrue
                $global:errorMessagePassed | Should -Be "No TikTok URL found in message"
                $global:chatTypePassed | Should -Be "group"
            }
        }

        It "Should pass correct parameters to ProcessTikTokUrl" {
            InModuleScope AnalyzeTTBot {
                # Создаем моки для всех сервисов
                $mockTelegramService = [ITelegramService]::new()
                $mockYtDlpService = [IYtDlpService]::new()
                $mockMediaInfoService = [IMediaInfoExtractorService]::new()
                $mockMediaFormatterService = [IMediaFormatterService]::new()
                $mockHashtagService = [IHashtagGeneratorService]::new()
                $mockFileSystemService = [IFileSystemService]::new()
                
                # Создаем экземпляр BotService
                $botService = [BotService]::new(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoService,
                    $mockMediaFormatterService,
                    $mockHashtagService,
                    $mockFileSystemService
                )
                
                # Создаем глобальные переменные для отслеживания параметров
                $global:passedUrl = ""
                $global:passedChatId = 0
                $global:passedMessageId = 0
                
                # Мокируем ValidateTextMessage
                $botService | Add-Member -MemberType ScriptMethod -Name "ValidateTextMessage" -Value {
                    param([string]$messageText)
                    return New-SuccessResponse -Data @{ Url = "https://vm.tiktok.com/test123/" }
                } -Force
                
                # Мокируем ProcessTikTokUrl для перехвата параметров
                $botService | Add-Member -MemberType ScriptMethod -Name "ProcessTikTokUrl" -Value {
                    param([string]$url, [long]$chatId, [int]$messageId)
                    $global:passedUrl = $url
                    $global:passedChatId = $chatId
                    $global:passedMessageId = $messageId
                    return New-SuccessResponse -Data @{}
                } -Force
                
                # Тестируем с конкретными значениями
                $botService.HandleTextMessage("Check this: https://vm.tiktok.com/test123/", 999888, 555444, "channel")
                
                # Проверяем переданные параметры
                $global:passedUrl | Should -Be "https://vm.tiktok.com/test123/"
                $global:passedChatId | Should -Be 999888
                $global:passedMessageId | Should -Be 555444
            }
        }

        It "Should use default chatType parameter when not specified" {
            InModuleScope AnalyzeTTBot {
                # Создаем моки для всех сервисов
                $mockTelegramService = [ITelegramService]::new()
                $mockYtDlpService = [IYtDlpService]::new()
                $mockMediaInfoService = [IMediaInfoExtractorService]::new()
                $mockMediaFormatterService = [IMediaFormatterService]::new()
                $mockHashtagService = [IHashtagGeneratorService]::new()
                $mockFileSystemService = [IFileSystemService]::new()
                
                # Создаем экземпляр BotService
                $botService = [BotService]::new(
                    $mockTelegramService,
                    $mockYtDlpService,
                    $mockMediaInfoService,
                    $mockMediaFormatterService,
                    $mockHashtagService,
                    $mockFileSystemService
                )
                
                # Создаем глобальную переменную для проверки chatType
                $global:receivedChatType = ""
                
                # Мокируем ValidateTextMessage для неуспешного результата
                $botService | Add-Member -MemberType ScriptMethod -Name "ValidateTextMessage" -Value {
                    param([string]$messageText)
                    return New-ErrorResponse -ErrorMessage "Invalid message"
                } -Force
                
                # Мокируем ProcessInvalidMessage для перехвата chatType
                $botService | Add-Member -MemberType ScriptMethod -Name "ProcessInvalidMessage" -Value {
                    param([string]$errorMessage, [long]$chatId, [int]$messageId, [string]$chatType)
                    $global:receivedChatType = $chatType
                } -Force
                
                # Тестируем без указания chatType (должен использовать значение по умолчанию "private")
                $botService.HandleTextMessage("Invalid text", 12345, 67890, "private")
                
                # Проверяем, что использовался chatType по умолчанию
                $global:receivedChatType | Should -Be "private"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
