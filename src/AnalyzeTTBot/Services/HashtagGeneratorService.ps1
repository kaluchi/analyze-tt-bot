<#
.SYNOPSIS
    Сервис для генерации хэштегов на основе медиаданных.
.DESCRIPTION
    Предоставляет функциональность для создания хэштегов на основе технических характеристик видео.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>
class HashtagGeneratorService : IHashtagGeneratorService {
    
    HashtagGeneratorService() {
        Write-OperationSucceeded -Operation "HashtagGeneratorService initialization" -FunctionName "HashtagGeneratorService.Constructor"
    }
    
    [hashtable] GetVideoHashtags([hashtable]$mediaInfoResponse, [string]$authorUsername) {
        Write-OperationStart -Operation "Generate video hashtags" -FunctionName "GetVideoHashtags"
        
        # Проверяем наличие данных
        if (-not $mediaInfoResponse.Success) {
            Write-OperationFailed -Operation "Generate video hashtags" -ErrorMessage "MediaInfo not successful" -FunctionName "GetVideoHashtags"
            return New-ErrorResponse -ErrorMessage "MediaInfo not successful"  
        }

        $mediaInfo = $mediaInfoResponse.Data   
        
        # Создаем список хэштегов
        $hashtags = @()
        
        # Добавляем хэштег автора, если указан
        if (-not [string]::IsNullOrWhiteSpace($authorUsername) -and $authorUsername -ne "NA" -and $authorUsername -ne "na") {
            $hashtags += "#$authorUsername"
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Added author hashtag: #$authorUsername"
        } else {
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "No valid author username provided: '$authorUsername'"
        }
        
        # Добавляем хэштег FPS
        if ($mediaInfo.FPS -and $mediaInfo.FPS -gt 0) {
            $fpsHashtag = "#$($mediaInfo.FPS)fps"
            $hashtags += $fpsHashtag
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Added FPS hashtag: $fpsHashtag"
        } else {
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Could not generate FPS hashtag: FPS value missing or invalid"
        }
        
        # Добавляем хэштег разрешения
        if ($mediaInfo.Width -and $mediaInfo.Height -and $mediaInfo.Width -gt 0 -and $mediaInfo.Height -gt 0) {
            $resolutionHashtag = "#$($mediaInfo.Width)x$($mediaInfo.Height)"
            $hashtags += $resolutionHashtag
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Added resolution hashtag: $resolutionHashtag"
        } else {
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Could not generate resolution hashtag: dimension values missing or invalid"
        }
        
        # Добавляем хэштеги битрейта через каждые 500kbps от 1000 до 6500
        if ($mediaInfo.VideoBitRate -and $mediaInfo.VideoBitRate -gt 0) {
            $bitRateKbps = [int]($mediaInfo.VideoBitRate / 1000)
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Detected video bitrate: $bitRateKbps kbps"
            
            # Создаем хэштеги только для уровней битрейта, которые не превышают фактический битрейт видео
            $bitrateHashtags = @()
            $rate = 1000
            while ($rate -le 6500 -and $rate -le $bitRateKbps) {
                $bitrateHashtag = "#${rate}kbps"
                $hashtags += $bitrateHashtag
                $bitrateHashtags += $bitrateHashtag
                $rate += 500
            }
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Added bitrate hashtags: $($bitrateHashtags -join ', ')"
        } else {
            Write-PSFMessage -Level Debug -FunctionName "GetVideoHashtags" -Message "Could not generate bitrate hashtags: bitrate value missing or invalid"
        }
        
        # Соединяем хэштеги в строку
        $result = $hashtags -join " "
        Write-OperationSucceeded -Operation "Generate video hashtags" -Details "Generated $($hashtags.Count) hashtags" -FunctionName "GetVideoHashtags"
        return New-SuccessResponse -Data $result
    }
}
