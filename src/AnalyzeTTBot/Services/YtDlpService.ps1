<#
.SYNOPSIS
    Сервис для работы с утилитой yt-dlp.
.DESCRIPTION
    Предоставляет функциональность для скачивания видео с TikTok и других платформ с использованием yt-dlp.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.3.0
    Обновлено: 03.04.2025 - Переименован из TikTokDownloaderService и расширена функциональность
#>
class YtDlpService : IYtDlpService {
    [string]$YtDlpPath
    [IFileSystemService]$FileSystemService
    [int]$TimeoutSeconds
    [string]$DefaultFormat
    [string]$CookiesPath
    
    YtDlpService(
        [string]$ytDlpPath,
        [IFileSystemService]$fileSystemService,
        [int]$timeoutSeconds,
        [string]$defaultFormat,
        [string]$cookiesPath
    ) {
        $this.YtDlpPath = $ytDlpPath
        $this.FileSystemService = $fileSystemService
        $this.TimeoutSeconds = $timeoutSeconds
        $this.DefaultFormat = $defaultFormat
        $this.CookiesPath = $cookiesPath
        
        Write-OperationSucceeded -Operation "YtDlpService initialization" -Details "yt-dlp path: $ytDlpPath" -FunctionName "YtDlpService.Constructor"
    }
[hashtable] SaveTikTokVideo([string]$url, [string]$outputPath = "") {
        # Валидация входных параметров и подготовка среды
        if ([string]::IsNullOrWhiteSpace($url)) {
            Write-OperationFailed -Operation "Save TikTok video" -ErrorMessage "Empty URL provided" -FunctionName "SaveTikTokVideo"
            return New-ErrorResponse -ErrorMessage "Empty URL provided"
        }
        
        # Проверка формата URL
        if (-not [uri]::IsWellFormedUriString($url, [System.UriKind]::Absolute)) {
            $errorMessage = "Invalid URL format: $url"
            Write-OperationFailed -Operation "Save TikTok video" -ErrorMessage $errorMessage -FunctionName "SaveTikTokVideo"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
        
        # Устанавливаем выходной путь (если не указан, создаем временный)
        $outputPath = $this.GetOutputPath($outputPath)
        
        # Подготавливаем директорию
        $outputDir = Split-Path -Parent $outputPath
        $dirResult = $this.FileSystemService.EnsureFolderExists($outputDir)
        
        if (-not $dirResult.Success) {
            $errorMessage = "Failed to create output directory: $outputDir. Error: $($dirResult.Error)"
            Write-OperationFailed -Operation "Save TikTok video" -ErrorMessage $errorMessage -FunctionName "SaveTikTokVideo"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
        
        Write-OperationStart -Operation "Download TikTok video" -Target "$url to $outputPath" -FunctionName "SaveTikTokVideo"
        
        try {
            # Скачиваем видео
            $downloadResult = $this.ExecuteYtDlp($url, $outputPath)
            
            if (-not $downloadResult.Success) {
                return $downloadResult
            }
            
            # Обработка метаданных
            $metadataResult = $this.ProcessMetadata($url, $outputPath)
            
            # Проверка наличия выходного файла
            if (-not (Test-Path -Path $metadataResult.FilePath)) {
                $errorMessage = "Failed to get file path. Output file does not exist: $($metadataResult.FilePath)"
                Write-OperationFailed -Operation "Download TikTok video" -ErrorMessage $errorMessage -FunctionName "SaveTikTokVideo"
                $errorData = @{
                    InputUrl = $url
                    OutputPath = $outputPath
                }
                return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
            }
            
            Write-OperationSucceeded -Operation "Download TikTok video" -Details "File: $($metadataResult.FilePath), Author: $($metadataResult.AuthorUsername)" -FunctionName "SaveTikTokVideo"
            
            # Собираем итоговый результат
            $resultData = @{
                FilePath = $metadataResult.FilePath
                JsonFilePath = $metadataResult.JsonFilePath
                JsonContent = $metadataResult.JsonContent
                AuthorUsername = $metadataResult.AuthorUsername
                VideoTitle = $metadataResult.VideoTitle
                FullVideoUrl = $metadataResult.FullVideoUrl
                InputUrl = $url
                OutputPath = $outputPath
            }
            
            return New-SuccessResponse -Data $resultData
        } catch {
            $errorMessage = "Failed to download video: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Download TikTok video" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "SaveTikTokVideo"
            
            # Возвращаем информацию об ошибке в стандартизированном формате
            $errorData = @{
                InputUrl = $url
                OutputPath = $outputPath
                Exception = $_
            }
            
            return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
        }
    }
    
    # Метод для получения пути вывода
    [string] GetOutputPath([string]$outputPath) {
        if (-not [string]::IsNullOrWhiteSpace($outputPath)) {
            return $outputPath
        }
        
        return $this.FileSystemService.NewTempFileName(".mp4")
    }
    
    # Метод для выполнения yt-dlp
    [hashtable] ExecuteYtDlp([string]$url, [string]$outputPath) {
        Write-OperationStart -Operation "Execute yt-dlp" -Target "$url to $outputPath" -FunctionName "ExecuteYtDlp"
        
        try {
            # Подготавливаем аргументы для yt-dlp
            $arguments = @(
                "--format", $this.DefaultFormat,
                "--output", $outputPath,
                "--no-playlist",
                "--write-info-json",
                "--no-warnings",
                "--no-check-certificate",  # Отключаем проверку SSL сертификата для работы с proxy
                $url
            )
            
            # Добавляем cookies если путь указан и файл существует
            if (-not [string]::IsNullOrWhiteSpace($this.CookiesPath) -and (Test-Path $this.CookiesPath)) {
                $arguments += @("--cookies", $this.CookiesPath)
                Write-PSFMessage -Level Debug -FunctionName "ExecuteYtDlp" -Message "Using cookies file: $($this.CookiesPath)"
            }
            
            # Запускаем yt-dlp через ProcessHelper
            $result = Invoke-ExternalProcess -ExecutablePath $this.YtDlpPath -ArgumentList $arguments -TimeoutSeconds $this.TimeoutSeconds
            
            if (-not $result.Success) {
                $errorLines = $result.Output | Where-Object { $_ -match "ERROR:" } | ForEach-Object { $_ -replace "ERROR:", "" } | ForEach-Object { $_.Trim() }
                $errorMessage = ($errorLines -join "`n").Trim()
                if ([string]::IsNullOrWhiteSpace($errorMessage)) {
                    $errorMessage = "yt-dlp process failed with exit code $($result.ExitCode)"
                }
                Write-OperationFailed -Operation "Execute yt-dlp" -ErrorMessage $errorMessage -FunctionName "ExecuteYtDlp"
                $errorData = @{
                    RawOutput = $result.Output
                    Error = $result.Error
                    InputUrl = $url
                }
                return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
            }
            
            # Проверяем наличие ошибок в выводе
            $errorLines = $result.Output | Where-Object { $_ -match "ERROR:" }
            if ($errorLines.Count -gt 0) {
                $errorMessage = $errorLines -join "; "
                Write-OperationFailed -Operation "Execute yt-dlp" -ErrorMessage $errorMessage -FunctionName "ExecuteYtDlp"
                $errorData = @{
                    RawOutput = $result.Output
                    InputUrl = $url
                }
                return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
            }
            
            Write-OperationSucceeded -Operation "Execute yt-dlp" -Details "Downloaded to $outputPath" -FunctionName "ExecuteYtDlp"
            
            $resultData = @{
                RawOutput = $result.Output
                OutputPath = $outputPath
            }
            return New-SuccessResponse -Data $resultData
        } catch {
            $errorMessage = "Failed to execute yt-dlp: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Execute yt-dlp" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "ExecuteYtDlp"
            $errorData = @{
                Exception = $_
                InputUrl = $url
            }
            return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
        }
    }
    
    # Метод для обработки метаданных
    [hashtable] ProcessMetadata([string]$url, [string]$outputPath) {
        Write-OperationStart -Operation "Process metadata" -Target "$url" -FunctionName "ProcessMetadata"
        
        try {
            # Инициализируем структуру результата
            $result = @{
                FilePath = $outputPath
                JsonFilePath = ""
                JsonContent = $null
                AuthorUsername = ""
                VideoTitle = ""
                FullVideoUrl = $url
            }
            
            # Находим и читаем JSON-файл с метаданными
            $jsonPaths = $this.GetPossibleJsonPaths($outputPath)
            $jsonResult = $this.FindAndReadJsonMetadata($jsonPaths, $url)
            
            $result.JsonFilePath = $jsonResult.JsonFilePath
            $result.JsonContent = $jsonResult.JsonContent
            
            # Извлекаем информацию из JSON или создаем по умолчанию
            $extractedInfo = $this.ExtractVideoInfo($jsonResult.JsonContent, $url)
            
            $result.AuthorUsername = $extractedInfo.AuthorUsername
            $result.VideoTitle = $extractedInfo.VideoTitle
            $result.FullVideoUrl = $extractedInfo.FullVideoUrl
            
            # Определяем фактический путь к видеофайлу
            if ($jsonResult.JsonContent -and $jsonResult.JsonContent._filename) {
                $result.FilePath = $jsonResult.JsonContent._filename
                Write-PSFMessage -Level Debug -FunctionName "ProcessMetadata" -Message "Found output file path from JSON metadata: $($result.FilePath)"
            } else {
                # Если файл не существует, попробуем найти его
                if (-not [System.IO.File]::Exists($result.FilePath)) {
                    $foundFile = $this.FindOutputFile($outputPath)
                    if ($foundFile) {
                        $result.FilePath = $foundFile
                    }
                }
            }
            
            Write-OperationSucceeded -Operation "Process metadata" -Details "Author: $($result.AuthorUsername), Title: $($result.VideoTitle)" -FunctionName "ProcessMetadata"
            
            return $result
        } catch {
            $errorMessage = "Failed to process metadata: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Process metadata" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "ProcessMetadata"
            $errorData = @{
                Exception = $_
                FilePath = $outputPath
            }
            return New-ErrorResponse -ErrorMessage $errorMessage -Data $errorData
        }
    }
    
    # Метод для получения возможных путей к JSON
    [string[]] GetPossibleJsonPaths([string]$outputPath) {
        $jsonFilePath = "$outputPath.info.json"
        $jsonFilePathAlternative = [System.IO.Path]::Combine(
            [System.IO.Path]::GetDirectoryName($outputPath),
            [System.IO.Path]::GetFileNameWithoutExtension($outputPath) + ".info.json"
        )
        
        return @($jsonFilePath, $jsonFilePathAlternative)
    }
    
    # Метод для поиска и чтения метаданных JSON
    [hashtable] FindAndReadJsonMetadata([string[]]$jsonPaths, [string]$url) {
        # Логируем пути для поиска
        foreach ($path in $jsonPaths) {
            Write-PSFMessage -Level Debug -FunctionName "FindAndReadJsonMetadata" -Message "Looking for JSON file: $path"
        }
        
        # Даем yt-dlp время для завершения записи файла
        # Start-Sleep -Milliseconds 500
        
        # Ищем среди возможных путей первый существующий файл
        $jsonFilePath = ""
        foreach ($path in $jsonPaths) {
            if (Test-Path -Path $path -PathType Leaf) {
                $jsonFilePath = $path
                Write-PSFMessage -Level Debug -FunctionName "FindAndReadJsonMetadata" -Message "Found JSON file: $jsonFilePath"
                break
            }
        }
        
        # Если JSON-файл не найден, создаем базовый
        if ([string]::IsNullOrEmpty($jsonFilePath)) {
            $jsonFilePath = $jsonPaths[0]  # Используем первый путь как основной
            $baseJsonContent = $this.CreateBaseJsonContent($url, $jsonPaths[0])
            
            # Используем JsonHelper для записи JSON
            Write-JsonFile -Path $jsonFilePath -InputObject $baseJsonContent -Force
            Write-PSFMessage -Level Debug -FunctionName "FindAndReadJsonMetadata" -Message "Created base JSON file with extracted information"
            
            return @{
                JsonFilePath = $jsonFilePath
                JsonContent = $baseJsonContent
            }
        }
        
        # Читаем существующий JSON-файл
        $jsonContent = Read-JsonFile -Path $jsonFilePath
        
        if ($null -eq $jsonContent) {
            Write-PSFMessage -Level Warning -FunctionName "FindAndReadJsonMetadata" -Message "Failed to read JSON metadata file"
            
            # В случае ошибки чтения, создаем базовый JSON
            $baseJsonContent = $this.CreateBaseJsonContent($url, $jsonPaths[0])
            return @{
                JsonFilePath = $jsonFilePath
                JsonContent = $baseJsonContent
            }
        }
        
        Write-PSFMessage -Level Debug -FunctionName "FindAndReadJsonMetadata" -Message "Successfully read JSON metadata file"
        
        return @{
            JsonFilePath = $jsonFilePath
            JsonContent = $jsonContent
        }
    }
    
    # Метод для создания базового JSON с минимальной информацией
    [hashtable] CreateBaseJsonContent([string]$url, [string]$outputPath) {
        $username = $this.ExtractUsernameFromUrl($url)
        
        return @{
            "_filename" = $outputPath
            "uploader" = $username
            "uploader_id" = $username
            "webpage_url" = $url
            "title" = "TikTok video" + $(if($username) {" by $username"} else {""})
        }
    }
    
    # Метод для извлечения имени пользователя из URL
    [string] ExtractUsernameFromUrl([string]$url) {
        if ($url -match '[https://]*(?:www\.)?tiktok\.com/@([^/]+)') {
            return $matches[1]
        }
        
        return ""
    }
    
    # Метод для извлечения информации о видео из JSON
    [hashtable] ExtractVideoInfo($jsonContent, [string]$url) {
        $authorUsername = ""
        $videoTitle = ""
        $fullVideoUrl = $url
        
        if ($null -ne $jsonContent) {
            # Извлекаем имя автора по приоритету полей
            if ($jsonContent.uploader) {
                $authorUsername = $jsonContent.uploader
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Found author from JSON metadata: $authorUsername"
            } elseif ($jsonContent.uploader_id) {
                $authorUsername = $jsonContent.uploader_id
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Found author ID from JSON metadata: $authorUsername"
            } elseif ($jsonContent.creator) {
                $authorUsername = $jsonContent.creator
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Found creator from JSON metadata: $authorUsername"
            } elseif ($jsonContent.channel -or $jsonContent.channel_id) {
                $authorUsername = if ($jsonContent.channel) { $jsonContent.channel } else { $jsonContent.channel_id }
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Found channel from JSON metadata: $authorUsername"
            } elseif ($jsonContent.extractor_key -eq "TikTok" -and $jsonContent.id -match "^(?:video/)?([\d]+)") {
                $authorUsername = "TikTokUser_$($matches[1])"
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Using TikTok ID as username: $authorUsername"
            }
            
            # Извлекаем заголовок видео
            if ($jsonContent.title) {
                $videoTitle = $jsonContent.title
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Found title from JSON metadata: $videoTitle"
            }
            
            # Получаем полный URL видео
            if ($jsonContent.webpage_url) {
                $fullVideoUrl = $jsonContent.webpage_url
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Found full video URL from JSON metadata: $fullVideoUrl"
            }
        }
        
        # Если имя автора по-прежнему не найдено, пытаемся извлечь из URL
        if ([string]::IsNullOrWhiteSpace($authorUsername) -or $authorUsername -eq "NA" -or $authorUsername -eq "na") {
            if ($fullVideoUrl -match '@([^/?&]+)') {
                $authorUsername = $matches[1]
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Extracted author from URL: $authorUsername"
            } else {
                $authorUsername = "TikTokUser" # Общее значение по умолчанию
                Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Using default author: $authorUsername"
            }
        }
        
        # Для сокращенных URL, используем полную версию
        if ($url -match 'vm\.tiktok\.com' -and $jsonContent -and $jsonContent.webpage_url) {
            $fullVideoUrl = $jsonContent.webpage_url
            Write-PSFMessage -Level Debug -FunctionName "ExtractVideoInfo" -Message "Using full video URL from JSON for shortened URL: $fullVideoUrl"
        }
        
        return @{
            AuthorUsername = $authorUsername
            VideoTitle = $videoTitle
            FullVideoUrl = $fullVideoUrl
        }
    }
    
    # Метод для поиска выходного файла, если он не находится по основному пути
    [string] FindOutputFile([string]$outputPath) {
        $directory = [System.IO.Path]::GetDirectoryName($outputPath)
        $filePattern = [System.IO.Path]::GetFileNameWithoutExtension($outputPath) + "*"
        
        Write-PSFMessage -Level Debug -FunctionName "FindOutputFile" -Message "Output file does not exist: $outputPath"
        
        # Проверяем существование каталога
        if (-not (Test-Path -Path $directory)) {
            Write-PSFMessage -Level Warning -FunctionName "FindOutputFile" -Message "Output directory does not exist: $directory"
            return ""
        }
        
        Write-PSFMessage -Level Debug -FunctionName "FindOutputFile" -Message "Searching for recent files in: $directory with pattern: $filePattern"
        
        # Ищем недавно созданные файлы с подходящим паттерном и медиа-расширением
        $recentFiles = Get-ChildItem -Path $directory -Filter $filePattern | 
            Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-2) -and $_.Extension -match "\.mp4|\.webm|\.mov|\.mkv" } | 
            Sort-Object LastWriteTime -Descending
        
        if ($recentFiles.Count -gt 0) {
            $filePath = $recentFiles[0].FullName
            Write-PSFMessage -Level Debug -FunctionName "FindOutputFile" -Message "Found recently created file: $filePath"
            return $filePath
        }
        
        Write-PSFMessage -Level Warning -FunctionName "FindOutputFile" -Message "No matching files found in directory"
        return ""
    }

    [hashtable] UpdateYtDlp() {
        Write-OperationStart -Operation "Update yt-dlp" -FunctionName "UpdateYtDlp"
        
        try {
            # Используем ProcessHelper для запуска yt-dlp с параметром обновления
            $result = Invoke-ExternalProcess -ExecutablePath $this.YtDlpPath -ArgumentList @("-U") -TimeoutSeconds 60
            
            if (-not $result.Success) {
                $errorMessage = "Process failed with exit code $($result.ExitCode): $($result.Error)"
                Write-OperationFailed -Operation "Update yt-dlp" -ErrorMessage $errorMessage -FunctionName "UpdateYtDlp"
                return New-ErrorResponse -ErrorMessage $errorMessage
            }
            
            # Проверяем вывод на наличие сообщения об обновлении
            if ($result.Output -match "yt-dlp is up to date" -or $result.Output -match "Updated yt-dlp") {
                $updateResult = @{
                    Status = "Success"
                    Message = $result.Output.Trim()
                    IsUpToDate = $result.Output -match "yt-dlp is up to date"
                }
                Write-OperationSucceeded -Operation "Update yt-dlp" -Details $result.Output.Trim() -FunctionName "UpdateYtDlp"
                return New-SuccessResponse -Data $updateResult
            } else {
                $errorMessage = "Unexpected output from yt-dlp update: $($result.Output.Trim())"
                Write-OperationFailed -Operation "Update yt-dlp" -ErrorMessage $errorMessage -FunctionName "UpdateYtDlp"
                return New-ErrorResponse -ErrorMessage $errorMessage
            }
        } catch {
            $errorMessage = "Failed to update yt-dlp: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Update yt-dlp" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "UpdateYtDlp"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
    
    [hashtable] CheckUpdates() {
        Write-OperationStart -Operation "Check yt-dlp updates" -FunctionName "CheckUpdates"
        
        try {
            # Получаем список доступных версий через pip index versions
            $pipIndex = Invoke-ExternalProcess -ExecutablePath "pip" -ArgumentList @("index", "versions", "yt-dlp") -TimeoutSeconds 15
            if (-not $pipIndex.Success) {
                $errorMessage = "Не удалось получить список версий yt-dlp через pip index: $($pipIndex.Error)"
                Write-OperationFailed -Operation "Check yt-dlp updates" -ErrorMessage $errorMessage -FunctionName "CheckUpdates"
                return New-ErrorResponse -ErrorMessage $errorMessage
            }
            
            # Инициализируем переменные
            $currentVersion = $null
            $latestVersion = $null
            $needsUpdate = $false
            
            # Обрабатываем вывод pip index, выделяя только нужные строки
            Write-PSFMessage -Level Debug -FunctionName "CheckUpdates" -Message "Processing pip index output for yt-dlp"
            $pipOutput = $pipIndex.Output | ForEach-Object { $_.Trim() }
            
            # Объединяем весь вывод в одну строку для обработки случаев, когда вывод приходит в одной строке
            $fullOutput = $pipOutput -join " "
            
            # ОТЛАДОЧНЫЙ ВЫВОД ДЛЯ ДЕБАГА ПАРСИНГА ВЕРСИЙ
            Write-PSFMessage -Level Debug -FunctionName "CheckUpdates" -Message "Full output: $fullOutput"
            
            # Ищем INSTALLED и LATEST в объединенном выводе
            if ($fullOutput -match 'INSTALLED:\s*([^\s]+)' -and $fullOutput -match 'LATEST:\s*([^\s]+)') {
                $currentVersion = $matches[1].Trim() # Из первого match (INSTALLED)
                # Нужно заново выполнить match для LATEST, так как $matches перезаписывается
                if ($fullOutput -match 'LATEST:\s*([^\s]+)') {
                    $latestVersion = $matches[1].Trim()
                } else {
                    $errorMessage = "Не удалось извлечь последнюю версию из объединенного вывода: $fullOutput"
                    Write-OperationFailed -Operation "Check yt-dlp updates" -ErrorMessage $errorMessage -FunctionName "CheckUpdates"
                    return New-ErrorResponse -ErrorMessage $errorMessage
                }
                
                # Извлекаем INSTALLED версию отдельно для надежности
                if ($fullOutput -match 'INSTALLED:\s*([^\s]+)') {
                    $currentVersion = $matches[1].Trim()
                } else {
                    $errorMessage = "Не удалось извлечь установленную версию из объединенного вывода: $fullOutput"
                    Write-OperationFailed -Operation "Check yt-dlp updates" -ErrorMessage $errorMessage -FunctionName "CheckUpdates"
                    return New-ErrorResponse -ErrorMessage $errorMessage
                }
                Write-PSFMessage -Level Debug -FunctionName "CheckUpdates" -Message "currentVersion: $currentVersion"
                Write-PSFMessage -Level Debug -FunctionName "CheckUpdates" -Message "latestVersion: $latestVersion"
                $needsUpdate = $currentVersion -ne $latestVersion
                Write-PSFMessage -Level Debug -FunctionName "CheckUpdates" -Message "Needs update: $needsUpdate (Current: $currentVersion, Latest: $latestVersion)"
                Write-OperationSucceeded -Operation "Check yt-dlp updates" -Details "Проверка обновлений выполнена" -FunctionName "CheckUpdates"
                return New-SuccessResponse -Data @{
                    CurrentVersion = $currentVersion
                    NewVersion = $latestVersion
                    NeedsUpdate = $needsUpdate
                }
            } else {
                $errorMessage = "Не удалось определить текущую или последнюю версию yt-dlp из вывода pip index"
                Write-OperationFailed -Operation "Check yt-dlp updates" -ErrorMessage $errorMessage -FunctionName "CheckUpdates"
                return New-ErrorResponse -ErrorMessage $errorMessage
            }
        } catch {
            $errorMessage = "Failed to check yt-dlp updates: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Check yt-dlp updates" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "CheckUpdates"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
    
    [hashtable] TestYtDlpInstallation([switch]$SkipCheckUpdates = $false) {
        Write-OperationStart -Operation "Test yt-dlp installation" -FunctionName "TestYtDlpInstallation"
        
        try {
            # Проверяем существование и работоспособность yt-dlp напрямую через вызов команды
            $result = Invoke-ExternalProcess -ExecutablePath $this.YtDlpPath -ArgumentList @("--version") -TimeoutSeconds 10
            
            if ($result.Success) {
                # Успешно запустили yt-dlp и получили версию
                $versionStr = $result.Output.Trim()
                Write-OperationSucceeded -Operation "Test yt-dlp installation" -Details "Version $versionStr detected" -FunctionName "TestYtDlpInstallation"
                
                # Проверка обновлений, если не указан флаг пропуска
                $checkUpdatesResult = $null
                if (-not $SkipCheckUpdates) {
                    $updatesCheck = $this.CheckUpdates()
                    if ($updatesCheck.Success) {
                        $checkUpdatesResult = $updatesCheck.Data
                        Write-PSFMessage -Level Debug -FunctionName "TestYtDlpInstallation" -Message "CheckUpdates result: NeedsUpdate=$($checkUpdatesResult.NeedsUpdate), NewVersion=$($checkUpdatesResult.NewVersion)"
                    }
                }
                
                $testResult = @{
                    Name = "yt-dlp"
                    Valid = $true
                    Version = $versionStr
                    Description = "Version $versionStr detected"
                    CheckUpdatesResult = $checkUpdatesResult
                    SkipCheckUpdates = $SkipCheckUpdates
                }
                
                return New-SuccessResponse -Data $testResult
            } else {
                # Команда вернула ошибку
                $errorMsg = "yt-dlp returned error (code $($result.ExitCode)): $($result.Error)"
                Write-OperationFailed -Operation "Test yt-dlp installation" -ErrorMessage $errorMsg -FunctionName "TestYtDlpInstallation"
                
                $testResult = @{
                    Name = "yt-dlp"
                    Valid = $false
                    Version = $null
                    Description = $errorMsg
                }
                
                return New-ErrorResponse -ErrorMessage $errorMsg
            }
        }
        catch {
            # Общая ошибка при выполнении
            $errorMsg = "Failed to test yt-dlp: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Test yt-dlp installation" -ErrorMessage $errorMsg -ErrorRecord $_ -FunctionName "TestYtDlpInstallation"
            
            return New-ErrorResponse -ErrorMessage $errorMsg
        }
    }
}
