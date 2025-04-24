Describe 'BotService.Start.HandleServiceError method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Обрабатывает ошибку в сервисе и отправляет сообщение об ошибке пользователю' {
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
                    @{ update_id = 1; message = @{ chat = @{ id = 1 }; message_id = 10; text = "https://www.tiktok.com/@user/video/123" } }
                ) }
            } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $false; Error = 'Ошибка сервиса YtDlp' }
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                param($chatId, $messageId, $text, $parseMode)
                $this.SentMessages.Add(@{ ChatId = $chatId; Text = $text; MessageId = $messageId; ParseMode = $parseMode })
                return @{ Success = $true; Data = @{ result = @{ message_id = $messageId } } }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $null
            )
            Mock Get-PSFConfigValue { return "stub" } -ModuleName AnalyzeTTBot
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Start-Sleep { } -ModuleName AnalyzeTTBot
            $botService.Start($true)
            $mockTelegramService.SentMessages | Where-Object { $_.Text -match 'Ошибка сервиса YtDlp' -or $_.Text -match 'Error downloading video' -or $_.Text -match 'Ошибка' -or $_.Text -match 'error' } | Should -Not -BeNullOrEmpty
        }
    }
}
