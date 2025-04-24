<#
.SYNOPSIS
    Сервис для извлечения технической информации из медиафайлов.
.DESCRIPTION
    Предоставляет функциональность для анализа и извлечения технических характеристик видео с использованием MediaInfo.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Дата: 05.04.2025
    Обновлено: Стандартизация формата ответов
#>
class MediaInfoExtractorService : IMediaInfoExtractorService {
    [IFileSystemService]$FileSystemService
    
    MediaInfoExtractorService([IFileSystemService]$fileSystemService) {
        $this.FileSystemService = $fileSystemService
        
        Write-OperationSucceeded -Operation "MediaInfoExtractorService initialization" -FunctionName "MediaInfoExtractorService.Constructor"
    }
    
    [hashtable] GetMediaInfo([string]$filePath) {
        Write-OperationStart -Operation "Analyze media file" -Target $filePath -FunctionName "GetMediaInfo"
        
        # Раннее завершение при отсутствии файла
        if (-not (Test-Path -Path $filePath)) {
            Write-OperationFailed -Operation "Analyze media file" -ErrorMessage "File not found: $filePath" -FunctionName "GetMediaInfo"
            return New-ErrorResponse -ErrorMessage "File not found: $filePath"
        }
        

        
        try {
            # Используем ProcessHelper для запуска MediaInfo
            $result = Invoke-ExternalProcess -ExecutablePath "mediainfo" -ArgumentList @("--Output=JSON", "$filePath")
            
            # Проверяем результат выполнения
            if (-not $result.success) {
                $errorMessage = "MediaInfo failed with exit code $($result.ExitCode): $($result.Error)"
                Write-OperationFailed -Operation "Run MediaInfo" -ErrorMessage $errorMessage -FunctionName "GetMediaInfo"
                return New-ErrorResponse -ErrorMessage $errorMessage
            }
            
            # Получаем вывод MediaInfo
            $output = $result.Output
            
            # Проверка на пустой вывод - раннее завершение
            if ([string]::IsNullOrWhiteSpace($output)) {
                Write-OperationFailed -Operation "Analyze media file" -ErrorMessage "MediaInfo returned empty output" -FunctionName "GetMediaInfo"
                return New-ErrorResponse -ErrorMessage "MediaInfo returned empty output"
            }
            
            # Используем JsonHelper для безопасного парсинга JSON
            $mediaInfo = ConvertFrom-JsonSafe -Json $output -Depth 10
            
            if ($null -eq $mediaInfo) {
                Write-OperationFailed -Operation "Parse MediaInfo output" -ErrorMessage "Failed to parse MediaInfo JSON output" -FunctionName "GetMediaInfo"
                return New-ErrorResponse -ErrorMessage "Failed to parse MediaInfo output"
            }
            
            # Извлекаем нужные данные
            $videoTrack = $mediaInfo.media.track | Where-Object { $_.'@type' -eq "Video" -or $_.type -eq "Video" } | Select-Object -First 1
            $audioTrack = $mediaInfo.media.track | Where-Object { $_.'@type' -eq "Audio" -or $_.type -eq "Audio" } | Select-Object -First 1
            $generalTrack = $mediaInfo.media.track | Where-Object { $_.'@type' -eq "General" -or $_.type -eq "General" } | Select-Object -First 1
            
            # Проверяем наличие необходимых треков - раннее завершение
            if (-not $generalTrack -or -not $videoTrack) {
                $missing = if ($generalTrack) { "Video track" } elseif ($videoTrack) { "General track" } else { "General and Video tracks" }
                Write-OperationFailed -Operation "Analyze media file" -ErrorMessage "No $missing found in the media file" -FunctionName "GetMediaInfo"
                return New-ErrorResponse -ErrorMessage "Unable to analyze video: No $missing found in MediaInfo output"
            }
            
            # Логируем найденные треки для отладки
            $audioTrackFormat = if ($audioTrack) { $audioTrack.Format } else { 'None' }
            Write-PSFMessage -Level Debug -FunctionName "GetMediaInfo" -Message "General track: $($generalTrack.Format), Video track: $($videoTrack.Format), Audio track: $audioTrackFormat"
            
            # Создаем результат с извлеченными данными
            $mediaInfoData = $this.CreateMediaInfoResult($generalTrack, $videoTrack, $audioTrack)
            
            # Проверяем на подозрительные значения
            if ($mediaInfoData.Width -eq 0 -or $mediaInfoData.Height -eq 0 -or $mediaInfoData.FPS -eq 0) {
                Write-PSFMessage -Level Warning -FunctionName "GetMediaInfo" -Message "Suspicious media info values: Width=$($mediaInfoData.Width), Height=$($mediaInfoData.Height), FPS=$($mediaInfoData.FPS)"
            }
            
            Write-OperationSucceeded -Operation "Analyze media file" -Details "Resolution: $($mediaInfoData.Width)x$($mediaInfoData.Height), FPS: $($mediaInfoData.FPS)" -FunctionName "GetMediaInfo"
            
            return New-SuccessResponse -Data $mediaInfoData
        } catch {
            $errorMessage = $_.Exception.Message
            Write-OperationFailed -Operation "Analyze media file" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "GetMediaInfo"
            return New-ErrorResponse -ErrorMessage $errorMessage -Data @{ exception = $_.Exception.Message }
        }
    }
    
    # Выделенный метод для создания структуры с результатами анализа медиа
    [hashtable] CreateMediaInfoResult($generalTrack, $videoTrack, $audioTrack) {
        # Преобразуем строковые числа в числовые значения, где это необходимо
        $videoWidth = if ($videoTrack.Width) { [int]$videoTrack.Width } else { 0 }
        $videoHeight = if ($videoTrack.Height) { [int]$videoTrack.Height } else { 0 }
        $videoBitRate = if ($videoTrack.BitRate) { [int]$videoTrack.BitRate } else { 0 }
        $videoFPS = if ($videoTrack.FrameRate) { [float]$videoTrack.FrameRate } else { 0 }
        $videoFrameCount = if ($videoTrack.FrameCount) { [int]$videoTrack.FrameCount } else { 0 }
        
        $fileSize = if ($generalTrack.FileSize) { [long]$generalTrack.FileSize } else { 0 }
        $fileSizeMB = if ($fileSize -gt 0) { [math]::Round($fileSize / 1MB, 2) } else { 0 }
        
        # Формируем результат
        $result = @{
            FileSize = $fileSize
            FileSizeMB = $fileSizeMB
            Duration = $generalTrack.Duration
            DurationFormatted = $generalTrack.Duration_String3
            Width = $videoWidth
            Height = $videoHeight
            AspectRatio = "$($videoWidth):$($videoHeight)"
            FPS = [int]$videoFPS
            FrameCount = $videoFrameCount
            VideoCodec = $videoTrack.Format
            VideoProfile = $videoTrack.Format_Profile
            VideoBitRate = $videoBitRate
            VideoBitRateFormatted = if ($videoBitRate -gt 0) { "$([math]::Round($videoBitRate / 1000, 0)) kbps" } else { "Unknown" }
            HasAudio = ($audioTrack -ne $null)
        }
        
        # Добавляем информацию об аудио, если оно есть
        if ($audioTrack) {
            $audioBitRate = if ($audioTrack.BitRate) { [int]$audioTrack.BitRate } else { 0 }
            $audioSampleRate = if ($audioTrack.SamplingRate) { [int]$audioTrack.SamplingRate } else { 0 }
            
            $result.AudioCodec = $audioTrack.Format
            $result.AudioChannels = if ($audioTrack.Channels) { [int]$audioTrack.Channels } else { 0 }
            $result.AudioBitRate = $audioBitRate
            $result.AudioBitRateFormatted = if ($audioBitRate -gt 0) { "$([math]::Round($audioBitRate / 1000, 0)) kbps" } else { "Unknown" }
            $result.AudioSampleRate = $audioSampleRate
            $result.AudioSampleRateFormatted = if ($audioSampleRate -gt 0) { "$([math]::Round($audioSampleRate / 1000, 1)) kHz" } else { "Unknown" }
        }
        
        return $result
    }
    
    [hashtable] CheckUpdates() {
        Write-OperationStart -Operation "Check MediaInfo updates" -FunctionName "CheckUpdates"
        
        try {
            # Получаем список устаревших пакетов через ChocoHelper
            $outdatedPackages = Get-Choco-Outdated
            
            # Ищем mediainfo-cli в списке устаревших пакетов
            $mediaInfoOutdated = $outdatedPackages | Where-Object { $_.Name -eq "mediainfo-cli" }
            
            # Формируем результат
            $result = @{
                NewVersion = $null
                NeedsUpdate = $false
                CurrentVersion = $null
            }
            
            if ($mediaInfoOutdated) {
                $result.NewVersion = $mediaInfoOutdated.AvailableVersion
                $result.CurrentVersion = $mediaInfoOutdated.CurrentVersion
                $result.NeedsUpdate = $true
                
                $details = "MediaInfo update available: $($mediaInfoOutdated.CurrentVersion) -> $($mediaInfoOutdated.AvailableVersion)"
                Write-OperationSucceeded -Operation "Check MediaInfo updates" -Details $details -FunctionName "CheckUpdates"
            } else {
                # Если mediainfo-cli не в списке устаревших, значит он актуален
                # Получаем текущую версию из списка установленных пакетов
                $installedPackages = Get-Choco-List
                $mediaInfoInstalled = $installedPackages | Where-Object { $_.Name -eq "mediainfo-cli" }
                
                if ($mediaInfoInstalled) {
                    $result.CurrentVersion = $mediaInfoInstalled.Version
                    $details = "MediaInfo is up to date: $($mediaInfoInstalled.Version)"
                } else {
                    $details = "MediaInfo is not installed via Chocolatey"
                }
                
                Write-OperationSucceeded -Operation "Check MediaInfo updates" -Details $details -FunctionName "CheckUpdates"
            }
            
            return New-SuccessResponse -Data $result
        }
        catch {
            $errorMessage = "Failed to check MediaInfo updates: $($_.Exception.Message)"
            Write-OperationFailed -Operation "Check MediaInfo updates" -ErrorMessage $errorMessage -ErrorRecord $_ -FunctionName "CheckUpdates"
            
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
    
    [hashtable] TestMediaInfoDependency([switch]$SkipCheckUpdates = $false) {
        try {
            # Выполняем команду для проверки наличия MediaInfo через ProcessHelper
            $result = Invoke-ExternalProcess -ExecutablePath "mediainfo" -ArgumentList @("--version")
            
            $mediaInfoValid = $false
            $mediaInfoVersion = "Не найден"
            
            if ($result.Success) {
                $output = $result.Output
                # Ищем версию вида vXX.XX или vXX.XX.X
                if ($output -match "v[0-9]+(\.[0-9]+)+") {
                    $mediaInfoValid = $true
                    $mediaInfoVersion = $matches[0]
                } elseif ($output -match "MediaInfo[\w\s-]*([0-9]+\.[0-9]+(\.[0-9]+)?)") {
                    $mediaInfoValid = $true
                    $mediaInfoVersion = $matches[1]
                } elseif ($output -match "([0-9]+\.[0-9]+(\.[0-9]+)?)") {
                    $mediaInfoValid = $true
                    $mediaInfoVersion = $matches[1]
                } else {
                    $mediaInfoValid = $false
                    $mediaInfoVersion = "Не найден"
                }
            }
            
            # Проверка обновлений, если не указан флаг пропуска
            $checkUpdatesResult = $null
            if ($mediaInfoValid -and -not $SkipCheckUpdates) {
                $updatesCheck = $this.CheckUpdates()
                if ($updatesCheck.Success) {
                    $checkUpdatesResult = $updatesCheck.Data
                }
            }

            $result = @{
                Name = "MediaInfo"
                Valid = $mediaInfoValid
                Version = $mediaInfoVersion
                Description = if ($mediaInfoValid) { "MediaInfo $mediaInfoVersion найден" } else { "MediaInfo не найден или не работает" }
                CheckUpdatesResult = $checkUpdatesResult
                SkipCheckUpdates = $SkipCheckUpdates
            }
            
            return New-SuccessResponse -Data $result
        } catch {
            $errorResult = @{
                Name = "MediaInfo"
                Valid = $false
                Version = "Неизвестно"
                Description = "Ошибка при проверке MediaInfo: $_"
            }
            return New-ErrorResponse -ErrorMessage "Ошибка при проверке MediaInfo: $_" -Data $errorResult
        }
    }
}
