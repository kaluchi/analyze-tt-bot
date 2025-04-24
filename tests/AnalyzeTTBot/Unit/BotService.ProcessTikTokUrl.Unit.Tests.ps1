Describe 'BotService.ProcessTikTokUrl method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Успешно обрабатывает валидный TikTok URL даже при ошибке форматирования отчета' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
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
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name GetMediaInfo -Value {
                param($filePath)
                return  @{ Success = $true; }
            } -Force
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockMediaFormatterService | Add-Member -MemberType ScriptMethod -Name FormatMediaInfo -Value {
                return @{ Success = $false; Error = "Ошибка форматирования видео"  }
            } -Force
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockHashtagGeneratorService | Add-Member -MemberType ScriptMethod -Name GetVideoHashtags -Value {
                return @{ Success = $true }
            } -Force
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name FileExists -Value {
                param($path)
                return $true
            } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFileName -Value {
                return "tempfile.tmp"
            } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name WriteAllBytes -Value {
                param($path, $bytes)
                return $true
            } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name ReadAllBytes -Value {
                param($path)
                return [System.Text.Encoding]::UTF8.GetBytes("test video content")
            } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $true }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            $url = "https://www.tiktok.com/@user/video/1234567890"
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeTrue
            $result.Data.Report | Should -Not -BeNullOrEmpty
            $result.Data.FileSent | Should -BeTrue
        }
    }
    It 'Возвращает ошибку при пустом URL' {
        InModuleScope AnalyzeTTBot {
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
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $null, $null, $null, $null, $null
            )
            $url = ""
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeFalse
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }
    It 'Возвращает ошибку, если не удалось отправить стартовое сообщение' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $false; Error = 'Ошибка отправки' }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                param($chatId, $messageId, $text, $parseMode)
                return @{ Success = $true }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value {
                param($chatId, $filePath, $caption, $replyToMessageId)
                return @{ Success = $true }
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name GetMediaInfo -Value {
                param($filePath)
                return  @{ Success = $true; }
            } -Force
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockMediaFormatterService | Add-Member -MemberType ScriptMethod -Name FormatMediaInfo -Value {
                return @{ Success = $true; Data = 'Отчет' }
            } -Force
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockHashtagGeneratorService | Add-Member -MemberType ScriptMethod -Name GetVideoHashtags -Value {
                return @{ Success = $true }
            } -Force
            $mockFileSystemService = [IFileSystemService]::new()
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $true; Data = @{ FilePath = 'file.mp4'; AuthorUsername = 'user'; FullVideoUrl = 'url' } }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            $url = 'https://www.tiktok.com/@user/video/1234567890'
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Ошибка отправки'
        }
    }
    It 'Возвращает ошибку, если не удалось скачать видео' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
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
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name GetMediaInfo -Value {
                param($filePath)
                return  @{ Success = $true; }
            } -Force
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockMediaFormatterService | Add-Member -MemberType ScriptMethod -Name FormatMediaInfo -Value {
                return @{ Success = $true; Data = 'Отчет' }
            } -Force
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockHashtagGeneratorService | Add-Member -MemberType ScriptMethod -Name GetVideoHashtags -Value {
                return @{ Success = $true }
            } -Force
            $mockFileSystemService = [IFileSystemService]::new()
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $false; Error = 'Ошибка скачивания' }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            $url = 'https://www.tiktok.com/@user/video/1234567890'
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Ошибка скачивания'
        }
    }
    It 'Возвращает ошибку, если не удалось проанализировать видео' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
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
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name GetMediaInfo -Value {
                param($filePath)
                return  @{ Success = $false; Error = 'Ошибка анализа' }
            } -Force
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockMediaFormatterService | Add-Member -MemberType ScriptMethod -Name FormatMediaInfo -Value {
                return @{ Success = $true; Data = 'Отчет' }
            } -Force
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockHashtagGeneratorService | Add-Member -MemberType ScriptMethod -Name GetVideoHashtags -Value {
                return @{ Success = $true }
            } -Force
            $mockFileSystemService = [IFileSystemService]::new()
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $true; Data = @{ FilePath = 'file.mp4'; AuthorUsername = 'user'; FullVideoUrl = 'url' } }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            $url = 'https://www.tiktok.com/@user/video/1234567890'
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Ошибка анализа'
        }
    }
    It 'Обрабатывает ошибку при отправке файла (исключение)' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                param($chatId, $messageId, $text, $parseMode)
                return @{ Success = $true }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value {
                param($chatId, $filePath, $caption, $replyToMessageId)
                throw 'Ошибка отправки файла'
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name GetMediaInfo -Value {
                param($filePath)
                return  @{ Success = $true; }
            } -Force
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockMediaFormatterService | Add-Member -MemberType ScriptMethod -Name FormatMediaInfo -Value {
                return @{ Success = $true; Data = 'Отчет' }
            } -Force
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockHashtagGeneratorService | Add-Member -MemberType ScriptMethod -Name GetVideoHashtags -Value {
                return @{ Success = $true }
            } -Force
            $mockFileSystemService = [IFileSystemService]::new()
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $true; Data = @{ FilePath = 'file.mp4'; AuthorUsername = 'user'; FullVideoUrl = 'url' } }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            $url = 'https://www.tiktok.com/@user/video/1234567890'
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeTrue
            $result.Data.FileSent | Should -BeFalse
            $result.Data.Report | Should -Not -BeNullOrEmpty
        }
    }
    It 'Продолжает выполнение при ошибке редактирования сообщения' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $true; Data = @{ result = @{ message_id = $replyToMessageId } } }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                param($chatId, $messageId, $text, $parseMode)
                return @{ Success = $false; Error = 'Ошибка редактирования' }
            } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value {
                param($chatId, $filePath, $caption, $replyToMessageId)
                return @{ Success = $true }
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name GetMediaInfo -Value {
                param($filePath)
                return  @{ Success = $true; }
            } -Force
            $mockMediaFormatterService = [IMediaFormatterService]::new()
            $mockMediaFormatterService | Add-Member -MemberType ScriptMethod -Name FormatMediaInfo -Value {
                return @{ Success = $true; Data = 'Отчет' }
            } -Force
            $mockHashtagGeneratorService = [IHashtagGeneratorService]::new()
            $mockHashtagGeneratorService | Add-Member -MemberType ScriptMethod -Name GetVideoHashtags -Value {
                return @{ Success = $true }
            } -Force
            $mockFileSystemService = [IFileSystemService]::new()
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name SaveTikTokVideo -Value {
                return @{ Success = $true; Data = @{ FilePath = 'file.mp4'; AuthorUsername = 'user'; FullVideoUrl = 'url' } }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $mockMediaFormatterService,
                $mockHashtagGeneratorService,
                $mockFileSystemService
            )
            $url = 'https://www.tiktok.com/@user/video/1234567890'
            $chatId = 123456789
            $messageId = 987654321
            $result = $botService.ProcessTikTokUrl($url, $chatId, $messageId)
            $result.Success | Should -BeTrue
            $result.Data.Report | Should -Not -BeNullOrEmpty
        }
    }
}

