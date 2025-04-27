#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ProcessInvalidMessage в BotService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ProcessInvalidMessage сервиса BotService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'BotService.ProcessInvalidMessage method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Должен отправлять сообщение об ошибке через TelegramService' {
        InModuleScope AnalyzeTTBot {
            # Mock Write-PSFMessage для проверки логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            # Mock Get-PSFConfigValue для получения сообщения об ошибке
            Mock Get-PSFConfigValue { 
                param($FullName)
                if ($FullName -eq "AnalyzeTTBot.Messages.InvalidLink") {
                    return "❌ Пожалуйста, отправьте корректную ссылку на TikTok."
                }
                return $null
            } -ModuleName AnalyzeTTBot
            
            # Создаем мок TelegramService
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{ 
                    ChatId = $chatId
                    Text = $text
                    ReplyToMessageId = $replyToMessageId
                    ParseMode = $parseMode 
                })
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            
            # Создаем экземпляр BotService с мок-зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            
            # Параметры теста
            $errorMessage = "URL не является ссылкой на TikTok"
            $chatId = 123456789
            $messageId = 987654321
            
            # Вызываем тестируемый метод
            $botService.ProcessInvalidMessage($errorMessage, $chatId, $messageId, "private")
            
            # Проверяем, что сообщение было отправлено
            $mockTelegramService.SentMessages.Count | Should -Be 1
            $sentMessage = $mockTelegramService.SentMessages[0]
            
            $sentMessage.ChatId | Should -Be $chatId
            $sentMessage.Text | Should -Be "❌ Пожалуйста, отправьте корректную ссылку на TikTok."
            $sentMessage.ReplyToMessageId | Should -Be $messageId
            $sentMessage.ParseMode | Should -Be "HTML"
            
            # Проверяем, что было вызвано логирование
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Verbose' -and $FunctionName -eq 'BotService.ProcessInvalidMessage'
            }
        }
    }
    
    It 'Должен корректно обрабатывать пустое сообщение об ошибке' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Get-PSFConfigValue { 
                param($FullName)
                if ($FullName -eq "AnalyzeTTBot.Messages.InvalidLink") {
                    return "❌ Пожалуйста, отправьте корректную ссылку на TikTok."
                }
                return $null
            } -ModuleName AnalyzeTTBot
            
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{ 
                    ChatId = $chatId
                    Text = $text
                    ReplyToMessageId = $replyToMessageId
                    ParseMode = $parseMode 
                })
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            
            # Параметры теста с пустым сообщением об ошибке
            $errorMessage = ""
            $chatId = 123456789
            $messageId = 987654321
            
            $botService.ProcessInvalidMessage($errorMessage, $chatId, $messageId, "private")
            
            # Проверяем, что сообщение было отправлено
            $mockTelegramService.SentMessages.Count | Should -Be 1
            $sentMessage = $mockTelegramService.SentMessages[0]
            
            $sentMessage.ChatId | Should -Be $chatId
            $sentMessage.Text | Should -Be "❌ Пожалуйста, отправьте корректную ссылку на TikTok."
            $sentMessage.ReplyToMessageId | Should -Be $messageId
            $sentMessage.ParseMode | Should -Be "HTML"
            
            # Проверяем, что было вызвано логирование с пустым сообщением об ошибке
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Verbose' -and 
                $FunctionName -eq 'BotService.ProcessInvalidMessage' -and
                $Message -match "Error: $"
            }
        }
    }
    
    It 'Должен использовать сообщение по умолчанию, если конфигурация отсутствует' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            # Mock Get-PSFConfigValue возвращает null для отсутствующей конфигурации
            Mock Get-PSFConfigValue { return $null } -ModuleName AnalyzeTTBot
            
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{ 
                    ChatId = $chatId
                    Text = $text
                    ReplyToMessageId = $replyToMessageId
                    ParseMode = $parseMode 
                })
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            
            $errorMessage = "Некорректный формат URL"
            $chatId = 123456789
            $messageId = 987654321
            
            $botService.ProcessInvalidMessage($errorMessage, $chatId, $messageId, "private")
            
            # Проверяем, что сообщение было отправлено с null текстом
            $mockTelegramService.SentMessages.Count | Should -Be 1
            $sentMessage = $mockTelegramService.SentMessages[0]
            
            $sentMessage.ChatId | Should -Be $chatId
            $sentMessage.Text | Should -BeNullOrEmpty
            $sentMessage.ReplyToMessageId | Should -Be $messageId
            $sentMessage.ParseMode | Should -Be "HTML"
        }
    }
    
    It 'Должен логировать сообщение об ошибке в сообщении' {
        InModuleScope AnalyzeTTBot {
            $loggedMessages = @()
            Mock Write-PSFMessage { 
                param($Message)
                $loggedMessages += $Message
            } -ModuleName AnalyzeTTBot
            
            Mock Get-PSFConfigValue { 
                param($FullName)
                if ($FullName -eq "AnalyzeTTBot.Messages.InvalidLink") {
                    return "❌ Пожалуйста, отправьте корректную ссылку на TikTok."
                }
                return $null
            } -ModuleName AnalyzeTTBot
            
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            
            $errorMessage = "Специальное сообщение об ошибке для теста"
            $chatId = 123456789
            $messageId = 987654321
            
            $botService.ProcessInvalidMessage($errorMessage, $chatId, $messageId, "private")
            
            # Проверяем, что в лог-сообщении содержится переданное сообщение об ошибке
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Message -match "Error: $errorMessage"
            }
        }
    }
}
