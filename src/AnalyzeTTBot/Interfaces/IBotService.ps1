<#
.SYNOPSIS
    Интерфейс для основного сервиса бота.
.DESCRIPTION
    Определяет методы для запуска бота и обработки сообщений.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class IBotService {
    # Запускает бота и начинает обработку сообщений
    [void] Start([switch]$Debug) { throw "Must be implemented" }
    
    # Обрабатывает URL TikTok
    # Возвращает: @{ Success = $true/false; Data = $processResult; Error = $errorMessage }
    [hashtable] ProcessTikTokUrl([string]$url, [long]$chatId, [int]$messageId) { throw "Must be implemented" }
    
    # Обрабатывает команды бота
    [void] HandleCommand([string]$command, [long]$chatId, [int]$messageId) { throw "Must be implemented" }
    
    # Проверяет все зависимости приложения
    # Возвращает: @{ Success = $true/false; Data = $dependenciesResult; Error = $errorMessage }
    [hashtable] TestDependencies([switch]$SkipTokenValidation, [switch]$SkipCheckUpdates = $false) { throw "Must be implemented" }
    
    # Отображает результаты проверки зависимостей
    [void] ShowDependencyValidationResults([PSCustomObject]$ValidationResults) { throw "Must be implemented" }
}
