<#
.SYNOPSIS
    Конфигурация логирования для AnalyzeTTBot с использованием PSFramework.
.DESCRIPTION
    Настраивает конфигурацию логирования и диагностики с использованием PSFramework.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 02.04.2025
#>

# Определение базовой директории для логов
# В Linux-контейнере $env:TEMP может быть не определена
$logPath = if ($env:TEMP) {
    Join-Path -Path $env:TEMP -ChildPath "AnalyzeTTBot\logs"
} else {
    # В Linux-контейнере используем стандартную директорию /app/logs
    "/app/logs"
}

# Создаем директорию для логов, если она не существует
if (-not (Test-Path -Path $logPath)) {
    try {
        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        Write-PSFMessage -Level Verbose -Message "Создана директория для логов: $logPath"
    }
    catch {
        Write-PSFMessage -Level Warning -Message "Не удалось создать директорию для логов: $logPath. Ошибка: $_"
    }
}

# Конфигурация включения/отключения логирования
$loggingEnabledConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.Enabled"
    Value           = $true
    Description     = "Включить/выключить логирование в файл"
    Validation      = "bool"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingEnabledConfig | Register-PSFConfig

# Конфигурация пути к директории с логами
$loggingPathConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.Path"
    Value           = $logPath
    Description     = "Путь к директории для хранения логов"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingPathConfig | Register-PSFConfig

# Конфигурация формата имени файла лога
$loggingFilenameConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.FileFormat"
    Value           = "%date%.log"
    Description     = "Формат имени файла лога (используется strftime-подобный формат)"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingFilenameConfig | Register-PSFConfig

# Конфигурация уровня детализации логирования (Verbose, Information, Warning, Error)
# Проверяем наличие переменной окружения LOG_LEVEL
Write-PSFMessage -Level Verbose -Message "Проверка наличия переменной окружения LOG_LEVEL"

# Используем переменную окружения, если она задана
$logLevel = if ($env:LOG_LEVEL) {
    $env:LOG_LEVEL  # Используем переменную окружения
} else {
    "Information"  # Значение по умолчанию
}

# Проверяем, запущен ли скрипт в режиме отладки
$debugMode = $DebugPreference -ne "SilentlyContinue" -or $PSBoundParameters.ContainsKey('Debug')

# Сначала сбрасываем все настройки консольного вывода PSFramework, чтобы обеспечить идемпотентность
# Это решает проблему, когда последующие запуски в той же сессии наследуют состояние от предыдущих запусков
# Set-PSFConfig -FullName PSFramework.Message.ConsoleOutput.Disable -Value $false -PassThru | Register-PSFConfig
# Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 9 -PassThru | Register-PSFConfig
# Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 9 -PassThru | Register-PSFConfig

# Настройка консольного вывода на основе режима отладки и уровня логирования
if ($debugMode) {
    # В режиме отладки настраиваем вывод согласно уровню логирования
    Write-PSFMessage -Level Verbose -Message "Включен режим отладки. Уровень логирования: $logLevel"
    
    switch ($logLevel.ToLower()) {
        "verbose" { 
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 9 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 9 -PassThru | Register-PSFConfig
        }
        "debug" { 
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 6 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 6 -PassThru | Register-PSFConfig
        }
        "information" { 
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 3 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 0 -PassThru | Register-PSFConfig
        }
        "warning" { 
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 2 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 0 -PassThru | Register-PSFConfig
        }
        "error" { 
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 1 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 0 -PassThru | Register-PSFConfig
        }
        "quiet" {
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 0 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 0 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.ConsoleOutput.Disable -Value $true -PassThru | Register-PSFConfig
        }
        default { 
            # Set-PSFConfig -FullName PSFramework.Message.Info.Maximum -Value 3 -PassThru | Register-PSFConfig
            # Set-PSFConfig -FullName PSFramework.Message.Debug.Maximum -Value 0 -PassThru | Register-PSFConfig
        }
    }
} else {
    # Без режима отладки отключаем логирование в консоль
    Write-PSFMessage -Level Verbose -Message "Режим отладки выключен. Логирование в консоль отключено."
    # Set-PSFConfig -FullName PSFramework.Message.ConsoleOutput.Disable -Value $true -PassThru | Register-PSFConfig
}

$loggingLevelConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.Level"
    Value           = $logLevel
    Description     = "Минимальный уровень сообщений для записи в лог (Verbose, Information, Warning, Error)"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingLevelConfig | Register-PSFConfig

# Проверяем, была ли задана переменная окружения
if ($env:LOG_LEVEL) {
    Write-PSFMessage -Level Verbose -Message "Переменная окружения LOG_LEVEL найдена и будет использована: $env:LOG_LEVEL"
}

# Конфигурация максимального размера файла лога перед ротацией
$loggingMaxSizeConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.MaxFileSize"
    Value           = 10MB
    Description     = "Максимальный размер файла лога в байтах перед ротацией"
    Validation      = "long"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingMaxSizeConfig | Register-PSFConfig

# Конфигурация количества хранимых файлов логов
$loggingRetentionConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.FileRetention"
    Value           = 10
    Description     = "Количество хранимых файлов логов до удаления старых"
    Validation      = "integer"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingRetentionConfig | Register-PSFConfig

# Конфигурация формата времени в логах
$loggingTimeFormatConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "Logging.TimeFormat"
    Value           = "yyyy-MM-dd HH:mm:ss.fff"
    Description     = "Формат отображения времени в логах"
    Validation      = "string"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @loggingTimeFormatConfig | Register-PSFConfig

Write-PSFMessage -Level Verbose -Message "Конфигурация логирования инициализирована"
