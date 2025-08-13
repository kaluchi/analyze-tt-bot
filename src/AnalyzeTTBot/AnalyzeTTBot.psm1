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

# Импортируем PSFramework
try {
    # Проверяем наличие модуля
    if (-not (Get-Module -Name PSFramework -ListAvailable)) {
        Write-Warning "PSFramework не установлен. Попытка установки..."
        Install-Module -Name PSFramework -AllowClobber -Scope CurrentUser
    }
    
    # Импортируем модуль
    Import-Module -Name PSFramework -ErrorAction Stop
    Write-PSFMessage -Level Debug -Message "PSFramework успешно импортирован"
    
}
catch {
    Write-Error "Не удалось импортировать PSFramework: $_"
    throw "Критическая ошибка при импорте PSFramework"
}

# Определяем путь к корневой директории модуля
$script:ModuleRoot = $PSScriptRoot
Write-PSFMessage -Level Debug -Message "Корневая директория модуля: $script:ModuleRoot" 


# Загружаем интерфейсы с помощью dot-sourcing
Write-PSFMessage -Level Debug -Message  "Загрузка интерфейсов..." 

# Используем прямой dot-sourcing как рекомендовано в памятке
Get-ChildItem -Path "$script:ModuleRoot\Interfaces" -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
    try {
        Write-PSFMessage -Level Debug -Message  "  Загрузка интерфейса: $($_.Name)" 
        . $_.FullName
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Ошибка загрузки интерфейса $($_.Name): $_"
        throw $_
    }
}

# Загружаем все утилиты
Write-PSFMessage -Level Debug -Message "Загрузка утилит..." 
Get-ChildItem -Path "$script:ModuleRoot\Utilities" -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
    try {
        Write-PSFMessage -Level Debug -Message "  Загрузка утилиты: $($_.Name)" 
        . $_.FullName
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Ошибка загрузки утилиты $($_.Name): $_"
    }
}

# Загружаем контейнер зависимостей
Write-PSFMessage -Level Debug -Message "Загрузка контейнера зависимостей..." 
Get-ChildItem -Path "$script:ModuleRoot\Factories" -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
    try {
        Write-PSFMessage -Level Debug -Message  "  Загрузка контейнера: $($_.Name)" 
        . $_.FullName
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Ошибка загрузки контейнера $($_.Name): $_"
        throw $_
    }
}

# Загружаем сервисы
Write-PSFMessage -Level Debug -Message  "Загрузка сервисов..." 
Get-ChildItem -Path "$script:ModuleRoot\Services" -Filter "*.ps1" | Sort-Object Name | ForEach-Object {
    try {
        Write-PSFMessage -Level Debug -Message "  Загрузка сервиса: $($_.Name)"
        . $_.FullName
    }
    catch {
        Write-PSFMessage -Level Critical -Message "Ошибка загрузки сервиса $($_.Name): $_"
        throw $_
    }
}


# Инициализация модуля
try {
    # Централизованная инициализация конфигурации (встроенно из Initialize-Configuration.ps1)
    
    # Определяем директорию конфигурации
    $configDir = "$script:ModuleRoot\Config"
    
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
        
        # Встроенная логика загрузки конфигурационного файла
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
    
    # Информация о результате инициализации конфигурации
    $configInitResult = [PSCustomObject]@{
        ConfigFilesLoaded = $loadedConfigs
        DebugMode = $debugMode
    }
    
    # Регистрируем сервисы в контейнере зависимостей
    $registered = Register-DependencyServices -ClearContainer
    
    if (-not $registered) {
        Write-PSFMessage -Level Critical -Message "Ошибка при регистрации сервисов."
        throw "Ошибка инициализации модуля AnalyzeTTBot"
    }
    
    Write-PSFMessage -Level Host -Message "Модуль AnalyzeTTBot успешно инициализирован."
}
catch {
    Write-PSFMessage -Level Critical -Message "Не удалось инициализировать модуль: $_"
    exit 1
}


# Функция для запуска бота
function Start-AnalyzeTTBot {
    <#
    .SYNOPSIS
        Запускает TikTok бота для анализа видео.
    .DESCRIPTION
        Функция запускает бота для анализа TikTok видео с использованием
        обновленной системы конфигурации и инициализации.
    .PARAMETER DebugMode
        Запускает бота в режиме отладки.
    .PARAMETER ValidateOnly
        Только проверяет зависимости без запуска бота.
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
    
    # Получаем экземпляр бота из контейнера
    $botService = Get-DependencyService -ServiceType "IBotService"
    
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
    Write-PSFMessage -Level Host  -Message "Запуск бота..." 
    $botService.Start($false)
}
