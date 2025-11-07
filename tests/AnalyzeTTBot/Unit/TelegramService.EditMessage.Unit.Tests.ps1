#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода EditMessage сервиса TelegramService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода EditMessage сервиса TelegramService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "TelegramService.EditMessage Tests" {
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
        $script:testChatId = 123456789
        $script:testMessageId = 987654321
        $script:testText = "Test message text"
        
        # Вспомогательная функция для проверки структуры ответа
        function global:Assert-ResponseStructure {
            param($Response)
            $Response.Keys | Should -Contain 'Success'
            $Response.Keys | Should -Contain 'Data'
            if ($Response.ContainsKey('timestamp')) {
                $Response.timestamp | Should -Not -BeNullOrEmpty
            }
            $Response.GetType().Name | Should -Be 'Hashtable'
        }
    }

    Context "Edit message functionality" {
        It "Should format and edit message correctly" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-CurlMethod
                Mock Invoke-CurlMethod {
                    return @{
                        ok = $true
                        result = @{
                            message_id = $script:testMessageId
                            chat = @{
                                id = $script:testChatId
                            }
                            text = $script:testText
                        }
                    }
                } -ModuleName AnalyzeTTBot
                
                # Мокируем Get-PSFConfigValue
                Mock Get-PSFConfigValue { return "⚠️ Файл слишком большой для отправки через Telegram ({0} МБ)." } -ModuleName AnalyzeTTBot
                
                # Создаем сервис и вызываем метод
                $telegramService = [TelegramService]::new($script:testToken, $script:testMaxFileSizeMB)
                $result = $telegramService.EditMessage($script:testChatId, $script:testMessageId, $script:testText, $null)
                
                # Проверяем, что Invoke-CurlMethod был вызван с правильными параметрами
                Should -Invoke Invoke-CurlMethod -Times 1 -Exactly -ModuleName AnalyzeTTBot -ParameterFilter {
                    $Uri -like "*editMessageText" -and
                    $Method -eq "Post" -and
                    $Body -match $script:testText -and
                    $Body -match $script:testMessageId
                }
                
                # Проверяем структуру ответа
                Assert-ResponseStructure -Response $result
                
                # Проверяем результат в новом формате
                $result.Success | Should -BeTrue
                # Добавляем проверку наличия ключа result и message_id
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.result | Should -Not -BeNullOrEmpty
                $result.Data.result.message_id | Should -Be $script:testMessageId
            }
        }
            
        It "Should handle message not modified error gracefully" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-CurlMethod для имитации ошибки "message is not modified"
                Mock Invoke-CurlMethod {
                    # curl возвращает JSON с ошибкой и парсит его
                    # Имитируем ответ Telegram API с ошибкой "message is not modified"
                    throw "Invoke-CurlMethod failed: curl failed with exit code 1: {`"ok`":false,`"error_code`":400,`"description`":`"Bad Request: message is not modified`"}"
                } -ModuleName AnalyzeTTBot
                
                # Мокируем Get-PSFConfigValue
                Mock Get-PSFConfigValue { return "⚠️ Файл слишком большой для отправки через Telegram ({0} МБ)." } -ModuleName AnalyzeTTBot
                
                # Создаем сервис и вызываем метод
                $telegramService = [TelegramService]::new($script:testToken, $script:testMaxFileSizeMB)
                $result = $telegramService.EditMessage($script:testChatId, $script:testMessageId, $script:testText, $null)
                
                # Проверяем структуру ответа
                Assert-ResponseStructure -Response $result
                
                # По дизайну сервиса, эта ошибка обрабатывается как успешный результат!
                $result.Success | Should -BeTrue
                $result.Data.result.message_id | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}