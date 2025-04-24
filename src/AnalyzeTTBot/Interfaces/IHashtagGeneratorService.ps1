<#
.SYNOPSIS
    Интерфейс для генерации хэштегов на основе медиаданных.
.DESCRIPTION
    Определяет методы для создания хэштегов на основе характеристик видео.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class IHashtagGeneratorService {
    # Генерирует хэштеги на основе характеристик видео
    # Возвращает: @{ Success = $true/false; Data = $hashtags; Error = $errorMessage }
    [hashtable] GetVideoHashtags([hashtable]$mediaInfo, [string]$authorUsername) { throw "Must be implemented" }
}
