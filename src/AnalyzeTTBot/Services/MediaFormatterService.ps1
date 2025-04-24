<#
.SYNOPSIS
    Сервис для форматирования информации о медиафайлах.
.DESCRIPTION
    Предоставляет функциональность для форматирования технических характеристик видео в удобный для чтения формат.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>
class MediaFormatterService : IMediaFormatterService {
    
    MediaFormatterService() {
        Write-OperationSucceeded -Operation "MediaFormatterService initialization" -FunctionName "MediaFormatterService.Constructor"
    }
    
    [hashtable] FormatMediaInfo([hashtable]$mediaInfoResponse, [string]$authorUsername, [string]$videoUrl, [string]$fullVideoUrl, [string]$filePath = "", [string]$videoTitle = "") { # Игнорируем параметр videoTitle, чтобы избежать отображения пути к файлу в отчете
        Write-OperationStart -Operation "Format media info" -FunctionName "FormatMediaInfo"
        
        # Используем ResponseHelper для создания стандартизированных ответов
        
        # Проверяем наличие данных
        if (-not $mediaInfoResponse.Success) {
            Write-OperationFailed -Operation "Format media info" -ErrorMessage $mediaInfoResponse.Error -FunctionName "FormatMediaInfo"
            return New-ServiceResponse -Success $false -ErrorMessage "❌ Error: $($mediaInfoResponse.Error)"
        }
        
        $mediaInfo = $mediaInfoResponse.Data;
        # Создаем отчет с нуля
        $report = ""
        
        # 1. Добавляем ссылку
        if (-not [string]::IsNullOrWhiteSpace($fullVideoUrl) -and $videoUrl -ne $fullVideoUrl) {
            $linkHtml = "🔗 Link: <a href='$fullVideoUrl'>$videoUrl</a>"
            $report += $linkHtml + "`n"
        } else {
            $report += "🔗 Link: $videoUrl`n"
        }
        
        # 2. Добавляем автора
        if (-not [string]::IsNullOrWhiteSpace($authorUsername) -and $authorUsername -ne "NA" -and $authorUsername -ne "na") {
            $profileUrl = "https://www.tiktok.com/@$authorUsername"
            $authorHtml = "👤 Author: <a href='$profileUrl'>@$authorUsername</a>"
            $report += $authorHtml + "`n"
        } elseif (-not [string]::IsNullOrWhiteSpace($authorUsername)) {
            $report += "👤 Author: @$authorUsername`n"
        }
        
        # 3. Секция видео
        $report += "`n🎬 VIDEO`n"
        
        # Разрешение
        if ($mediaInfo.Width -gt 0 -and $mediaInfo.Height -gt 0) {
            $report += "Resolution: $($mediaInfo.Width) x $($mediaInfo.Height)`n"
        } else {
            $report += "Resolution: Unknown`n"
        }
        
        # FPS
        if ($mediaInfo.FPS -gt 0) {
            $report += "FPS: $($mediaInfo.FPS)`n"
        } else {
            $report += "FPS: Unknown`n"
        }
        
        # Битрейт видео
        if ($mediaInfo.VideoBitRateFormatted -and $mediaInfo.VideoBitRateFormatted -ne "Unknown") {
            $report += "Bitrate: $($mediaInfo.VideoBitRateFormatted.Replace('kbps', 'kb/s'))`n"
        }
        
        # Кодек видео
        if ($mediaInfo.VideoCodec -and $mediaInfo.VideoCodec -ne "Unknown") {
            $report += "Codec: $($mediaInfo.VideoCodec)`n"
        } else {
            $report += "Codec: Unknown`n"
        }
        
        # 4. Секция аудио
        $report += "`n"
        
        if ($mediaInfo.HasAudio) {
            $report += "🔊 AUDIO`n"
            
            # Формат аудио
            $audioFormat = $mediaInfo.AudioCodec
            if ($mediaInfo.AudioCodec -eq "AAC") {
                $audioFormat = "AAC LC SBR PS (AAC)"
            }
            $report += "Format: $audioFormat`n"
            
            # Битрейт аудио
            if ($mediaInfo.AudioBitRateFormatted -and $mediaInfo.AudioBitRateFormatted -ne "Unknown") {
                $report += "Bitrate: $($mediaInfo.AudioBitRateFormatted.Replace('kbps', 'kb/s'))`n"
            }
            
            # Каналы
            if ($mediaInfo.AudioChannels -gt 0) {
                $report += "Channels: $($mediaInfo.AudioChannels)`n"
            }
            
            # Частота дискретизации
            if ($mediaInfo.AudioSampleRateFormatted -and $mediaInfo.AudioSampleRateFormatted -ne "Unknown") {
                $report += "Sampling Rate: $($mediaInfo.AudioSampleRateFormatted)`n"
            }
        }
        
        # 5. Общая информация
        $report += "`n📁 General information:`n"
        
        # Длительность
        if ($mediaInfo.Duration -and $mediaInfo.Duration -ne "Unknown") {
            $durationSeconds = [math]::Floor([float]$mediaInfo.Duration)
            $durationMilliseconds = [math]::Round(([float]$mediaInfo.Duration - $durationSeconds) * 1000)
            $report += "Duration: $durationSeconds s $durationMilliseconds ms`n"
        } elseif ($mediaInfo.DurationFormatted -and $mediaInfo.DurationFormatted -ne "Unknown") {
            $report += "Duration: $($mediaInfo.DurationFormatted)`n"
        } else {
            $report += $this.GetEstimatedDurationString($mediaInfo)
        }
        
        # Размер файла
        if ($mediaInfo.FileSize -gt 0) {
            if ($mediaInfo.FileSize -lt 1MB) {
                $fileSizeKiB = [math]::Round($mediaInfo.FileSize / 1KB, 0)
                $fileSizeKiBStr = $fileSizeKiB.ToString("N0").Replace(",", " ")
                $report += "File Size: $fileSizeKiBStr KiB`n"
            } else {
                $fileSizeMB = [math]::Round($mediaInfo.FileSizeMB * 1024) / 1024
                $fileSizeMBStr = $fileSizeMB.ToString("N3").Replace(",", " ")
                $report += "File Size: $fileSizeMBStr MB`n"
            }
        } else {
            $report += "File Size: Unknown`n"
        }
        
        Write-OperationSucceeded -Operation "Format media info" -FunctionName "FormatMediaInfo"
        return New-ServiceResponse -Success $true -Data $report
    }
    
    # Выделенный метод для получения строки расчетной длительности
    [string] GetEstimatedDurationString([hashtable]$mediaInfo) {
        $videoBitRate = $mediaInfo.VideoBitRate
        $audioBitRate = $mediaInfo.AudioBitRate
        
        if ($videoBitRate -le 0) { $videoBitRate = 500000 }
        if ($audioBitRate -le 0) { $audioBitRate = 64000 }
        
        $totalBitRate = $videoBitRate + $audioBitRate
        
        if ($mediaInfo.FileSize -gt 0 -and $totalBitRate -gt 0) {
            $fileSizeBits = $mediaInfo.FileSize * 8
            $estimatedDuration = $fileSizeBits / $totalBitRate
            
            $seconds = [math]::Floor($estimatedDuration)
            $milliseconds = [math]::Round(($estimatedDuration - $seconds) * 1000)
            
            return "Duration: $seconds s $milliseconds ms`n"
        } else {
            return "Duration: 15 s 0 ms`n"
        }
    }
}
