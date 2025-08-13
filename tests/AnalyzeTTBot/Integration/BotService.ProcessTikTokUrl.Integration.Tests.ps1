#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Интеграционные тесты для метода ProcessTikTokUrl в BotService.
.DESCRIPTION
    Проверяет полный цикл обработки TikTok URL с использованием реальных сервисов
    за исключением TelegramService, который мокается для тестирования.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "BotService.ProcessTikTokUrl Integration Tests" {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
        
        # Создаем тестовую конфигурацию
        $ytDlpPath = (Get-Command yt-dlp -ErrorAction SilentlyContinue).Source
        if (-not $ytDlpPath) {
            throw "yt-dlp не найден в системе"
        }
        
        $config = @{
            YtDlpPath = $ytDlpPath
            DownloadTimeout = 60
            DefaultFormat = "best"
            ValidTikTokUrl = "https://www.tiktok.com/@yakinattyy_/video/7492429481462746384?_t=ZM-8vjNmHDakoX&_r=1"
            expectedAuthorUsername = "yakinattyy_"
            expectedVideoTitle = "тгк:яника"
            expectedFullVideoUrl = "https://www.tiktok.com/@yakinattyy_/video/7492429481462746384?_t=ZM-8vjNmHDakoX&_r=1"
        }
        
        # Создаем временную директорию для тестов
        $script:TestTempPath = Join-Path $env:TEMP "BotServiceProcessTikTokUrlIntegrationTests_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $script:TestTempPath -ItemType Directory -Force | Out-Null
        
        # Конфигурация будет доступна для InModuleScope
        $script:Config = $config
    }
    
    Context "ProcessTikTokUrl with real TikTok video" {
        It "Should successfully process valid TikTok URL and generate expected report" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                # Создаем mock для TelegramService
                $mockTelegramService = [ITelegramService]::new()
                $script:telegramCalls = @()
                
                $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                    param($chatId, $text, $replyToMessageId, $parseMode)
                    $script:telegramCalls += [PSCustomObject]@{
                        Method = "SendMessage"
                        ChatId = $chatId
                        Text = $text
                        ReplyToMessageId = $replyToMessageId
                        ParseMode = $parseMode
                    }
                    return @{ 
                        Success = $true; 
                        Data = @{ result = @{ message_id = 123 } } 
                    }
                } -Force
                
                $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value {
                    param($chatId, $messageId, $text, $parseMode)
                    $script:telegramCalls += [PSCustomObject]@{
                        Method = "EditMessage"
                        ChatId = $chatId
                        MessageId = $messageId
                        Text = $text
                        ParseMode = $parseMode
                    }
                    return @{ Success = $true }
                } -Force
                
                $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value {
                    param($chatId, $filePath, $caption, $replyToMessageId)
                    $script:telegramCalls += [PSCustomObject]@{
                        Method = "SendFile"
                        ChatId = $chatId
                        FilePath = $filePath
                        Caption = $caption
                        ReplyToMessageId = $replyToMessageId
                    }
                    return @{ Success = $true }
                } -Force
                
                # Создаем реальные сервисы
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat,
                    ""  # cookiesPath - пустая строка для интеграционного теста
                )
                $mediaInfoExtractorService = [MediaInfoExtractorService]::new($fileSystemService)
                $mediaFormatterService = [MediaFormatterService]::new()
                $hashtagGeneratorService = [HashtagGeneratorService]::new()
                
                # Создаем BotService с реальными сервисами и замоканным TelegramService
                $botService = [BotService]::new(
                    $mockTelegramService,
                    $ytDlpService,
                    $mediaInfoExtractorService,
                    $mediaFormatterService,
                    $hashtagGeneratorService,
                    $fileSystemService
                )
                
                $chatId = 12345
                $messageId = 67890
                
                # Выполняем тестируемый метод
                $result = $botService.ProcessTikTokUrl($Config.ValidTikTokUrl, $chatId, $messageId)
                
                # Добавляем отладочную информацию
                if (-not $result.Success) {
                    Write-Host "Test failed: $($result.Error)" -ForegroundColor Red
                    Write-Host "Result object:" -ForegroundColor Yellow
                    Write-Host ($result | ConvertTo-Json -Depth 5) -ForegroundColor Yellow
                }
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.Report | Should -Not -BeNullOrEmpty
                $result.Data.FileSent | Should -BeTrue
                
                # Проверяем, что все необходимые вызовы Telegram API были выполнены
                $script:telegramCalls.Count | Should -BeGreaterThan 3
                
                # Проверяем отправку начального сообщения
                $sendMessageCalls = $script:telegramCalls | Where-Object { $_.Method -eq "SendMessage" }
                $sendMessageCalls.Count | Should -BeGreaterThan 0
                
                # Проверяем редактирование сообщений (должно быть несколько изменений статуса)
                $editMessageCalls = $script:telegramCalls | Where-Object { $_.Method -eq "EditMessage" }
                $editMessageCalls.Count | Should -BeGreaterThan 2
                
                # Проверяем отправку файла
                $sendFileCalls = $script:telegramCalls | Where-Object { $_.Method -eq "SendFile" }
                $sendFileCalls.Count | Should -Be 1
                $sendFileCalls[0].FilePath | Should -Match "\.mp4$"
                
                # Проверяем формат отчета и наличие ожидаемых данных
                $result.Data.Report | Should -Match "🔗 Link: "
                $result.Data.Report | Should -Match $Config.expectedAuthorUsername
                $result.Data.Report | Should -Match "🎬 VIDEO"
                $result.Data.Report | Should -Match "🔊 AUDIO"
                $result.Data.Report | Should -Match "1080 x 1920"  # Ожидаемое разрешение
                $result.Data.Report | Should -Match "FPS: 30"    # Ожидаемый FPS
                $result.Data.Report | Should -Match "HEVC"      # Ожидаемый видео кодек
                $result.Data.Report | Should -Match "AAC"       # Ожидаемый аудио кодек
                $result.Data.Report | Should -Match "44\.1 kHz" # Ожидаемая частота дискретизации
            }
        }
    }
    
    AfterAll {
        # Очистка временных файлов
        if ($script:TestTempPath -and (Test-Path $script:TestTempPath)) {
            Remove-Item -Path $script:TestTempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
