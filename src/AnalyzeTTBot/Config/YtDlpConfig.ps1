<#
.SYNOPSIS
    Конфигурация параметров yt-dlp для AnalyzeTTBot.
.DESCRIPTION
    Определяет настройки для инструмента скачивания видео yt-dlp.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 02.04.2025
#>

# Конфигурация пути к yt-dlp (может быть перезаписано из локальной конфигурации)
$ytdlpPathConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "YtDlp.Path"
    Value           = "yt-dlp"
    Description     = "Путь к исполняемому файлу yt-dlp. Используйте полный путь, если программа не в PATH"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @ytdlpPathConfig | Register-PSFConfig

# Настройка для обновления yt-dlp при запуске
$ytdlpUpdateConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "YtDlp.UpdateOnStart"
    Value           = $false
    Description     = "Обновлять yt-dlp при каждом запуске бота"
    Validation      = "bool"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @ytdlpUpdateConfig | Register-PSFConfig

# Таймаут выполнения команды скачивания
$ytdlpTimeoutConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "YtDlp.Timeout"
    Value           = 300
    Description     = "Максимальное время ожидания (в секундах) для операций скачивания через yt-dlp"
    Validation      = "integer"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @ytdlpTimeoutConfig | Register-PSFConfig

# Формат видео для скачивания
$ytdlpFormatConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "YtDlp.Format"
    Value           = "best"
    Description     = "Формат видео для скачивания через yt-dlp (best, worst, bestvideo+bestaudio, и т.д.)"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @ytdlpFormatConfig | Register-PSFConfig

Write-PSFMessage -Level Verbose -Message "Конфигурация yt-dlp инициализирована"
