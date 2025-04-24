<#
.SYNOPSIS
    Интерфейс для извлечения технической информации из медиафайлов.
.DESCRIPTION
    Определяет методы для анализа и извлечения технических характеристик видео.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class IMediaInfoExtractorService {
    # Получает технические характеристики видеофайла
    # Возвращает: @{ Success = $true/false; Data = $mediaInfo; Error = $errorMessage }
    [hashtable] GetMediaInfo([string]$filePath) { throw "Must be implemented" }
    
    # Проверяет наличие и работоспособность MediaInfo
    # Возвращает: @{ Success = $true/false; Data = $testResult; Error = $errorMessage }
    [hashtable] TestMediaInfoDependency([switch]$SkipCheckUpdates = $false) { throw "Must be implemented" }
}
