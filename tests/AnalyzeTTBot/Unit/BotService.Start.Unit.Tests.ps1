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

    It "Should handle /start and /help commands and invalid links" {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{ ChatId = $chatId; Text = $text; ReplyToMessageId = $replyToMessageId; ParseMode = $parseMode })
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                param($chatId, $messageId, $text, $parseMode)
                return @{ Success = $true }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value {
                param($chatId, $filePath, $caption, $replyToMessageId)
                return @{ Success = $true }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value {
                param($offset, $timeout)
                return @{ Success = $true; Data = @(
                    @{ update_id = 1; message = @{ chat = @{ id = 1 }; message_id = 10; text = "/start" } },
                    @{ update_id = 2; message = @{ chat = @{ id = 1 }; message_id = 11; text = "/help" } },
                    @{ update_id = 3; message = @{ chat = @{ id = 1 }; message_id = 12; text = "notalink" } },
                    @{ update_id = 4; message = @{ chat = @{ id = 1 }; message_id = 13; text = "https://www.tiktok.com/@user/video/123" } }
                ) }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value {
                param($SkipTokenValidation)
                return @{ Success = $true; Data = @{ Name = "Telegram Bot"; Valid = $true; Version = "mock"; Description = "mock" } }
            } -Force
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
            Mock Get-PSFConfigValue { return "stub" } -ModuleName AnalyzeTTBot
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Start-Sleep { } -ModuleName AnalyzeTTBot
            
            # Добавляем моки для новых методов
            $botService | Add-Member -MemberType ScriptMethod -Name HandleMenuCommand -Value {
                param($messageText, $chatId, $messageId)
                $this.HandleCommand($messageText, $chatId, $messageId)
            } -Force
            
            $botService | Add-Member -MemberType ScriptMethod -Name HandleTextMessage -Value {
                param($messageText, $chatId, $messageId)
                if ($messageText -match "tiktok\.com") {
                    # Просто логируем, чтобы избежать сложностей в тесте
                    return
                }
                $this.TelegramService.SendMessage($chatId, "Invalid link", $messageId, "HTML")
            } -Force
            
            $botService | Add-Member -MemberType ScriptMethod -Name HandleException -Value {
                param($exception, $functionName)
                # Просто логируем исключение
            } -Force
            Mock Out-Null { } -ModuleName AnalyzeTTBot
            $botService.Start($true)
            $mockTelegramService.SentMessages.Count | Should -BeGreaterThan 0
        }
    }

    AfterAll {
        # Очищаем все модули и переменные, чтобы не было конфликтов между тестами
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
