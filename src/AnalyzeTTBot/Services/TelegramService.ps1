<#
.SYNOPSIS
    Сервис для работы с API Telegram.
.DESCRIPTION
    Предоставляет функциональность для отправки сообщений, файлов и получения обновлений от Telegram Bot API.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 01.04.2025 - Использование утилитарных функций для логирования и работы с процессами
#>

# Вспомогательная функция для вызова API через curl (работает с proxy)
function Invoke-CurlMethod {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Uri,

        [Parameter(Mandatory=$false)]
        [string]$Method = "GET",

        [Parameter(Mandatory=$false)]
        [string]$Body,

        [Parameter(Mandatory=$false)]
        [string]$ContentType = "application/json",

        [Parameter(Mandatory=$false)]
        [hashtable]$Form
    )

    $curlArgs = @('-s')  # Silent mode

    if ($Method -eq "POST") {
        $curlArgs += '-X', 'POST'
        if ($Body) {
            $curlArgs += '-H', "Content-Type: $ContentType"
            $curlArgs += '-d', $Body
        }
        if ($Form) {
            # Для multipart/form-data используем -F параметры
            foreach ($key in $Form.Keys) {
                $value = $Form[$key]
                if ($value -is [System.IO.FileInfo]) {
                    $curlArgs += '-F', "document=@`"$($value.FullName)`""
                } else {
                    $curlArgs += '-F', "$key=$value"
                }
            }
        }
    }

    $curlArgs += $Uri

    try {
        $result = & curl @curlArgs 2>&1

        if ($LASTEXITCODE -eq 0) {
            # Парсим JSON
            $jsonResult = $result | ConvertFrom-Json
            return $jsonResult
        } else {
            throw "curl failed with exit code ${LASTEXITCODE}: $result"
        }
    } catch {
        throw "Invoke-CurlMethod failed: $($_.Exception.Message)"
    }
}

class TelegramService : ITelegramService {
    [string]$Token
    [int]$MaxFileSizeMB
    [string]$FileTooLargeTemplate
    
    TelegramService([string]$token, [int]$maxFileSizeMB) {
        $this.Token = $token
        $this.MaxFileSizeMB = $maxFileSizeMB
        $this.FileTooLargeTemplate = Get-PSFConfigValue -FullName "AnalyzeTTBot.Messages.FileTooLarge" -Fallback "⚠️ Файл слишком большой для отправки через Telegram ({0} МБ)."
        
        # В логах указываем только общую информацию, без чувствительных данных
        Write-OperationSucceeded -Operation "TelegramService initialization" -Details "Max file size: $maxFileSizeMB MB" -FunctionName "TelegramService.Constructor"
    }
    
    [hashtable] SendMessage([long]$chatId, [string]$text, [int]$replyToMessageId, [string]$parseMode) {
        $apiUrl = "https://api.telegram.org/bot$($this.Token)"
        $uri = "$apiUrl/sendMessage"
        
        $params = @{
            chat_id = $chatId
            text = $text
        }
        
        if ($replyToMessageId) {
            $params.reply_to_message_id = $replyToMessageId
        }
        
        if ($parseMode) {
            $params.parse_mode = $parseMode
        }
        
        Write-OperationStart -Operation "Send Telegram message" -Target "Chat $chatId (length: $($text.Length) chars)" -FunctionName "SendMessage"

        try {
            $response = Invoke-CurlMethod -Uri $uri -Method Post -ContentType "application/json" -Body ($params | ConvertTo-Json)
            Write-OperationSucceeded -Operation "Send Telegram message" -Details "Message ID: $($response.result.message_id)" -FunctionName "SendMessage"
            return New-SuccessResponse -Data $response
        } catch {
            $errorMessage = "Failed to send message to Telegram: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Send Telegram message" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "SendMessage"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
    
    [hashtable] EditMessage([long]$chatId, [int]$messageId, [string]$text, [string]$parseMode) {
        $apiUrl = "https://api.telegram.org/bot$($this.Token)"
        $uri = "$apiUrl/editMessageText"
        
        $params = @{
            chat_id = $chatId
            message_id = $messageId
            text = $text
        }
        
        if ($parseMode) {
            $params.parse_mode = $parseMode
        }
        
        Write-OperationStart -Operation "Edit Telegram message" -Target "Message $messageId in chat $chatId" -FunctionName "EditMessage"

        try {
            $response = Invoke-CurlMethod -Uri $uri -Method Post -ContentType "application/json" -Body ($params | ConvertTo-Json)
            Write-OperationSucceeded -Operation "Edit Telegram message" -FunctionName "EditMessage"
            return New-SuccessResponse -Data $response
        } catch {
            # Если ошибка связана с тем, что сообщение не изменилось, это не считается ошибкой
            if ($_.Exception.Message -match "message is not modified") {
                Write-PSFMessage -Level Verbose -FunctionName "EditMessage" -Message "Message not modified"
                $notModifiedResponse = @{
                    ok = $true
                    result = @{
                        message_id = $messageId
                    }
                }
                return New-SuccessResponse -Data $notModifiedResponse
            }
            
            $errorMessage = "Failed to edit message: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Edit Telegram message" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "EditMessage"
            
            # Не выбрасываем исключение, так как ошибка редактирования не критична
            $errorData = @{
                message_id = $messageId
            }
            return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
        }
    }
    
    [hashtable] SendFile([long]$chatId, [string]$filePath, [string]$caption, [int]$replyToMessageId) {
        $apiUrl = "https://api.telegram.org/bot$($this.Token)"
        $uri = "$apiUrl/sendDocument"
        
        # Проверяем существование файла
        if (-not (Test-Path -Path $filePath)) {
            Write-OperationFailed -Operation "Send Telegram file" -ErrorMessage "File not found: $filePath" -FunctionName "SendFile"
            return New-ErrorResponse -ErrorMessage "File not found: $filePath" -Data @{ reason = "file_not_found" }
        }
        
        # Получаем размер файла
        $fileInfo = Get-Item $filePath
        $fileSize = $fileInfo.Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
        
        Write-OperationStart -Operation "Send Telegram file" -Target "$filePath ($fileSizeMB MB) to chat $chatId" -FunctionName "SendFile"
        
        # Если файл больше максимально допустимого размера
        if ($fileSizeMB -gt $this.MaxFileSizeMB) {
            $errorMessage = "File is too large: $fileSizeMB MB > $($this.MaxFileSizeMB) MB"
            Write-OperationFailed -Operation "Send Telegram file" -ErrorMessage $errorMessage -FunctionName "SendFile"
            
            # Формируем сообщение о том, что файл слишком большой
            $message = $this.FileTooLargeTemplate -f $fileSizeMB
            
            # Добавляем подпись к файлу, если она есть
            if ($caption) {
                $message += "`n`n$caption"
            }
            
            # Отправляем сообщение вместо файла
            $this.SendMessage($chatId, $message, $replyToMessageId, $null)
            
            return New-ErrorResponse -ErrorMessage $errorMessage -Data @{ 
                reason = "file_too_large"
                file_size = $fileSizeMB
            }
        }
        
        # В PowerShell 7 можно использовать параметр -Form для отправки файлов
        try {
            # Создаем форму для отправки файла
            $form = @{
                chat_id = $chatId
                document = Get-Item -Path $filePath
            }
            
            # Добавляем опциональные параметры
            if (-not [string]::IsNullOrEmpty($caption)) {
                $form['caption'] = $caption
            }
            
            if ($replyToMessageId) {
                $form['reply_to_message_id'] = $replyToMessageId
            }
            
            # Отправляем запрос
            $response = Invoke-RestMethod -Uri $uri -Method Post -Form $form -ErrorAction Stop
            
            Write-OperationSucceeded -Operation "Send Telegram file" -Details "Using PowerShell 7 native form" -FunctionName "SendFile"
            return New-SuccessResponse -Data $response.result
        } catch {
            Write-PSFMessage -Level Warning -FunctionName "SendFile" -Message "Error with native method: $_. Falling back to curl"
            
            # Используем ProcessHelper для выполнения curl
            # Создаем параметры для curl
            $curlArgs = @(
                '-s',
                '-X', 'POST',
                $uri
            )
            
            # Добавляем обязательный параметр chat_id
            $curlArgs += @('-F', "chat_id=$chatId")
            
            # Добавляем опциональные параметры
            if (-not [string]::IsNullOrEmpty($caption)) {
                # Экранируем кавычки в caption для безопасной передачи через curl
                $escapedCaption = $caption -replace '"', '\"'
                $curlArgs += @('-F', "caption=`"$escapedCaption`"")
            }
            
            if ($replyToMessageId) {
                $curlArgs += @('-F', "reply_to_message_id=$replyToMessageId")
            }
            
            # Добавляем сам файл
            $curlArgs += @('-F', "document=@`"$filePath`"")
            
            # Выполняем curl через ProcessHelper
            try {
                $curlResult = Invoke-ExternalProcess -ExecutablePath "curl" -ArgumentList $curlArgs
                
                if (-not $curlResult.Success) {
                    $errorMessage = "curl error: $($curlResult.Error)"
                    Write-OperationFailed -Operation "Send Telegram file" -ErrorMessage $errorMessage -FunctionName "SendFile"
                    return New-ErrorResponse -ErrorMessage $errorMessage -Data @{ reason = "curl_error" }
                }
                
                $result = $curlResult.Output
                
                # Проверяем результат на ошибку "Request Entity Too Large"
                if ($result -match "Request Entity Too Large") {
                    $errorMessage = "Request Entity Too Large"
                    Write-OperationFailed -Operation "Send Telegram file" -ErrorMessage $errorMessage -FunctionName "SendFile"
                    
                    # Отправляем сообщение о том, что файл слишком большой
                    $message = $this.FileTooLargeTemplate -f $fileSizeMB
                    
                    if (-not [string]::IsNullOrEmpty($caption)) {
                        $message += "`n`n$caption"
                    }
                    
                    $this.SendMessage($chatId, $message, $replyToMessageId, $null)
                    
                    return New-ErrorResponse -ErrorMessage $errorMessage -Data @{ 
                        reason = "request_entity_too_large"
                        file_size = $fileSizeMB
                    }
                }
                
                Write-OperationSucceeded -Operation "Send Telegram file" -Details "Using curl" -FunctionName "SendFile"
                
                # Пытаемся парсить JSON результата
                try {
                    $jsonResult = $result | ConvertFrom-Json
                    return New-SuccessResponse -Data $jsonResult.result
                } catch {
                    # Если не удалось парсить JSON, просто возвращаем успех
                    return New-SuccessResponse
                }
            } catch {
                $errorMessage = "Failed to send file with curl: $_"
                Write-OperationFailed -Operation "Send Telegram file" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "SendFile"
                return New-ErrorResponse -ErrorMessage $errorMessage -Data @{ reason = "curl_error" }
            }
        }
    }
    
    [hashtable] GetUpdates([int]$offset, [int]$timeout) {
        $apiUrl = "https://api.telegram.org/bot$($this.Token)"
        
        $params = @{
            offset = $offset
            timeout = $timeout
        }
        
        # Формируем URL запроса
        $queryParams = $params.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
        $queryString = $queryParams -join "&"
        $uri = "$apiUrl/getUpdates?$queryString"
        
        Write-PSFMessage -Level Debug -FunctionName "GetUpdates" -Message "Getting updates with offset $offset and timeout $timeout"

        try {
            $response = Invoke-CurlMethod -Uri $uri -Method Get

            # Если дошли сюда, значит запрос успешен (HTTP 200)
            if ($response.ok) {
                $updates = if ($null -ne $response.result) { $response.result } else { @() }
                if ($updates.Count -gt 0) {
                    Write-PSFMessage -Level Verbose -FunctionName "GetUpdates" -Message "Received $($updates.Count) updates. Updates content: $($updates | ConvertTo-Json -Depth 10)"
                }
                return New-SuccessResponse -Data $updates
            } else {
                $errorMessage = "Error getting updates: $($response.description)"
                Write-PSFMessage -Level Warning -FunctionName "GetUpdates" -Message $errorMessage
                return New-ErrorResponse -ErrorMessage $errorMessage
            }
        } catch {
            $errorMessage = "Error getting updates: $($_.Exception.Message)"
            Write-PSFMessage -Level Warning -FunctionName "GetUpdates" -Message $errorMessage
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
    
    [hashtable] TestToken([switch]$SkipTokenValidation) {
        try {
            $telegramToken = $this.Token
            
            if ([string]::IsNullOrWhiteSpace($telegramToken) -or $telegramToken -eq "PLACE_YOUR_REAL_TOKEN_HERE" -or $telegramToken -eq "YOUR_BOT_TOKEN_HERE") {
                $testResult = @{
                    Name = "Telegram Bot"
                    Valid = $false
                    Version = "Н/Д"
                    Description = "Токен Telegram не настроен"
                }
                return New-ErrorResponse -ErrorMessage "Токен Telegram не настроен" -Data $testResult
            } 
            elseif ($SkipTokenValidation) {
                $testResult = @{
                    Name = "Telegram Bot"
                    Valid = $true
                    Version = "Пропущена валидация"
                    Description = "Валидация токена пропущена (ручной режим пропуска)"
                }
                return New-SuccessResponse -Data $testResult
            }
            else {
                # Проверяем работоспособность токена
                Write-PSFMessage -Level Verbose -Message "Проверка токена Telegram (скрыт для безопасности)"
                $apiUrl = "https://api.telegram.org/bot$telegramToken/getMe"
                Write-PSFMessage -Level Verbose -Message "API URL: $apiUrl"

                try {
                    $response = Invoke-CurlMethod -Uri $apiUrl -Method Get

                    if ($response.ok) {
                        $testResult = @{
                            Name = "Telegram Bot"
                            Valid = $true
                            Version = "@$($response.result.username)"
                            Description = "Бот @$($response.result.username) активен"
                        }
                        return New-SuccessResponse -Data $testResult
                    } else {
                        $testResult = @{
                            Name = "Telegram Bot"
                            Valid = $false
                            Version = "Н/Д"
                            Description = "Недействительный токен или ошибка API"
                        }
                        return New-ErrorResponse -ErrorMessage "Недействительный токен или ошибка API" -Data $testResult
                    }
                } catch {
                    $errorMessage = "Не удалось подключиться к API Telegram: $_"
                    $testResult = @{
                        Name = "Telegram Bot"
                        Valid = $false
                        Version = "Н/Д"
                        Description = $errorMessage
                    }
                    return New-ErrorResponse -ErrorMessage $errorMessage -Data $testResult
                }
            }
        } catch {
            $errorMessage = "Ошибка при проверке токена Telegram: $_"
            $testResult = @{
                Name = "Telegram Bot"
                Valid = $false
                Version = "Неизвестно"
                Description = $errorMessage
            }
            return New-ErrorResponse -ErrorMessage $errorMessage -Data $testResult
        }
    }
}
