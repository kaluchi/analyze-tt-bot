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

# Путь к файлу cookies для аутентификации
# Проверяем наличие переменной окружения YT_DLP_COOKIES_FILE
Write-PSFMessage -Level Verbose -Message "Проверка наличия переменной окружения YT_DLP_COOKIES_FILE"

# Используем переменную окружения, если она задана
$ytdlpCookiesPath = if ($env:YT_DLP_COOKIES_FILE) {
    $env:YT_DLP_COOKIES_FILE  # Используем переменную окружения
} else {
    "./cookies/cookies.txt"  # Значение по умолчанию (dummy файл)
}

# Проверяем, была ли задана переменная окружения
if ($env:YT_DLP_COOKIES_FILE) {
    Write-PSFMessage -Level Verbose -Message "Переменная окружения YT_DLP_COOKIES_FILE найдена и будет использована: $env:YT_DLP_COOKIES_FILE"
} else {
    Write-PSFMessage -Level Verbose -Message "Переменная окружения YT_DLP_COOKIES_FILE не задана, используется fallback: ./cookies/cookies.txt"
}

$ytdlpCookiesConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "YtDlp.CookiesPath"
    Value           = $ytdlpCookiesPath
    Description     = "Путь к файлу cookies для аутентификации в yt-dlp. Используйте YT_DLP_COOKIES_FILE для переопределения."
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @ytdlpCookiesConfig | Register-PSFConfig

Write-PSFMessage -Level Verbose -Message "Конфигурация yt-dlp инициализирована"
