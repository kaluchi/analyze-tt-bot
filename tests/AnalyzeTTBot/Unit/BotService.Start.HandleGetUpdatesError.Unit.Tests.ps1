Describe 'BotService.Start.HandleGetUpdatesError method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Не отправляет сообщений, если GetUpdates возвращает ошибку' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{ ChatId = $chatId; Text = $text; ReplyToMessageId = $replyToMessageId; ParseMode = $parseMode })
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            $callCount = 0
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value {
                param($offset, $timeout)
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return @{ Success = $false; Error = 'Ошибка Telegram API' }
                } else {
                    return @{ Success = $true; Data = @() }
                }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            Mock Get-PSFConfigValue { return "stub" } -ModuleName AnalyzeTTBot
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Start-Sleep { } -ModuleName AnalyzeTTBot
            $botService.Start($true)
            $mockTelegramService.SentMessages.Count | Should -Be 0
        }
    }
}
