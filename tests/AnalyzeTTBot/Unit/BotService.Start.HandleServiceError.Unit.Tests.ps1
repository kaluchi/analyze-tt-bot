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
    It 'Обрабатывает ошибку в сервисе через ProcessTikTokUrl' {
        InModuleScope AnalyzeTTBot {
            # Этот тест проверяет работу ProcessTikTokUrl напрямую
            
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
            
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                param($chatId, $messageId, $text, $parseMode)
                $this.SentMessages.Add(@{ 
                    ChatId = $chatId
                    Text = $text
                    MessageId = $messageId
                    ParseMode = $parseMode 
                })
                return @{ Success = $true }
            } -Force
            
            # Создаем мок YtDlpService, который возвращает ошибку
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                param($url, $outputPath)
                return @{ 
                    Success = $false 
                    Error = 'Ошибка сервиса YtDlp: Не удалось скачать видео'
                    Data = @{
                        RawOutput = @("ERROR: Unable to download video")
                    }
                }
            } -Force
            
            # Другие моки
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockFileSystemService = [IFileSystemService]::new()
            
            # Создаем экземпляр BotService
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            
            # Мокируем конфигурацию и логирование
            Mock Get-PSFConfigValue { 
                param($FullName)
                switch ($FullName) {
                    "AnalyzeTTBot.Messages.Processing" { return "Обработка видео..." }
                    "AnalyzeTTBot.Messages.Downloading" { return "Скачивание видео..." }
                    "AnalyzeTTBot.Messages.Analyzing" { return "Анализ видео..." }
                    default { return "stub" }
                }
            } -ModuleName AnalyzeTTBot
            
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Вызываем ProcessTikTokUrl напрямую, проверяя обработку ошибки
            $result = $botService.ProcessTikTokUrl("https://tiktok.com/video/12345", 123, 456)
            
            # Проверяем, что метод вернул ошибку
            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
            
            # Проверяем, что были отправлены сообщения
            $processMessages = $mockTelegramService.SentMessages | Select-Object Text
            
            # Должно быть как минимум два сообщения: первоначальное и сообщение об ошибке
            $processMessages.Count | Should -BeGreaterThan 1
            
            # Должно быть сообщение об ошибке
            $errorMessages = $mockTelegramService.SentMessages | Where-Object { 
                $_.Text -match 'Error' -or 
                $_.Text -match '❌'
            }
            $errorMessages | Should -Not -BeNullOrEmpty
        }
    }
}