Describe 'BotService.Start.HandleUnknownCommand method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Обрабатывает неизвестную команду и отправляет сообщение об ошибке' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                $this.SentMessages.Add(@{ ChatId = $chatId; Text = $text; ReplyToMessageId = $replyToMessageId; ParseMode = $parseMode })
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value {
                param($offset, $timeout)
                return @{ Success = $true; Data = @(
                    @{ update_id = 1; message = @{ chat = @{ id = 1 }; message_id = 10; text = "/unknown" } }
                ) }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            Mock Get-PSFConfigValue { return "Ошибка: неизвестная команда" } -ModuleName AnalyzeTTBot
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Start-Sleep { } -ModuleName AnalyzeTTBot
            $botService.Start($true)
            $mockTelegramService.SentMessages | Where-Object { $_.Text -match 'неизвестная команда' } | Should -Not -BeNullOrEmpty
        }
    }
}
