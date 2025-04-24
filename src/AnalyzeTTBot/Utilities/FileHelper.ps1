<#
.SYNOPSIS
    Вспомогательные функции для работы с файловой системой.
.DESCRIPTION
    Предоставляет стандартизированные функции для работы с файлами, директориями,
    временными файлами и прочими операциями с файловой системой.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата создания: 01.04.2025
#>

function Test-DirectoryExists {
    <#
    .SYNOPSIS
        Проверяет существование директории и опционально создает ее.
    .DESCRIPTION
        Проверяет существование директории и, при необходимости, создает ее.
        Возвращает $true, если директория существует или была успешно создана.
    .PARAMETER Path
        Путь к проверяемой директории.
    .PARAMETER Create
        Создать директорию, если она не существует.
    .EXAMPLE
        Test-DirectoryExists -Path "C:\Temp\Downloads" -Create
        Проверяет существование директории и создает ее, если она не существует.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$Create
    )
    
    $exists = Test-Path -Path $Path -PathType Container
    
    if (-not $exists -and $Create) {
        try {
            New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-PSFMessage -Level Verbose -FunctionName "Test-DirectoryExists" -Message "Created directory: $Path"
            return $true
        }
        catch {
            Write-PSFMessage -Level Warning -FunctionName "Test-DirectoryExists" -Message "Failed to create directory: $Path. Error: $_"
            return $false
        }
    }
    
    return $exists
}

function New-TemporaryFilePath {
    <#
    .SYNOPSIS
        Создает путь к временному файлу.
    .DESCRIPTION
        Генерирует уникальный путь к временному файлу с заданным расширением и префиксом.
        Не создает сам файл, а только генерирует путь к нему.
    .PARAMETER Extension
        Расширение временного файла. По умолчанию: .tmp
    .PARAMETER Prefix
        Префикс имени временного файла. По умолчанию: temp_
    .PARAMETER Directory
        Директория для временного файла. По умолчанию: системная временная директория.
    .EXAMPLE
        $filePath = New-TemporaryFilePath -Extension ".mp4" -Prefix "tiktok_"
        Создает путь к временному файлу с расширением .mp4 и префиксом tiktok_.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Extension = ".tmp",
        
        [Parameter(Mandatory = $false)]
        [string]$Prefix = "temp_",
        
        [Parameter(Mandatory = $false)]
        [string]$Directory = $env:TEMP
    )
    
    # Убедиться, что расширение начинается с точки
    if (-not [string]::IsNullOrEmpty($Extension) -and -not $Extension.StartsWith('.')) {
        $Extension = ".$Extension"
    }
    
    # Убедиться, что директория существует
    if (-not (Test-Path -Path $Directory -PathType Container)) {
        try {
            New-Item -Path $Directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-PSFMessage -Level Verbose -FunctionName "New-TemporaryFilePath" -Message "Created directory: $Directory"
        }
        catch {
            Write-PSFMessage -Level Warning -FunctionName "New-TemporaryFilePath" -Message "Failed to create directory: $Directory. Error: $_"
            $Directory = $env:TEMP
        }
    }
    
    # Генерировать уникальное имя файла
    $fileName = "$Prefix$(Get-Date -Format 'yyyyMMdd_HHmmss')_$(Get-Random -Maximum 100000)$Extension"
    $filePath = Join-Path -Path $Directory -ChildPath $fileName
    
    Write-PSFMessage -Level Verbose -FunctionName "New-TemporaryFilePath" -Message "Generated temporary file path: $filePath"
    return $filePath
}

function Remove-OldFiles {
    <#
    .SYNOPSIS
        Удаляет старые файлы из указанной директории.
    .DESCRIPTION
        Удаляет файлы из указанной директории, которые старше заданного количества дней.
        Возвращает количество удаленных файлов.
    .PARAMETER Path
        Путь к директории, в которой нужно удалить старые файлы.
    .PARAMETER OlderThanDays
        Количество дней, старше которых файлы будут удалены.
    .PARAMETER Filter
        Фильтр файлов для удаления. По умолчанию: *
    .PARAMETER Recurse
        Рекурсивно удалять файлы в поддиректориях.
    .EXAMPLE
        Remove-OldFiles -Path "C:\Temp\Downloads" -OlderThanDays 7
        Удаляет файлы из директории C:\Temp\Downloads, которые старше 7 дней.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [int]$OlderThanDays,
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = "*",
        
        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )
    
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-PSFMessage -Level Verbose -FunctionName "Remove-OldFiles" -Message "Directory does not exist: $Path"
        return 0
    }
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
        
        $params = @{
            Path = $Path
            Filter = $Filter
            File = $true
            ErrorAction = "SilentlyContinue"
        }
        
        if ($Recurse) {
            $params.Recurse = $true
        }
        
        $oldFiles = Get-ChildItem @params | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        $count = 0
        foreach ($file in $oldFiles) {
            try {
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                $count++
                Write-PSFMessage -Level Debug -FunctionName "Remove-OldFiles" -Message "Removed file: $($file.FullName)"
            }
            catch {
                Write-PSFMessage -Level Warning -FunctionName "Remove-OldFiles" -Message "Failed to remove file: $($file.FullName). Error: $_"
            }
        }
        
        Write-PSFMessage -Level Verbose -FunctionName "Remove-OldFiles" -Message "Removed $count old files from $Path"
        return $count
    }
    catch {
        Write-PSFMessage -Level Warning -FunctionName "Remove-OldFiles" -Message "Error removing old files: $_"
        return 0
    }
}

function Get-FileHash256 {
    <#
    .SYNOPSIS
        Вычисляет SHA256 хеш файла.
    .DESCRIPTION
        Вычисляет SHA256 хеш файла и возвращает его в виде строки.
        Оптимизирован для работы с большими файлами.
    .PARAMETER Path
        Путь к файлу, для которого нужно вычислить хеш.
    .EXAMPLE
        $hash = Get-FileHash256 -Path "C:\Temp\video.mp4"
        Вычисляет SHA256 хеш файла video.mp4.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        Write-PSFMessage -Level Warning -FunctionName "Get-FileHash256" -Message "File not found: $Path"
        return $null
    }
    
    try {
        $hashObj = Get-FileHash -Path $Path -Algorithm SHA256 -ErrorAction Stop
        return $hashObj.Hash.ToLower()
    }
    catch {
        Write-PSFMessage -Level Warning -FunctionName "Get-FileHash256" -Message "Failed to calculate hash for file: $Path. Error: $_"
        return $null
    }
}

function Copy-FileWithProgress {
    <#
    .SYNOPSIS
        Копирует файл с отображением прогресса.
    .DESCRIPTION
        Копирует файл из исходного местоположения в целевое с отображением прогресса.
        Оптимизирован для копирования больших файлов.
    .PARAMETER Source
        Путь к исходному файлу.
    .PARAMETER Destination
        Путь к целевому файлу.
    .PARAMETER BufferSize
        Размер буфера для копирования в байтах. По умолчанию: 4MB.
    .PARAMETER Force
        Перезаписать файл, если он уже существует.
    .EXAMPLE
        Copy-FileWithProgress -Source "C:\Temp\video.mp4" -Destination "D:\Backup\video.mp4"
        Копирует файл video.mp4 из C:\Temp в D:\Backup с отображением прогресса.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        
        [Parameter(Mandatory = $false)]
        [int]$BufferSize = 4MB,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    if (-not (Test-Path -Path $Source -PathType Leaf)) {
        Write-PSFMessage -Level Warning -FunctionName "Copy-FileWithProgress" -Message "Source file not found: $Source"
        return $false
    }
    
    if ((Test-Path -Path $Destination) -and -not $Force) {
        Write-PSFMessage -Level Warning -FunctionName "Copy-FileWithProgress" -Message "Destination file already exists and -Force not specified: $Destination"
        return $false
    }
    
    try {
        # Создаем директорию назначения, если она не существует
        $destDir = Split-Path -Parent $Destination
        if (-not [string]::IsNullOrEmpty($destDir) -and -not (Test-Path -Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        
        # Получаем размер файла
        $sourceFile = Get-Item -Path $Source -ErrorAction Stop
        $fileSize = $sourceFile.Length
        $totalMB = [Math]::Round($fileSize / 1MB, 2)
        
        Write-PSFMessage -Level Verbose -FunctionName "Copy-FileWithProgress" -Message "Copying file: $Source to $Destination (Size: $totalMB MB)"
        
        # Создаем потоки для копирования
        $sourceStream = [System.IO.File]::OpenRead($Source)
        $destStream = [System.IO.File]::Create($Destination)
        
        try {
            $buffer = New-Object byte[] $BufferSize
            $totalBytesRead = 0
            $bytesRead = 0
            
            # Цикл копирования
            do {
                $bytesRead = $sourceStream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $destStream.Write($buffer, 0, $bytesRead)
                    $totalBytesRead += $bytesRead
                    
                    # Отображаем прогресс каждые 5%
                    $progressPercent = [Math]::Round(($totalBytesRead / $fileSize) * 100, 0)
                    if ($progressPercent % 5 -eq 0) {
                        $copyMB = [Math]::Round($totalBytesRead / 1MB, 2)
                        Write-PSFMessage -Level Verbose -FunctionName "Copy-FileWithProgress" -Message "Progress: $progressPercent% ($copyMB MB / $totalMB MB)"
                    }
                }
            } while ($bytesRead -gt 0)
            
            Write-PSFMessage -Level Verbose -FunctionName "Copy-FileWithProgress" -Message "File copied successfully: $Source to $Destination"
            return $true
        }
        finally {
            # Закрываем потоки
            if ($null -ne $sourceStream) { $sourceStream.Dispose() }
            if ($null -ne $destStream) { $destStream.Dispose() }
        }
    }
    catch {
        Write-PSFMessage -Level Warning -FunctionName "Copy-FileWithProgress" -Message "Failed to copy file: $Source to $Destination. Error: $_"
        return $false
    }
}

function Get-FolderSize {
    <#
    .SYNOPSIS
        Вычисляет размер директории.
    .DESCRIPTION
        Вычисляет общий размер всех файлов в директории, опционально рекурсивно.
        Возвращает размер в байтах.
    .PARAMETER Path
        Путь к директории.
    .PARAMETER Recurse
        Рекурсивно вычислять размер файлов в поддиректориях.
    .EXAMPLE
        $size = Get-FolderSize -Path "C:\Temp" -Recurse
        Вычисляет общий размер всех файлов в директории C:\Temp и ее поддиректориях.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )
    
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-PSFMessage -Level Warning -FunctionName "Get-FolderSize" -Message "Directory not found: $Path"
        return 0
    }
    
    try {
        $params = @{
            Path = $Path
            File = $true
            ErrorAction = "SilentlyContinue"
        }
        
        if ($Recurse) {
            $params.Recurse = $true
        }
        
        $size = (Get-ChildItem @params | Measure-Object -Property Length -Sum).Sum
        
        # Если размер не удалось вычислить, используем 0
        if ($null -eq $size) {
            $size = 0
        }
        
        Write-PSFMessage -Level Verbose -FunctionName "Get-FolderSize" -Message "Folder size: $Path = $([Math]::Round($size / 1MB, 2)) MB"
        return $size
    }
    catch {
        Write-PSFMessage -Level Warning -FunctionName "Get-FolderSize" -Message "Failed to calculate folder size: $Path. Error: $_"
        return 0
    }
}

function Get-EnsuredTempPath {
    <#
    .SYNOPSIS
        Получает путь к временной директории, создавая ее при необходимости.
    .DESCRIPTION
        Возвращает путь к временной директории, создавая ее, если она не существует.
        Позволяет создавать вложенные директории в системной временной директории.
    .PARAMETER SubPath
        Путь поддиректории внутри системной временной директории.
    .EXAMPLE
        $tempPath = Get-EnsuredTempPath -SubPath "MyApp\Downloads"
        Получает путь к временной директории %TEMP%\MyApp\Downloads, создавая ее при необходимости.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$SubPath
    )
    
    # Если поддиректория не указана, просто возвращаем системную временную директорию
    if ([string]::IsNullOrEmpty($SubPath)) {
        return $env:TEMP
    }
    
    # Проверяем, является ли путь абсолютным
    if ($SubPath -match '^[A-Za-z]:\\') {
        # Если это абсолютный путь, используем его напрямую
        $fullPath = $SubPath
    } else {
        # Если относительный путь, объединяем с временной директорией
        $fullPath = Join-Path -Path $env:TEMP -ChildPath $SubPath
    }
    
    # Создаем директорию, если она не существует
    if (-not (Test-Path -Path $fullPath -PathType Container)) {
        try {
            New-Item -Path $fullPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-PSFMessage -Level Verbose -FunctionName "Get-EnsuredTempPath" -Message "Created temporary directory: $fullPath"
        }
        catch {
            Write-PSFMessage -Level Warning -FunctionName "Get-EnsuredTempPath" -Message "Failed to create temporary directory: $fullPath. Error: $_"
            return $env:TEMP
        }
    }
    
    return $fullPath
}
