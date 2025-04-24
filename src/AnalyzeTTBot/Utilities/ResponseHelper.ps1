<#
.SYNOPSIS
    Вспомогательные функции для работы с ответами сервисов.
.DESCRIPTION
    Предоставляет функции для создания стандартизированных ответов сервисов.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 05.04.2025
#>

function New-ServiceResponse {
    <#
    .SYNOPSIS
        Создает стандартизированный ответ сервиса.
    .DESCRIPTION
        Создает хэштаблицу с полями Success, Data и Error для стандартизации ответов сервисов.
    .PARAMETER Success
        Флаг успешности операции.
    .PARAMETER Data
        Данные, возвращаемые сервисом.
    .PARAMETER ErrorMessage
        Сообщение об ошибке (если операция не успешна).
    .OUTPUTS
        System.Collections.Hashtable - Стандартизированный ответ сервиса.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [bool]$Success,
        
        [Parameter(Mandatory=$false)]
        $Data = $null,
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = $null
    )
    
    return @{
        Success = $Success
        Data = $Data
        Error = $ErrorMessage
    }
}

function New-SuccessResponse {
    <#
    .SYNOPSIS
        Создает успешный ответ сервиса.
    .DESCRIPTION
        Создает хэштаблицу с полями Success=true, Data и Error=null.
    .PARAMETER Data
        Данные, возвращаемые сервисом.
    .OUTPUTS
        System.Collections.Hashtable - Стандартизированный успешный ответ сервиса.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        $Data = $null
    )
    
    return New-ServiceResponse -Success $true -Data $Data
}

function New-ErrorResponse {
    <#
    .SYNOPSIS
        Создает ответ сервиса с ошибкой.
    .DESCRIPTION
        Создает хэштаблицу с полями Success=false, Data и Error.
    .PARAMETER ErrorMessage
        Сообщение об ошибке.
    .PARAMETER Data
        Дополнительные данные, связанные с ошибкой.
    .OUTPUTS
        System.Collections.Hashtable - Стандартизированный ответ сервиса с ошибкой.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage,
        
        [Parameter(Mandatory=$false)]
        $Data = $null
    )
    
    return New-ServiceResponse -Success $false -ErrorMessage $ErrorMessage -Data $Data
}

# Export-ModuleMember -Function New-SuccessResponse
# Export-ModuleMember -Function New-ErrorResponse
