<#
.SYNOPSIS
    Централизованная инициализация конфигурации для AnalyzeTTBot.
.DESCRIPTION
    Единая точка инициализации всех настроек и конфигурационных параметров для AnalyzeTTBot.
    Загружает базовые конфигурационные файлы и настраивает логирование.
.EXAMPLE
    . .\Config\Initialize-Configuration.ps1
    Инициализирует конфигурацию.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Дата: 25.04.2025
#>

# Определяем директорию конфигурации
$configDir = $PSScriptRoot

# Функция загрузки конфигурационных файлов
function Import-ConfigFile {
    [CmdletBinding()]
    param (
        [string]$FilePath
    )
    
    if (Test-Path -Path $FilePath) {
        try {
            Write-PSFMessage -Level Debug -Message "Загрузка конфигурации: $FilePath"
            . $FilePath
            return $true
        }
        catch {
            Write-PSFMessage -Level Debug -Message  "Ошибка при загрузке конфигурационного файла $FilePath : $_"
            return $false
        }
    }
    else {
        Write-PSFMessage -Level Debug -Message  "Файл конфигурации не найден: $FilePath"
        return $false
    }
}

# Создаем массив конфигурационных файлов в порядке загрузки
$configFiles = @(
    "LoggingConfig.ps1",     # Сначала инициализируем логирование
    "TelegramConfig.ps1",    # Затем основные компоненты
    "MediaConfig.ps1",
    "YtDlpConfig.ps1"
)

# 1. Загружаем базовые конфигурационные файлы
$loadedConfigs = @()
foreach ($configFile in $configFiles) {
    $configFilePath = Join-Path -Path $configDir -ChildPath $configFile
    $loaded = Import-ConfigFile -FilePath $configFilePath
    if ($loaded) {
        $loadedConfigs += $configFile
    }
}

Write-PSFMessage -Level Debug -Message "Загружено $($loadedConfigs.Count) из $($configFiles.Count) конфигурационных файлов"

# 2. Регистрация провайдера логирования
$loggingEnabled = Get-PSFConfigValue -FullName "AnalyzeTTBot.Logging.Enabled" -Fallback $true
    
if ($loggingEnabled) {
    $logPath = Get-PSFConfigValue -FullName "AnalyzeTTBot.Logging.Path" -Fallback "$env:TEMP\AnalyzeTTBot\logs"
    $fileFormat = Get-PSFConfigValue -FullName "AnalyzeTTBot.Logging.FileFormat" -Fallback "%date%.log"
    $timeFormat = Get-PSFConfigValue -FullName "AnalyzeTTBot.Logging.TimeFormat" -Fallback "yyyy-MM-dd HH:mm:ss.fff"
    
    # Параметры для провайдера логирования
    $loggingParams = @{
        Name          = 'logfile'
        InstanceName  = 'AnalyzeTTBot'
        Enabled       = $true
        FilePath      = Join-Path -Path $logPath -ChildPath $fileFormat
        FileType      = 'SingleFile'
        TimeFormat    = $timeFormat
        LogRotatePath = $logPath
    }
    
    # Регистрируем провайдер логирования
    try {
        Set-PSFLoggingProvider @loggingParams
        Write-PSFMessage -Level Debug -Message "Провайдер логирования зарегистрирован: $logPath" 
    }
    catch {
        Write-Warning "Ошибка при регистрации провайдера логирования: $_"
    }
}
else {
    Write-PSFMessage -Level Debug -Message  "Логирование отключено в конфигурации"
}

# 3. Дополнительная информация для режима отладки
$debugMode = $DebugPreference -ne "SilentlyContinue" -or $PSBoundParameters.ContainsKey('Debug')

if ($debugMode) {
    Write-PSFMessage -Level Debug -Message "Активирован режим отладки в конфигурации"
}

# Возвращаем информацию о результате инициализации
[PSCustomObject]@{
    ConfigFilesLoaded = $loadedConfigs
    DebugMode = $debugMode
}
