<#
.SYNOPSIS
    Основной сервис бота для анализа видео с TikTok.
.DESCRIPTION
    Предоставляет функциональность для запуска бота и обработки сообщений от пользователей.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>
class BotService : IBotService {
    [ITelegramService]$TelegramService
    [IYtDlpService]$YtDlpService
    [IMediaInfoExtractorService]$MediaInfoExtractorService
    [IMediaFormatterService]$MediaFormatterService
    [IHashtagGeneratorService]$HashtagGeneratorService
    [IFileSystemService]$FileSystemService
    
    BotService(
        [ITelegramService]$telegramService,
        [IYtDlpService]$ytDlpService,
        [IMediaInfoExtractorService]$mediaInfoExtractorService,
        [IMediaFormatterService]$mediaFormatterService,
        [IHashtagGeneratorService]$hashtagGeneratorService,
        [IFileSystemService]$fileSystemService
    ) {
        $this.TelegramService = $telegramService
        $this.YtDlpService = $ytDlpService
        $this.MediaInfoExtractorService = $mediaInfoExtractorService
        $this.MediaFormatterService = $mediaFormatterService
        $this.HashtagGeneratorService = $hashtagGeneratorService
        $this.FileSystemService = $fileSystemService
        
        Write-PSFMessage -Level Verbose -FunctionName "BotService.Constructor" -Message "BotService initialized"
    }
    
    [void] Start([switch]$Debug=$false) {
        Write-PSFMessage -Level Host -FunctionName "BotService.Start" -Message "Bot is running! Press Ctrl+C to stop." -Target $this
        
        $lastUpdateId = 0
        
        while ($true) {
            try {
                # Получаем обновления
                $updatesResponse = $this.TelegramService.GetUpdates($lastUpdateId, 30)
                
                if (-not $updatesResponse.Success) {
                    Write-PSFMessage -Level Warning -FunctionName "BotService.Start" -Message "Failed to get updates: $($updatesResponse.Error)"
                    Start-Sleep -Seconds 5
                    continue
                }
                
                $updates = $updatesResponse.Data
                if ($null -eq $updates) {
                    $updates = @() # Гарантируем, что у нас массив даже если пусто
                }
                
                foreach ($update in $updates) {
                    $lastUpdateId = $update.update_id + 1
                    # Универсальная обработка разных типов сообщений
                    $messageObj = $null
                    $messageType = $null
                    if ($update.PSObject.Properties["message"] -and $update.message.text) {
                        $messageObj = $update.message
                        $messageType = $update.message.chat.type
                    } elseif ($update.PSObject.Properties["channel_post"] -and $update.channel_post.text) {
                        $messageObj = $update.channel_post
                        $messageType = $update.channel_post.chat.type
                    }
                    if ($messageObj -and $messageObj.text) {
                        $chatId = $messageObj.chat.id
                        $messageId = $messageObj.message_id
                        $messageText = $messageObj.text
                        $chatType = $messageObj.chat.type
                        Write-PSFMessage -Level Verbose -FunctionName "BotService.Start" -Message "Получено сообщение ($messageType): $messageText из чата ID: $chatId"
                        # Проверяем, является ли сообщение командой (начинается со слэша)
                        if ($messageText.StartsWith('/')) {
                            $this.HandleMenuCommand($messageText, $chatId, $messageId)
                        } else {
                            $this.HandleTextMessage($messageText, $chatId, $messageId, $chatType)
                        }
                    }
                }
            } catch {
                $this.HandleException($_, "BotService.Start")
                Start-Sleep -Seconds 5
            }

            if($Debug) {
                break
            } 
            
            Start-Sleep -Seconds 1
        }
    }
    
    [void] HandleMenuCommand([string]$messageText, [long]$chatId, [int]$messageId) {
        switch ($messageText) {
            "/start" {
                $this.HandleCommand("/start", $chatId, $messageId)
                Write-PSFMessage -Level Verbose -FunctionName "BotService.HandleMenuCommand" -Message "Handled /start command for chat $chatId" -Target $this
            }
            "/help" {
                $this.HandleCommand("/help", $chatId, $messageId)
                Write-PSFMessage -Level Verbose -FunctionName "BotService.HandleMenuCommand" -Message "Handled /help command for chat $chatId" -Target $this
            }
            default {
                Write-PSFMessage -Level Warning -FunctionName "BotService.HandleMenuCommand" -Message "Unknown command: $messageText" -Target $this
                $invalidLinkMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.InvalidLink"
                $this.TelegramService.SendMessage($chatId, $invalidLinkMessage, $messageId, "HTML")
            }
        }
    }
    
    [void] HandleTextMessage([string]$messageText, [long]$chatId, [int]$messageId, [string]$chatType = "private") {
        $result = $this.ValidateTextMessage($messageText)
        if ($result.Success) {
            $this.ProcessTikTokUrl($result.Data.Url, $chatId, $messageId)
        } else {
            $this.ProcessInvalidMessage($result.Error, $chatId, $messageId, $chatType)
        }
    }
    
    [hashtable] ValidateTextMessage([string]$messageText) {
        # Проверяем на ссылку TikTok
        if ($messageText -match "tiktok\.com" -or $messageText -match "vm\.tiktok\.com") {
            # Извлекаем URL из сообщения с помощью регулярного выражения
            $url = ""
            
            # Попытка извлечь URL из сообщения, распознавая разные форматы
            if ($messageText -match "🔗 Link: (https?://(?:www\.|vm\.)?tiktok\.com/[^\s\)]+)") {
                # Формат отчета с иконкой ссылки
                $url = $matches[1]
                Write-PSFMessage -Level Verbose -FunctionName "BotService.ValidateTextMessage" -Message "Extracted TikTok URL from report format: $url" -Target $this
            }
            elseif ($messageText -match "<a href='([^']+)'>([^<]+)</a>") {
                # HTML формат ссылки
                $url = $matches[2] # Берем видимый текст ссылки
                Write-PSFMessage -Level Verbose -FunctionName "BotService.ValidateTextMessage" -Message "Extracted TikTok URL from HTML format: $url" -Target $this
            }
            elseif ($messageText -match "(https?://(?:www\.|vm\.)?tiktok\.com/[^\s\)]+)") {
                # Обычный URL в тексте
                $url = $matches[1]
                Write-PSFMessage -Level Verbose -FunctionName "BotService.ValidateTextMessage" -Message "Extracted TikTok URL from plain text: $url" -Target $this
            }
            else {
                # Если не удалось извлечь URL, используем все сообщение как запасной вариант
                $url = $messageText
                Write-PSFMessage -Level Warning -FunctionName "BotService.ValidateTextMessage" -Message "Could not extract TikTok URL, using full message" -Target $this
            }
            
            # Проверка извлеченного URL
            if ([string]::IsNullOrWhiteSpace($url)) {
                Write-PSFMessage -Level Warning -FunctionName "BotService.ValidateTextMessage" -Message "Empty URL extracted from message: $messageText" -Target $this
                return New-ErrorResponse -ErrorMessage "Empty URL extracted from message"
            }
            
            Write-PSFMessage -Level Verbose -FunctionName "BotService.ValidateTextMessage" -Message "Valid TikTok URL found: $url" -Target $this
            return New-SuccessResponse -Data @{Url = $url}
        }
        else {
            Write-PSFMessage -Level Verbose -FunctionName "BotService.ValidateTextMessage" -Message "No TikTok URL found in message" -Target $this
            return New-ErrorResponse -ErrorMessage "No TikTok URL found in message"
        }
    }
    
    [void] ProcessInvalidMessage([string]$errorMessage, [long]$chatId, [int]$messageId, [string]$chatType = "private") {
        if ($chatType -eq "private") {
            $invalidLinkMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.InvalidLink"
            $this.TelegramService.SendMessage($chatId, $invalidLinkMessage, $messageId, "HTML")
            Write-PSFMessage -Level Verbose -FunctionName "BotService.ProcessInvalidMessage" -Message "Sent invalid link message to chat $chatId. Error: $errorMessage" -Target $this
        } else {
            Write-PSFMessage -Level Verbose -FunctionName "BotService.ProcessInvalidMessage" -Message "Skipped sending invalid link message to group chat $chatId. Error: $errorMessage" -Target $this
        }
    }
    
    [void] HandleException([System.Exception]$exception, [string]$functionName) {
        Write-PSFMessage -Level Error -FunctionName $functionName -Message "Error: $($exception.Message)" -Exception $exception
    }
    
    [hashtable] ProcessTikTokUrl([string]$url, [long]$chatId, [int]$messageId) {
        if ([string]::IsNullOrWhiteSpace($url)) {
            return New-ErrorResponse -ErrorMessage "URL не может быть пустым"
        }
        # Получаем сообщения для обработки
        $processingMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.Processing"
        $downloadingMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.Downloading"
        $analyzingMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.Analyzing"
        
        Write-PSFMessage -Level Verbose -FunctionName "BotService.ProcessTikTokUrl" -Message "Processing TikTok URL: $url for chat $chatId" -Target $this
        
        # Отправляем начальное сообщение о прогрессе
        $progressResponse = $this.TelegramService.SendMessage($chatId, $processingMessage, $messageId, "HTML")
        if (-not $progressResponse.Success -or -not $progressResponse.Data -or -not $progressResponse.Data.result -or -not $progressResponse.Data.result.message_id) {
            $errorMsg = if ($progressResponse.Error) { $progressResponse.Error } else { "Failed to send initial progress message" }
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message $errorMsg -Target $this
            return New-ErrorResponse -ErrorMessage $errorMsg
        }
        
        $progressMsgId = $progressResponse.Data.result.message_id
        
        # Обновляем сообщение - скачивание
        $editResponse = $this.TelegramService.EditMessage($chatId, $progressMsgId, $downloadingMessage, "HTML")
        if (-not $editResponse.Success) {
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to edit progress message: $($editResponse.Error)" -Target $this
            # Продолжаем выполнение, т.к. ошибка редактирования не критична
        }
        
        # Скачиваем видео
        $downloadResult = $this.YtDlpService.SaveTikTokVideo($url, "")
        
        # Проверяем успешность скачивания
        if (-not $downloadResult.Success) {
            # Форматируем и отправляем сообщение об ошибке
            $errorMsg = "❌ Error downloading video:`n`n"
            
            $errorText = ""
            if ($downloadResult.Data -and $downloadResult.Data.RawOutput) {
                foreach ($line in $downloadResult.Data.RawOutput) {
                    if ($line -match "ERROR:") {
                        $errorText += $line + "`n"
                    }
                }
            }
            
            if ([string]::IsNullOrEmpty($errorText)) {
                $errorText = if ($downloadResult.Error) { $downloadResult.Error } else { "Unknown error" }
            }
            
            # Отправляем сообщение об ошибке
            $editErrorResponse = $this.TelegramService.EditMessage($chatId, $progressMsgId, "$errorMsg$errorText", "HTML")
            if (-not $editErrorResponse.Success) {
                Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to edit error message: $($editErrorResponse.Error)" -Target $this
                # Продолжаем выполнение, т.к. ошибка редактирования не критична
            }
            
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to download video: $errorText" -Target $this
            return New-ErrorResponse -ErrorMessage $errorText
        }
        
        # Обновляем сообщение - анализ
        $editAnalyzeResponse = $this.TelegramService.EditMessage($chatId, $progressMsgId, $analyzingMessage, "HTML")
        if (-not $editAnalyzeResponse.Success) {
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to edit progress message (analyzing): $($editAnalyzeResponse.Error)" -Target $this
            # Продолжаем выполнение, т.к. ошибка редактирования не критична
        }
        
        # Анализируем видео и генерируем отчет
        $mediaInfoResponse = $this.MediaInfoExtractorService.GetMediaInfo($downloadResult.Data.FilePath)
        if (-not $mediaInfoResponse.Success) {
            $errorMsg = "\u274c Error analyzing video: $($mediaInfoResponse.Error)"
            $this.TelegramService.EditMessage($chatId, $progressMsgId, $errorMsg, "HTML")
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to analyze video: $($mediaInfoResponse.Error)" -Target $this
            return New-ErrorResponse -ErrorMessage $mediaInfoResponse.Error
        }
        
        # Форматируем информацию и генерируем хэштеги
        $reportResponse = $this.MediaFormatterService.FormatMediaInfo($mediaInfoResponse, $downloadResult.Data.AuthorUsername, $url, $downloadResult.Data.FullVideoUrl, "", "")
        if (-not $reportResponse.Success) {
            $report = "\u274c Error formatting media info: $($reportResponse.Error)"
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to format media info: $($reportResponse.Error)" -Target $this
        } else {
            $report = $reportResponse.Data
        }
        
        $hashtagsResponse = $this.HashtagGeneratorService.GetVideoHashtags($mediaInfoResponse, $downloadResult.Data.AuthorUsername)
        $hashtagsString = if ($hashtagsResponse.Success) { $hashtagsResponse.Data } else { "" }
        
        # Обновляем сообщение с финальным отчетом
        $finalReportResponse = $this.TelegramService.EditMessage($chatId, $progressMsgId, $report, "HTML")
        if (-not $finalReportResponse.Success) {
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "Failed to edit final report message: $($finalReportResponse.Error)" -Target $this
            # Продолжаем выполнение, т.к. ошибка редактирования не критична
        }
        
        # Отправляем файл
        $fileCaption = if ($hashtagsString) { $hashtagsString } else { "📎 TikTok video file (original quality)" }
        $fileResult = $null
        try {
            $fileResult = $this.TelegramService.SendFile($chatId, $downloadResult.Data.FilePath, $fileCaption, $messageId)
        } catch {
            Write-PSFMessage -Level Error -FunctionName "BotService.ProcessTikTokUrl" -Message "Error sending file: $_" -Target $this
            # Продолжаем работу, даже если не удалось отправить файл
            $fileResult = New-ErrorResponse -ErrorMessage $_.ToString() -Data @{ reason = "exception" }
        }
        
        # Проверяем, что $fileResult не $null перед использованием
        if ($null -eq $fileResult) {
            Write-PSFMessage -Level Warning -FunctionName "BotService.ProcessTikTokUrl" -Message "File result is null, creating default failed result" -Target $this
            $fileResult = New-ErrorResponse -ErrorMessage "SendFile returned null" -Data @{ reason = "null_result" }
        }
        
        # Удаляем временный файл
        if (Test-Path -Path $downloadResult.Data.FilePath) {
            Remove-Item -Path $downloadResult.Data.FilePath -Force
            Write-PSFMessage -Level Verbose -FunctionName "BotService.ProcessTikTokUrl" -Message "Temporary file deleted: $($downloadResult.Data.FilePath)" -Target $this
        }
        
        Write-PSFMessage -Level Verbose -FunctionName "BotService.ProcessTikTokUrl" -Message "Successfully processed TikTok URL: $url" -Target $this
        
        return New-SuccessResponse -Data @{
            Report = $report
            FileSent = if ($fileResult.Success) { $true } else { $false }
            FilePath = $downloadResult.Data.FilePath
        }
    }
    
    [void] HandleCommand([string]$command, [long]$chatId, [int]$messageId) {
        switch ($command) {
            "/start" {
                $welcomeMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.Welcome"
                $messageResponse = $this.TelegramService.SendMessage($chatId, $welcomeMessage, $messageId, "HTML")
                if (-not $messageResponse.Success) {
                    Write-PSFMessage -Level Warning -FunctionName "BotService.HandleCommand" -Message "Failed to send welcome message: $($messageResponse.Error)" -Target $this
                } else {
                    Write-PSFMessage -Level Verbose -FunctionName "BotService.HandleCommand" -Message "Sent welcome message to chat $chatId" -Target $this
                }
            }
            "/help" {
                $helpMessage = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.Help"
                $messageResponse = $this.TelegramService.SendMessage($chatId, $helpMessage, $messageId, "HTML")
                if (-not $messageResponse.Success) {
                    Write-PSFMessage -Level Warning -FunctionName "BotService.HandleCommand" -Message "Failed to send help message: $($messageResponse.Error)" -Target $this
                } else {
                    Write-PSFMessage -Level Verbose -FunctionName "BotService.HandleCommand" -Message "Sent help message to chat $chatId" -Target $this
                }
            }
            default {
                Write-PSFMessage -Level Warning -FunctionName "BotService.HandleCommand" -Message "Unknown command: $command" -Target $this
            }
        }
    }
    
    [hashtable] TestDependencies([switch]$SkipTokenValidation, [switch]$SkipCheckUpdates = $false) {
        $result = @{
            AllValid = $true
            Dependencies = @()
        }
        
        # Проверка базовых зависимостей
        $result.Dependencies += $this.TestPowerShell()
        $result.Dependencies += $this.TestPSFramework()
        
        # Получаем результаты проверки из других сервисов
        $mediaInfoResult = $this.MediaInfoExtractorService.TestMediaInfoDependency($SkipCheckUpdates)
        $ytdlpResult = $this.YtDlpService.TestYtDlpInstallation($SkipCheckUpdates)
        $telegramResult = $this.TelegramService.TestToken($SkipTokenValidation)

        # Добавляем MediaInfo зависимость
        if ($mediaInfoResult.Success -and $mediaInfoResult.Data) {
            $result.Dependencies += $mediaInfoResult.Data
        } else {
            $result.Dependencies += @{
                Name = "MediaInfo"
                Valid = $false
                Version = "Неизвестно"
                Description = $mediaInfoResult.Error
            }
        }

        # Преобразуем результат проверки yt-dlp в общий формат
        if ($ytdlpResult.Success -and $ytdlpResult.Data) {
            $ytdlpData = $ytdlpResult.Data.Clone()
            $ytdlpData.Name = "yt-dlp"
            $ytdlpData.Valid = $true
            $ytdlpData.Description = "yt-dlp $($ytdlpData.Version) найден"
            $result.Dependencies += $ytdlpData
            Write-PSFMessage -Level Debug -FunctionName "TestDependencies" -Message "Added yt-dlp dependency with CheckUpdates: $($null -ne $ytdlpData.CheckUpdatesResult)"
        } else {
            $result.Dependencies += @{
                Name = "yt-dlp"
                Valid = $false
                Version = "Не найден"
                Description = "yt-dlp не найден или не работает: $($ytdlpResult.Error)"
            }
        }

        # Добавляем Telegram зависимость
        if ($telegramResult.Success -and $telegramResult.Data) {
            $result.Dependencies += $telegramResult.Data
        } else {
            $result.Dependencies += @{
                Name = "Telegram Bot"
                Valid = $false
                Version = "Н/Д"
                Description = $telegramResult.Error
            }
        }
        
        # Проверяем общий результат
        foreach ($dep in $result.Dependencies) {
            if (-not $dep.Valid) {
                $result.AllValid = $false
                break
            }
        }
        
        return New-SuccessResponse -Data $result
    }
    
    [void] ShowDependencyValidationResults([PSCustomObject]$ValidationResults) {
        if (-not $ValidationResults.Success) {
            Write-Host "Ошибка при проверке зависимостей: $($ValidationResults.Error)" -ForegroundColor Red
            return
        }
        
        if ($ValidationResults.Data.AllValid) {
            Write-Host "Все зависимости проверены успешно." -ForegroundColor Green
        }
        
        # Рисуем заголовок таблицы с более корректным выравниванием
        Write-Host 
        Write-Host ("{0,10} {1,-17} {2,-20} {3,-40}" -f "Статус", "Компонент", "Версия", "Примечание") -ForegroundColor DarkCyan
        Write-Host ("{0,10} {1,-17} {2,-20} {3,-40}" -f "-------", "---------", "-------", "-----------") -ForegroundColor DarkCyan
        
        foreach ($dep in $ValidationResults.Data.Dependencies) {
            # Определяем статус и цвет
            $statusColor = "Green"
            $statusSymbol = "✓ OK"
            
            # Проверяем наличие обновления
            $needsUpdate = $false
            $updateInfo = ""
            
            # Добавляем отладочную информацию
            Write-PSFMessage -Level Debug -FunctionName "ShowDependencyValidationResults" -Message "Processing component: $($dep.Name), Valid: $($dep.Valid), HasCheckResult: $($null -ne $dep.CheckUpdatesResult)"
            
            if ($dep.CheckUpdatesResult) {
                Write-PSFMessage -Level Debug -FunctionName "ShowDependencyValidationResults" -Message "CheckUpdatesResult: NeedsUpdate=$($dep.CheckUpdatesResult.NeedsUpdate), NewVersion=$($dep.CheckUpdatesResult.NewVersion)"
            }
            
            if ($dep.Valid -and $dep.CheckUpdatesResult -and $dep.CheckUpdatesResult.NeedsUpdate) {
                $needsUpdate = $true
                $statusColor = "Yellow"
                $statusSymbol = "⚠ Update"
                $updateInfo = "Есть обновление: $($dep.CheckUpdatesResult.NewVersion)"
                Write-PSFMessage -Level Debug -FunctionName "ShowDependencyValidationResults" -Message "Setting update status for $($dep.Name): $updateInfo"
            } elseif (-not $dep.Valid) {
                $statusColor = "Red"
                $statusSymbol = "x Failed"
            }
            
            # Очищаем версию от переносов строк
            $versionStr = $dep.Version -replace "`n", " " -replace "`r", ""
            
            # Ограничиваем длину версии до 20 символов
            if ($versionStr.Length -gt 20) {
                $versionStr = $versionStr.Substring(0, 17) + "..."
            }
            
            # Выводим информацию в форматированном виде
            Write-Host ("{0,10} {1,-17} {2,-20} {3,-40}" -f $statusSymbol, $dep.Name, $versionStr, $updateInfo) -ForegroundColor $statusColor
        }
        
        Write-Host 
        
        $invalidDeps = $ValidationResults.Data.Dependencies | Where-Object { -not $_.Valid }
        if ($invalidDeps.Count -gt 0) {
            Write-Host "Обнаружены проблемы со следующими компонентами:" -ForegroundColor Yellow
            foreach ($dep in $invalidDeps) {
                Write-Host "  - $($dep.Name): $($dep.Description)" -ForegroundColor Yellow
            }
            Write-Host
            
            # Добавляем инструкции по установке yt-dlp, если его нет
            $ytdlpDep = $ValidationResults.Data.Dependencies | Where-Object { $_.Name -eq "yt-dlp" -and -not $_.Valid }
            if ($ytdlpDep) {
                Write-Host "Рекомендации по установке yt-dlp:" -ForegroundColor Cyan
                Write-Host "  1. С помощью pip (требуется Python):" -ForegroundColor Cyan
                Write-Host "     python -m pip install -U yt-dlp" -ForegroundColor White
                Write-Host
            }
        }
    }
    
    # Приватные методы для внутренних проверок
    [hashtable] TestPowerShell() {
        try {
            # Безопасно получаем версию PowerShell
            if ($null -ne $global:PSVersionTable -and $null -ne $global:PSVersionTable.PSVersion) {
                $psVersion = $global:PSVersionTable.PSVersion
            } else {
                # Фаллбэк на случай, если не можем получить реальную версию
                $psVersion = [Version]::new(7, 0)
            }
            
            $psValid = $psVersion.Major -ge 7
            
            return @{
                Name = "PowerShell"
                Valid = $psValid
                Version = $psVersion.ToString()
                Description = if ($psValid) { "PowerShell $($psVersion.ToString()) доступен" } else { "Требуется PowerShell 7+, текущая версия: $($psVersion.ToString())" }
            }
        } catch {
            # В случае любых ошибок, предполагаем успешную проверку
            return @{
                Name = "PowerShell"
                Valid = $true
                Version = "7.0+"
                Description = "PowerShell 7.0+ доступен (предполагается по умолчанию)"
            }
        }
    }
    
    [hashtable] TestPSFramework() {
        $psFrameworkVersion = Get-Module -Name PSFramework -ListAvailable | Select-Object -ExpandProperty Version -First 1
        $psFrameworkValid = $null -ne $psFrameworkVersion
        
        return @{
            Name = "PSFramework"
            Valid = $psFrameworkValid
            Version = if ($psFrameworkValid) { $psFrameworkVersion.ToString() } else { "Не установлен" }
            Description = if ($psFrameworkValid) { "PSFramework $($psFrameworkVersion.ToString()) установлен" } else { "PSFramework не установлен" }
        }
    }
}
