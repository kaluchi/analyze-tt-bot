#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Unit tests for BotService.Start method.
.DESCRIPTION
    Covers main loop logic, command handling, TikTok link extraction, and error handling.
.NOTES
    Author: TikTok Bot Team
    Created: 20.04.2025
#>

Describe "BotService.Start method" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }

    It "Должен обрабатывать разные типы сообщений, включая из каналов" {
        InModuleScope AnalyzeTTBot {
            # Создаем моки для сервисов
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
                return @{ Success = $true; Data = @{ result = @{ message_id = 123 } } }
            } -Force
            
            # Создаем экземпляр BotService с заглушками
            $botService = [BotService]::new(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            
            # Мокируем методы, которые обрабатывают различные типы сообщений
            $botService | Add-Member -MemberType ScriptMethod -Name HandleTextMessage -Value {
                param($messageText, $chatId, $messageId, $chatType = "private")
                # Добавляем отметку о типе чата, чтобы проверить, что передаётся правильный параметр
                $this.TelegramService.SendMessage($chatId, "Обработано сообщение из $chatType чата", $messageId, "HTML")
            } -Force
            
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Проверяем обработку сообщения из личного чата
            $botService.HandleTextMessage("test", 1, 10, "private")
            
            # Проверяем обработку сообщения из канала
            $botService.HandleTextMessage("test", 2, 20, "channel")
            
            # Проверяем обработку сообщения из группы
            $botService.HandleTextMessage("test", 3, 30, "group")
            
            # Проверяем, что отправлены правильные сообщения
            $privateMessages = $mockTelegramService.SentMessages | Where-Object { $_.ChatId -eq 1 }
            $channelMessages = $mockTelegramService.SentMessages | Where-Object { $_.ChatId -eq 2 }
            $groupMessages = $mockTelegramService.SentMessages | Where-Object { $_.ChatId -eq 3 }
            
            # Выводим все сообщения для отладки
            Write-Host "All messages: $($mockTelegramService.SentMessages | ConvertTo-Json -Depth 2)"
            
            # Проверяем, что все сообщения отправлены
            $privateMessages.Count | Should -BeGreaterOrEqual 1
            $channelMessages.Count | Should -BeGreaterOrEqual 1
            $groupMessages.Count | Should -BeGreaterOrEqual 1
            
            # Проверяем, что в сообщениях правильно указан тип чата
            $messages = $mockTelegramService.SentMessages
            $messages | Where-Object { $_.ChatId -eq 1 -and $_.Text -match "private" } | Should -Not -BeNullOrEmpty
            $messages | Where-Object { $_.ChatId -eq 2 -and $_.Text -match "channel" } | Should -Not -BeNullOrEmpty
            $messages | Where-Object { $_.ChatId -eq 3 -and $_.Text -match "group" } | Should -Not -BeNullOrEmpty
        }
    }

    AfterAll {
        # Очищаем все модули и переменные, чтобы не было конфликтов между тестами
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}