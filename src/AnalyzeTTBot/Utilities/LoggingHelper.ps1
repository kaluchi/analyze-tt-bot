<#
.SYNOPSIS
    Вспомогательные функции для стандартизации логирования.
.DESCRIPTION
    Предоставляет стандартизированные функции для логирования операций,
    ошибок и результатов выполнения с использованием PSFramework.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата создания: 01.04.2025
#>

function Write-OperationStart {
    <#
    .SYNOPSIS
        Логирует начало операции.
    .DESCRIPTION
        Записывает информацию о начале операции в лог с использованием PSFramework.
    .PARAMETER Operation
        Название операции.
    .PARAMETER Target
        Целевой объект операции (опционально).
    .PARAMETER FunctionName
        Имя функции, из которой выполняется логирование. По умолчанию определяется автоматически.
    .EXAMPLE
        Write-OperationStart -Operation "Downloading video" -Target "https://example.com/video.mp4"
        Логирует начало операции скачивания видео.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $false)]
        [string]$Target,
        
        [Parameter(Mandatory = $false)]
        [string]$FunctionName = (Get-PSCallStack)[0].Command
    )
    
    $message = "Starting operation: $Operation"
    if ($Target) {
        $message += " on $Target"
    }
    
    Write-PSFMessage -Level Verbose -FunctionName $FunctionName -Message $message
}

function Write-OperationSucceeded {
    <#
    .SYNOPSIS
        Логирует успешное завершение операции.
    .DESCRIPTION
        Записывает информацию об успешном завершении операции в лог с использованием PSFramework.
    .PARAMETER Operation
        Название операции.
    .PARAMETER Details
        Дополнительные детали об операции (опционально).
    .PARAMETER FunctionName
        Имя функции, из которой выполняется логирование. По умолчанию определяется автоматически.
    .EXAMPLE
        Write-OperationSucceeded -Operation "Downloading video" -Details "Downloaded 10MB in 5 seconds"
        Логирует успешное завершение операции скачивания видео с дополнительными деталями.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $false)]
        [string]$Details,
        
        [Parameter(Mandatory = $false)]
        [string]$FunctionName = (Get-PSCallStack)[0].Command
    )
    
    $message = "Operation succeeded: $Operation"
    if ($Details) {
        $message += ". $Details"
    }
    
    Write-PSFMessage -Level Verbose -FunctionName $FunctionName -Message $message
}

function Write-OperationFailed {
    <#
    .SYNOPSIS
        Логирует неудачное завершение операции.
    .DESCRIPTION
        Записывает информацию о неудачном завершении операции в лог с использованием PSFramework.
    .PARAMETER Operation
        Название операции.
    .PARAMETER ErrorMessage
        Сообщение об ошибке (опционально).
    .PARAMETER ErrorRecord
        Объект ErrorRecord (опционально).
    .PARAMETER FunctionName
        Имя функции, из которой выполняется логирование. По умолчанию определяется автоматически.
    .EXAMPLE
        Write-OperationFailed -Operation "Downloading video" -ErrorMessage "Network error" -ErrorRecord $_
        Логирует неудачное завершение операции скачивания видео с информацией об ошибке.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory = $false)]
        [string]$FunctionName = (Get-PSCallStack)[0].Command
    )
    
    $message = "Operation failed: $Operation"
    
    if (-not [string]::IsNullOrEmpty($ErrorMessage)) {
        $message += ". $ErrorMessage"
    }
    
    if ($null -ne $ErrorRecord) {
        Write-PSFMessage -Level Warning -FunctionName $FunctionName -Message $message -ErrorRecord $ErrorRecord
    } else {
        Write-PSFMessage -Level Warning -FunctionName $FunctionName -Message $message
    }
}

function Write-OperationProgress {
    <#
    .SYNOPSIS
        Логирует прогресс операции.
    .DESCRIPTION
        Записывает информацию о прогрессе операции в лог с использованием PSFramework.
    .PARAMETER Operation
        Название операции.
    .PARAMETER Progress
        Информация о прогрессе операции.
    .PARAMETER FunctionName
        Имя функции, из которой выполняется логирование. По умолчанию определяется автоматически.
    .EXAMPLE
        Write-OperationProgress -Operation "Downloading video" -Progress "50% complete"
        Логирует прогресс операции скачивания видео.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [string]$Progress,
        
        [Parameter(Mandatory = $false)]
        [string]$FunctionName = (Get-PSCallStack)[0].Command
    )
    
    $message = "Operation progress: $Operation - $Progress"
    
    Write-PSFMessage -Level Verbose -FunctionName $FunctionName -Message $message
}

function Get-SanitizedLogMessage {
    <#
    .SYNOPSIS
        Очищает сообщение от конфиденциальных данных перед логированием.
    .DESCRIPTION
        Удаляет или маскирует конфиденциальные данные (токены, пароли и т.д.) в сообщении перед логированием.
    .PARAMETER Message
        Исходное сообщение для очистки.
    .EXAMPLE
        $cleanMessage = Get-SanitizedLogMessage -Message "Using token: 1234567890abcdef"
        Очищает сообщение от токена перед логированием.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    # Список паттернов для маскирования
    $patterns = @(
        # Telegram Bot Token
        @{
            Pattern = '\d+:[A-Za-z0-9_-]{35,}'
            Replacement = '[TELEGRAM_TOKEN]'
        },
        # API Key: value формат
        @{
            Pattern = '(API Key:|api[_\-]?key|token|secret|password|pass)[\s:="'']+([A-Za-z0-9_\-\.]{5,})'
            Replacement = '$1 [REDACTED]'
        },
        # apikey=value формат
        @{
            Pattern = '(api[_\-]?key|token|secret|password|pass)=([A-Za-z0-9_\-\.]{5,})'
            Replacement = '$1=[REDACTED]'
        },
        # URL с учетными данными
        @{
            Pattern = '(https?://)[^:]+:[^@]+@'
            Replacement = '$1[USER]:[PASSWORD]@'
        }
    )
    
    # Применяем каждый паттерн
    $sanitizedMessage = $Message
    foreach ($p in $patterns) {
        $sanitizedMessage = $sanitizedMessage -replace $p.Pattern, $p.Replacement
    }
    
    return $sanitizedMessage
}

function Write-PSFMessageSafe {
    <#
    .SYNOPSIS
        Безопасно логирует сообщение с использованием PSFramework.
    .DESCRIPTION
        Очищает сообщение от конфиденциальных данных и логирует его с использованием PSFramework.
    .PARAMETER Level
        Уровень логирования.
    .PARAMETER Message
        Сообщение для логирования.
    .PARAMETER FunctionName
        Имя функции, из которой выполняется логирование. По умолчанию определяется автоматически.
    .PARAMETER Target
        Целевой объект логирования (опционально).
    .PARAMETER ErrorRecord
        Объект ErrorRecord (опционально).
    .EXAMPLE
        Write-PSFMessageSafe -Level Verbose -Message "Using token: 1234567890abcdef"
        Безопасно логирует сообщение, очищая его от конфиденциальных данных.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSFramework.Message.MessageLevel]$Level,
        
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$FunctionName = (Get-PSCallStack)[0].Command,
        
        [Parameter(Mandatory = $false)]
        [object]$Target,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    
    # Очищаем сообщение от конфиденциальных данных
    $sanitizedMessage = Get-SanitizedLogMessage -Message $Message
    
    # Логируем очищенное сообщение
    if ($null -ne $ErrorRecord) {
        Write-PSFMessage -Level $Level -Message $sanitizedMessage -FunctionName $FunctionName -Target $Target -ErrorRecord $ErrorRecord
    } else {
        Write-PSFMessage -Level $Level -Message $sanitizedMessage -FunctionName $FunctionName -Target $Target
    }
}
