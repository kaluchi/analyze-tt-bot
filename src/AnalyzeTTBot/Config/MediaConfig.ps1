<#
.SYNOPSIS
    Конфигурация параметров работы с медиафайлами для AnalyzeTTBot.
.DESCRIPTION
    Определяет настройки для работы с медиафайлами, их обработки и хранения.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 02.04.2025
#>

# Конфигурация временной папки для сохранения файлов
$tempFolderConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Temp.Folder"
    Value           = "TikTokAnalyzer"
    Description     = "Имя временной папки для сохранения скачанных файлов"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @tempFolderConfig | Register-PSFConfig

# Конфигурация формата хранения медиа-метаданных
$mediaFormatConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Media.MetadataFormat"
    Value           = "json"
    Description     = "Формат хранения метаданных о медиафайлах (json, xml, text)"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @mediaFormatConfig | Register-PSFConfig

# Конфигурация используемых кодеков для анализа
$mediaCodecsConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Media.Codecs"
    Value           = @("h264", "h265", "avc1", "av01", "vp8", "vp9")
    Description     = "Список поддерживаемых видеокодеков для анализа"
    Validation      = "stringarray"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @mediaCodecsConfig | Register-PSFConfig

# Настройка максимальной глубины анализа метаданных
$mediaDepthConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Media.AnalysisDepth"
    Value           = 3
    Description     = "Уровень детализации при анализе медиафайлов (1-минимальный, 3-стандартный, 5-детальный)"
    Validation      = "integer"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @mediaDepthConfig | Register-PSFConfig

# Определение пути к MediaInfo (может быть перезаписано из локальной конфигурации)
$mediaInfoPathConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "MediaInfo.Path"
    Value           = "mediainfo"
    Description     = "Путь к исполняемому файлу MediaInfo. Используйте полный путь, если программа не в PATH"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @mediaInfoPathConfig | Register-PSFConfig

Write-PSFMessage -Level Verbose -Message "Конфигурация медиа инициализирована"
