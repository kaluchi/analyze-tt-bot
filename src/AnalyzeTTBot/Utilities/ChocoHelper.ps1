<#
.SYNOPSIS
    Вспомогательные функции для работы с пакетным менеджером Chocolatey.
.DESCRIPTION
    Предоставляет стандартизированные функции для получения списка установленных
    пакетов и устаревших пакетов из Chocolatey.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата создания: 22.04.2025
#>

function Get-Choco-List {
    <#
    .SYNOPSIS
        Получает список установленных пакетов Chocolatey.
    .DESCRIPTION
        Запускает команду 'choco list' и парсит результат, возвращая массив
        объектов с информацией об установленных пакетах.
    .EXAMPLE
        $packages = Get-Choco-List
        Получает список всех установленных пакетов Chocolatey.
    .OUTPUTS
        System.Management.Automation.PSObject[]
        Массив объектов со свойствами:
        - Name: Имя пакета
        - Version: Версия пакета
    #>
    [CmdletBinding()]
    param()
    
    Write-PSFMessage -Level Verbose -FunctionName "Get-Choco-List" -Message "Getting list of installed Chocolatey packages"
    
    try {
        # Выполняем команду choco list
        $result = Invoke-ExternalProcess -ExecutablePath "choco" -ArgumentList @("list") -TimeoutSeconds 30
        
        if (-not $result.Success) {
            Write-PSFMessage -Level Warning -FunctionName "Get-Choco-List" -Message "Failed to get package list. Error: $($result.Error)"
            return @()
        }
        
        # Разбираем вывод
        $packages = @()
        $lines = $result.Output -split "`r?`n"
        
        foreach ($line in $lines) {
            # Пропускаем строки с информацией о Chocolatey и итоговую строку
            if ($line -match '^Chocolatey v' -or 
                $line -match '^\d+ packages? installed\.$' -or
                [string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            # Парсим строки формата "packageName version"
            if ($line -match '^([^\s]+)\s+([^\s]+)$') {
                $packages += [PSCustomObject]@{
                    Name = $matches[1]
                    Version = $matches[2]
                }
            }
        }
        
        Write-PSFMessage -Level Verbose -FunctionName "Get-Choco-List" -Message "Found $($packages.Count) installed packages"
        return $packages
    }
    catch {
        Write-PSFMessage -Level Error -FunctionName "Get-Choco-List" -Message "Exception while getting package list: $_"
        return @()
    }
}

function Get-Choco-Outdated {
    <#
    .SYNOPSIS
        Получает список устаревших пакетов Chocolatey.
    .DESCRIPTION
        Запускает команду 'choco outdated' и парсит результат, возвращая массив
        объектов с информацией об устаревших пакетах и доступных обновлениях.
    .EXAMPLE
        $outdatedPackages = Get-Choco-Outdated
        Получает список всех устаревших пакетов Chocolatey.
    .OUTPUTS
        System.Management.Automation.PSObject[]
        Массив объектов со свойствами:
        - Name: Имя пакета
        - CurrentVersion: Текущая установленная версия
        - AvailableVersion: Доступная версия для обновления
        - Pinned: Закреплен ли пакет (true/false)
    #>
    [CmdletBinding()]
    param()
    
    Write-PSFMessage -Level Verbose -FunctionName "Get-Choco-Outdated" -Message "Getting list of outdated Chocolatey packages"
    
    try {
        # Выполняем команду choco outdated
        $result = Invoke-ExternalProcess -ExecutablePath "choco" -ArgumentList @("outdated") -TimeoutSeconds 30
        
        if (-not $result.Success) {
            Write-PSFMessage -Level Warning -FunctionName "Get-Choco-Outdated" -Message "Failed to get outdated packages. Error: $($result.Error)"
            return @()
        }
        
        # Разбираем вывод
        $outdatedPackages = @()
        $lines = $result.Output -split "`r?`n"
        $startParsing = $false
        
        foreach ($line in $lines) {
            # Начинаем парсинг после строки с заголовками
            if ($line -match 'Output is package name \| current version \| available version \| pinned\?') {
                $startParsing = $true
                continue
            }
            
            # Пропускаем строки до начала парсинга и итоговую строку
            if (-not $startParsing -or 
                $line -match '^Chocolatey has determined' -or
                $line -match '^Chocolatey v' -or
                $line -match '^Outdated Packages$' -or
                [string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            # Парсим строки формата "packageName|currentVersion|availableVersion|pinned"
            if ($line -match '^([^\|]+)\|([^\|]+)\|([^\|]+)\|([^\|]+)$') {
                $outdatedPackages += [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    CurrentVersion = $matches[2].Trim()
                    AvailableVersion = $matches[3].Trim()
                    Pinned = [bool]::Parse($matches[4].Trim())
                }
            }
        }
        
        Write-PSFMessage -Level Verbose -FunctionName "Get-Choco-Outdated" -Message "Found $($outdatedPackages.Count) outdated packages"
        return $outdatedPackages
    }
    catch {
        Write-PSFMessage -Level Error -FunctionName "Get-Choco-Outdated" -Message "Exception while getting outdated packages: $_"
        return @()
    }
}
