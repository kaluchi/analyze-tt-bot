<#
.SYNOPSIS
    Интерфейс для работы с API Telegram.
.DESCRIPTION
    Определяет методы для отправки сообщений, файлов и получения обновлений от Telegram Bot API.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class ITelegramService {
    # Отправляет сообщение в чат
    # Возвращает: @{ Success = $true/false; Data = $messageResult; Error = $errorMessage }
    [hashtable] SendMessage([long]$chatId, [string]$text, [int]$replyToMessageId, [string]$parseMode) { throw "Must be implemented" }
    
    # Редактирует сообщение в чате
    # Возвращает: @{ Success = $true/false; Data = $editResult; Error = $errorMessage }
    [hashtable] EditMessage([long]$chatId, [int]$messageId, [string]$text, [string]$parseMode) { throw "Must be implemented" }
    
    # Отправляет файл в чат
    # Возвращает: @{ Success = $true/false; Data = $fileResult; Error = $errorMessage }
    [hashtable] SendFile([long]$chatId, [string]$filePath, [string]$caption, [int]$replyToMessageId) { throw "Must be implemented" }
    
    # Получает обновления от Telegram Bot API
    # Возвращает: @{ Success = $true/false; Data = $updates; Error = $errorMessage }
    [hashtable] GetUpdates([int]$offset, [int]$timeout) { throw "Must be implemented" }
    
    # Проверяет валидность токена
    # Возвращает: @{ Success = $true/false; Data = $tokenInfo; Error = $errorMessage }
    [hashtable] TestToken([switch]$SkipTokenValidation) { throw "Must be implemented" }
}
