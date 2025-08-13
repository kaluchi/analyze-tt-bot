<#
.SYNOPSIS
    Модуль AnalyzeTTBot для анализа видео с TikTok.
.DESCRIPTION
    Модуль предоставляет функциональность для анализа видео с TikTok,
    включая скачивание, извлечение метаданных, форматирование и отправку через Telegram.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 2025
#>

#region Module Initialization


# Определяем путь к корневой директории модуля
Write-PSFMessage -Level Debug -Message "Корневая директория модуля: $PSScriptRoot" 

# Загружаем компоненты модуля
$componentPaths = @(
    @{ Path = "Interfaces"; Name = "интерфейсов" },
    @{ Path = "Utilities"; Name = "утилит" },
    @{ Path = "Services"; Name = "сервисов" }
)

foreach ($component in $componentPaths) {
    $fullPath = Join-Path -Path $PSScriptRoot -ChildPath $component.Path
    
    if (Test-Path -Path $fullPath) {
        Write-PSFMessage -Level Debug -Message "Загрузка $($component.Name)..." 
        
        Get-ChildItem -Path $fullPath -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
            try {
                Write-PSFMessage -Level Debug -Message "  Загрузка $($component.Name.TrimEnd('в','х','й')): $($_.Name)" 
                . $_.FullName
            }
            catch {
                Write-PSFMessage -Level Critical -Message "Ошибка загрузки $($_.Name): $_"
                throw $_
            }
        }
    }
    else {
        Write-PSFMessage -Level Warning -Message "Директория $($component.Path) не найдена"
    }
}

# Минимальная инициализация модуля
try {
    Write-PSFMessage -Level Debug -Message "Модуль AnalyzeTTBot загружен. Готов к созданию экземпляров бота."
}
catch {
    Write-PSFMessage -Level Critical -Message "Не удалось инициализировать модуль: $_"
    exit 1
}
#endregion

#region Private Functions
function Initialize-BotConfiguration {
    <#
    .SYNOPSIS
        Инициализирует конфигурацию бота.
    .DESCRIPTION
        Загружает конфигурационные файлы и настраивает провайдеры логирования.
    .OUTPUTS
        [PSCustomObject] Результат инициализации конфигурации.
    #>
    [CmdletBinding()]
    param()
    
    # Определяем директорию конфигурации
    $configDir = Join-Path -Path $PSScriptRoot -ChildPath "Config"
    
    # Создаем массив конфигурационных файлов в порядке загрузки
    $configFiles = @(
        "LoggingConfig.ps1",     # Сначала инициализируем логирование
        "TelegramConfig.ps1",    # Затем основные компоненты
        "MediaConfig.ps1",
        "YtDlpConfig.ps1"
    )
    
    # Загружаем базовые конфигурационные файлы
    $loadedConfigs = @()
    foreach ($configFile in $configFiles) {
        $configFilePath = Join-Path -Path $configDir -ChildPath $configFile
        
        if (Test-Path -Path $configFilePath) {
            try {
                Write-PSFMessage -Level Debug -Message "Загрузка конфигурации: $configFilePath"
                . $configFilePath
                $loadedConfigs += $configFile
            }
            catch {
                Write-PSFMessage -Level Debug -Message "Ошибка при загрузке конфигурационного файла $configFilePath : $_"
            }
        }
        else {
            Write-PSFMessage -Level Debug -Message "Файл конфигурации не найден: $configFilePath"
        }
    }
    
    Write-PSFMessage -Level Debug -Message "Загружено $($loadedConfigs.Count) из $($configFiles.Count) конфигурационных файлов"
    
    # Регистрация провайдера логирования
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
        Write-PSFMessage -Level Debug -Message "Логирование отключено в конфигурации"
    }
    
    # Возвращаем результат инициализации
    return [PSCustomObject]@{
        ConfigFilesLoaded = $loadedConfigs
        LoggingEnabled = $loggingEnabled
        DebugMode = $DebugPreference -ne "SilentlyContinue"
    }
}

function New-BotServices {
    <#
    .SYNOPSIS
        Создает экземпляры всех сервисов бота.
    .DESCRIPTION
        Создает и настраивает все необходимые сервисы для работы бота.
    .OUTPUTS
        [BotService] Экземпляр основного сервиса бота.
    #>
    [CmdletBinding()]
    param()
    
    Write-PSFMessage -Level Verbose -Message "Создание сервисов приложения"
    
    # Сначала создаем FileSystemService, так как другие сервисы зависят от него
    $fileSystemService = [FileSystemService]::new(
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.Temp.Folder")
    )
    
    # Создаем остальные сервисы
    $telegramService = [TelegramService]::new(
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.Telegram.Token"),
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.MaxFileSize")
    )
    
    $ytDlpService = [YtDlpService]::new(
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.Path"),
        $fileSystemService,
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.Timeout"),
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.Format"),
        (Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.CookiesPath")
    )
    
    # Создаем специализированные сервисы для анализа медиа
    $mediaInfoExtractorService = [MediaInfoExtractorService]::new($fileSystemService)
    $mediaFormatterService = [MediaFormatterService]::new()
    $hashtagGeneratorService = [HashtagGeneratorService]::new()
    
    # Создаем основной сервис бота
    $botService = [BotService]::new(
        $telegramService,
        $ytDlpService,
        $mediaInfoExtractorService,
        $mediaFormatterService,
        $hashtagGeneratorService,
        $fileSystemService
    )
    
    return $botService
}
#endregion

#region Public Functions
function Create-AnalyzeTTBot {
    <#
    .SYNOPSIS
        Создает экземпляр бота AnalyzeTTBot.
    .DESCRIPTION
        Инициализирует конфигурацию, создает сервисы и возвращает экземпляр BotService.
    .OUTPUTS
        [BotService] Экземпляр основного сервиса бота.
    .EXAMPLE
        $botService = Create-AnalyzeTTBot
        $botService.Start()
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Инициализируем конфигурацию
        $configResult = Initialize-BotConfiguration
        
        if ($configResult.DebugMode) {
            Write-PSFMessage -Level Debug -Message "Активирован режим отладки в конфигурации"
        }
        
        # Создаем сервисы
        $botService = New-BotServices
        
        Write-PSFMessage -Level Host -Message "Модуль AnalyzeTTBot успешно инициализирован."
        
        return $botService
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Не удалось создать экземпляр бота: $_"
        throw
    }
}

function Start-AnalyzeTTBot {
    <#
    .SYNOPSIS
        Запускает TikTok бота для анализа видео.
    .DESCRIPTION
        Функция создает экземпляр бота и запускает его для анализа TikTok видео.
    .PARAMETER DebugMode
        Запускает бота в режиме отладки.
    .PARAMETER ValidateOnly
        Только проверяет зависимости без запуска бота.
    .PARAMETER SkipCheckUpdates
        Пропускает проверку обновлений.
    .EXAMPLE
        Start-AnalyzeTTBot -ValidateOnly
        Проверяет зависимости без запуска бота.
    .EXAMPLE
        Start-AnalyzeTTBot
        Запускает бота в обычном режиме.
    .EXAMPLE
        Start-AnalyzeTTBot -DebugMode
        Запускает бота в режиме отладки.
    #>
    [CmdletBinding()]
    param (
        [switch]$DebugMode,
        [switch]$ValidateOnly,
        [switch]$SkipCheckUpdates
    )
    
    # Создаем экземпляр бота
    $botService = Create-AnalyzeTTBot
    
    # Всегда выполняем проверку зависимостей и выводим результат
    $result = $botService.TestDependencies($false, $SkipCheckUpdates) 
    $botService.ShowDependencyValidationResults($result)
    
    # Если режим только валидации, завершаем работу
    if ($ValidateOnly) {
        return
    }
    
    # Если зависимости не прошли проверку, выводим сообщение и завершаем работу
    if (-not $result.Data.AllValid) {
        Write-PSFMessage -Level Critical -Message "Невозможно запустить бота из-за проблем с зависимостями. Исправьте указанные выше проблемы и попробуйте снова."
        return
    }
    
    # Запускаем бота
    Write-PSFMessage -Level Host -Message "Запуск бота..." 
    $botService.Start($false)
}
#endregion