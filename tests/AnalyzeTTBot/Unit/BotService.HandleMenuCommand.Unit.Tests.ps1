#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода HandleMenuCommand в BotService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода HandleMenuCommand сервиса BotService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'BotService.HandleMenuCommand method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Корректно обрабатывает команду /start' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Создаем мок HandleCommand
            $mockBotService = [BotService]::new(
                $null, $null, $null, $null, $null, $null
            )
            
            # Заменяем метод HandleCommand моком
            $mockBotService | Add-Member -MemberType ScriptMethod -Name 'HandleCommand' -Value {
                param($command, $chatId, $messageId)
                $script:handledCommand = $command
                $script:handledChatId = $chatId
                $script:handledMessageId = $messageId
            } -Force
            
            # Тестовые параметры
            $messageText = "/start"
            $chatId = 123456789
            $messageId = 987654321
            
            # Вызываем тестируемый метод
            $mockBotService.HandleMenuCommand($messageText, $chatId, $messageId)
            
            # Проверяем, что HandleCommand был вызван с правильными параметрами
            $script:handledCommand | Should -Be "/start"
            $script:handledChatId | Should -Be $chatId
            $script:handledMessageId | Should -Be $messageId
            
            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Verbose' -and 
                $FunctionName -eq 'BotService.HandleMenuCommand' -and
                $Message -match "Handled /start command for chat $chatId"
            }
        }
    }

    It 'Корректно обрабатывает команду /help' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Создаем мок HandleCommand
            $mockBotService = [BotService]::new(
                $null, $null, $null, $null, $null, $null
            )
            
            # Заменяем метод HandleCommand моком
            $mockBotService | Add-Member -MemberType ScriptMethod -Name 'HandleCommand' -Value {
                param($command, $chatId, $messageId)
                $script:handledCommand = $command
                $script:handledChatId = $chatId
                $script:handledMessageId = $messageId
            } -Force
            
            # Тестовые параметры
            $messageText = "/help"
            $chatId = 123456789
            $messageId = 987654321
            
            # Вызываем тестируемый метод
            $mockBotService.HandleMenuCommand($messageText, $chatId, $messageId)
            
            # Проверяем, что HandleCommand был вызван с правильными параметрами
            $script:handledCommand | Should -Be "/help"
            $script:handledChatId | Should -Be $chatId
            $script:handledMessageId | Should -Be $messageId
            
            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Verbose' -and 
                $FunctionName -eq 'BotService.HandleMenuCommand' -and
                $Message -match "Handled /help command for chat $chatId"
            }
        }
    }

    It 'Отправляет сообщение об ошибке при неизвестной команде' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Mock для конфигурации
            Mock Get-PSFConfigValue { 
                param($FullName)
                if ($FullName -eq "AnalyzeTTBot.Messages.InvalidLink") {
                    return "❌ Неизвестная команда. Используйте /help для получения списка команд."
                }
                return $null
            } -ModuleName AnalyzeTTBot
            
            # Создаем мок TelegramService
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name "SentMessages" -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name "SendMessage" -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{
                    ChatId = $chatId
                    Text = $text
                    ReplyToMessageId = $replyToMessageId
                    ParseMode = $parseMode
                })
                return @{ Success = $true; Data = @{ result = @{ message_id = 1001 } } }
            } -Force
            
            # Создаем экземпляр BotService с мок-зависимостями
            $mockBotService = [BotService]::new(
                $mockTelegramService, $null, $null, $null, $null, $null
            )
            
            # Тестовые параметры
            $messageText = "/unknown_command"
            $chatId = 123456789
            $messageId = 987654321
            
            # Вызываем тестируемый метод
            $mockBotService.HandleMenuCommand($messageText, $chatId, $messageId)
            
            # Проверяем, что сообщение об ошибке было отправлено
            $mockTelegramService.SentMessages.Count | Should -Be 1
            $sentMessage = $mockTelegramService.SentMessages[0]
            
            $sentMessage.ChatId | Should -Be $chatId
            $sentMessage.Text | Should -Be "❌ Неизвестная команда. Используйте /help для получения списка команд."
            $sentMessage.ReplyToMessageId | Should -Be $messageId
            $sentMessage.ParseMode | Should -Be "HTML"
            
            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Warning' -and 
                $FunctionName -eq 'BotService.HandleMenuCommand' -and
                $Message -match "Unknown command: $messageText"
            }
        }
    }

    It 'Корректно обрабатывает случай с отсутствующей конфигурацией сообщения при неизвестной команде' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Mock для конфигурации, возвращающий null
            Mock Get-PSFConfigValue { return $null } -ModuleName AnalyzeTTBot
            
            # Создаем мок TelegramService
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name "SentMessages" -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name "SendMessage" -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{
                    ChatId = $chatId
                    Text = $text
                    ReplyToMessageId = $replyToMessageId
                    ParseMode = $parseMode
                })
                return @{ Success = $true; Data = @{ result = @{ message_id = 1002 } } }
            } -Force
            
            # Создаем экземпляр BotService с мок-зависимостями
            $mockBotService = [BotService]::new(
                $mockTelegramService, $null, $null, $null, $null, $null
            )
            
            # Тестовые параметры
            $messageText = "/another_unknown"
            $chatId = 123456789
            $messageId = 987654321
            
            # Вызываем тестируемый метод
            $mockBotService.HandleMenuCommand($messageText, $chatId, $messageId)
            
            # Проверяем, что сообщение об ошибке было отправлено с null текстом
            $mockTelegramService.SentMessages.Count | Should -Be 1
            $sentMessage = $mockTelegramService.SentMessages[0]
            
            $sentMessage.ChatId | Should -Be $chatId
            $sentMessage.Text | Should -BeNullOrEmpty
            $sentMessage.ReplyToMessageId | Should -Be $messageId
            $sentMessage.ParseMode | Should -Be "HTML"
            
            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Warning' -and 
                $FunctionName -eq 'BotService.HandleMenuCommand' -and
                $Message -match "Unknown command: $messageText"
            }
        }
    }
}