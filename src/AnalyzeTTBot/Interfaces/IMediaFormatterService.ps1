<#
.SYNOPSIS
    Интерфейс для форматирования информации о медиафайлах.
.DESCRIPTION
    Определяет методы для форматирования технических характеристик видео для отображения.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class IMediaFormatterService {
    # Форматирует информацию о видео для отображения
    # Возвращает: @{ Success = $true/false; Data = $formattedText; Error = $errorMessage }
    [hashtable] FormatMediaInfo([hashtable]$mediaInfo, [string]$authorUsername, [string]$videoUrl, [string]$fullVideoUrl, [string]$filePath = "", [string]$videoTitle = "") { throw "Must be implemented" }
}
