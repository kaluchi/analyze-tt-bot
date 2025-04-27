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
                return @{ Success = $true; Data = @{ result = @{ message_id = 123 } } }
            } -Force
            
            # Создаем экземпляр BotService
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            
            # Мокируем конфигурацию
            Mock Get-PSFConfigValue { 
                param($FullName)
                switch ($FullName) {
                    "AnalyzeTTBot.Messages.InvalidLink" { return "Ошибка: неизвестная команда" }
                    default { return "stub" }
                }
            } -ModuleName AnalyzeTTBot
            
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Напрямую вызываем HandleMenuCommand для неизвестной команды
            $botService.HandleMenuCommand("/unknown", 123, 456)
            
            # Проверяем, что сообщение об ошибке было отправлено
            $mockTelegramService.SentMessages.Count | Should -BeGreaterThan 0
            
            # Должно быть сообщение о неизвестной команде
            $commandMessage = $mockTelegramService.SentMessages | Where-Object { 
                $_.Text -match 'неизвестная команда' -or 
                $_.Text -match 'unknown command' 
            }
            $commandMessage | Should -Not -BeNullOrEmpty
        }
    }
}