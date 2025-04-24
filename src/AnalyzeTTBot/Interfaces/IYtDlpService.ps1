<#
.SYNOPSIS
    Интерфейс для работы с утилитой yt-dlp.
.DESCRIPTION
    Определяет методы для скачивания видео с TikTok и других платформ.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class IYtDlpService {
    # Скачивает видео с TikTok по URL
    # Возвращает: @{ Success = $true/false; Data = $outputPath; Error = $errorMessage }
    [hashtable] SaveTikTokVideo([string]$url, [string]$outputPath = "") { throw "Must be implemented" }
    
    # Обновляет yt-dlp до последней версии
    # Возвращает: @{ Success = $true/false; Data = $updateResult; Error = $errorMessage }
    [hashtable] UpdateYtDlp() { throw "Must be implemented" }
    
    # Проверяет наличие и работоспособность yt-dlp
    # Возвращает: @{ Success = $true/false; Data = $testResult; Error = $errorMessage }
    [hashtable] TestYtDlpInstallation([switch]$SkipCheckUpdates = $false) { throw "Must be implemented" }
}
