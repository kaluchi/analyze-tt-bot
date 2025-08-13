<#
.SYNOPSIS
    Контейнер зависимостей для инверсии контроля.
.DESCRIPTION
    Предоставляет функциональность для регистрации и получения сервисов.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
#>

# Класс контейнера зависимостей
class DependencyContainer {
    # Словарь зарегистрированных сервисов
    [hashtable]$Services = @{}
    
    # Регистрирует синглтон-сервис
    [void] RegisterSingleton([string]$serviceType, [object]$implementation) {
        $this.Services[$serviceType] = $implementation
        Write-PSFMessage -Level Verbose -FunctionName "DependencyContainer.RegisterSingleton" -Message "Registered service of type $serviceType"
    }
    
    # Получает зарегистрированный сервис
    [object] GetService([string]$serviceType) {
        if ($this.Services.ContainsKey($serviceType)) {
            return $this.Services[$serviceType]
        }
        throw "Service of type $serviceType not registered in the container"
    }
    
    # Проверяет, зарегистрирован ли сервис
    [bool] HasService([string]$serviceType) {
        return $this.Services.ContainsKey($serviceType)
    }
    
    # Очищает все зарегистрированные сервисы
    [void] Clear() {
        $this.Services.Clear()
        Write-PSFMessage -Level Verbose -FunctionName "DependencyContainer.Clear" -Message "Dependency container cleared"
    }
}

# Создаем глобальный экземпляр контейнера
$script:Container = [DependencyContainer]::new()

# Функция для получения сервиса из контейнера
function Get-DependencyService {
    <#
    .SYNOPSIS
        Получает зарегистрированный сервис из контейнера зависимостей.
    .DESCRIPTION
        Получает сервис указанного типа из глобального контейнера зависимостей.
    .PARAMETER ServiceType
        Тип сервиса для получения (имя интерфейса).
    .EXAMPLE
        Get-DependencyService -ServiceType "ITelegramService"
        Получает сервис, реализующий интерфейс ITelegramService.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ServiceType
    )
    
    try {
        return $script:Container.GetService($ServiceType)
    }
    catch {
        Write-PSFMessage -Level Error -FunctionName "Get-DependencyService" -Message "Failed to get service of type $ServiceType : $_"
        throw
    }
}

# Функция для регистрации всех сервисов в контейнере
function Register-DependencyServices {
    <#
    .SYNOPSIS
        Регистрирует все сервисы в контейнере зависимостей.
    .DESCRIPTION
        Создает экземпляры всех сервисов и регистрирует их в глобальном контейнере зависимостей.
    .PARAMETER ClearContainer
        Очищает контейнер перед регистрацией сервисов.
    .EXAMPLE
        Register-DependencyServices
        Регистрирует все сервисы в контейнере зависимостей.
    #>
    [CmdletBinding()]
    param (
        [switch]$ClearContainer
    )
    
    # При необходимости очищаем контейнер
    if ($ClearContainer) {
        $script:Container.Clear()
    }
    
    # Получаем настройки из PSFramework
    # Для токена Telegram используем конфиденциальный подход - не выводим его значение в логи
    $telegramToken = Get-PSFConfigValue -FullName "AnalyzeTTBot.Telegram.Token"
    $tempFolder = Get-PSFConfigValue -FullName "AnalyzeTTBot.Temp.Folder"
    $maxFileSize = Get-PSFConfigValue -FullName "AnalyzeTTBot.MaxFileSize"
    $ytDlpPath = Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.Path"
    $ytDlpTimeout = Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.Timeout"
    $ytDlpFormat = Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.Format"
    $ytDlpCookiesPath = Get-PSFConfigValue -FullName "AnalyzeTTBot.YtDlp.CookiesPath"
    
    Write-PSFMessage -Level Verbose -FunctionName "Register-DependencyServices" -Message "Registering services in the dependency container"
    
    # Создаем и регистрируем сервисы
    try {
        # Сначала создаем FileSystemService, так как другие сервисы зависят от него
        $fileSystemService = [FileSystemService]::new($tempFolder)
        $script:Container.RegisterSingleton("IFileSystemService", $fileSystemService)
        
        # Создаем остальные сервисы
        $telegramService = [TelegramService]::new($telegramToken, $maxFileSize)
        $script:Container.RegisterSingleton("ITelegramService", $telegramService)
        
        $ytDlpService = [YtDlpService]::new($ytDlpPath, $fileSystemService, $ytDlpTimeout, $ytDlpFormat, $ytDlpCookiesPath)
        $script:Container.RegisterSingleton("IYtDlpService", $ytDlpService)
        
        # Создаем новые специализированные сервисы для анализа медиа
        $mediaInfoExtractorService = [MediaInfoExtractorService]::new($fileSystemService)
        $script:Container.RegisterSingleton("IMediaInfoExtractorService", $mediaInfoExtractorService)
        
        $mediaFormatterService = [MediaFormatterService]::new()
        $script:Container.RegisterSingleton("IMediaFormatterService", $mediaFormatterService)
        
        $hashtagGeneratorService = [HashtagGeneratorService]::new()
        $script:Container.RegisterSingleton("IHashtagGeneratorService", $hashtagGeneratorService)
        
        # Создаем основной сервис бота, который зависит от всех остальных сервисов
        $botService = [BotService]::new(
            $telegramService,
            $ytDlpService,
            $mediaInfoExtractorService,
            $mediaFormatterService,
            $hashtagGeneratorService,
            $fileSystemService
        )
        $script:Container.RegisterSingleton("IBotService", $botService)
        
        Write-PSFMessage -Level Important -FunctionName "Register-DependencyServices" -Message "All services registered successfully"
        return $true
    }
    catch {
        Write-PSFMessage -Level Error -FunctionName "Register-DependencyServices" -Message "Failed to register services: $_"
        return $false
    }
}

# Функции будут экспортированы в модуле AnalyzeTTBot.psm1
