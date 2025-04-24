#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Интеграционные тесты для метода GetMediaInfo в MediaInfoExtractorService.
.DESCRIPTION
    Проверяет корректность извлечения технической информации из медиафайла с помощью MediaInfoExtractorService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "MediaInfoExtractorService.GetMediaInfo Integration Tests" {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
        $testVideoPath = Join-Path $PSScriptRoot "..\TestData\test_video.mp4"
        $tiktokVideoPath = Join-Path $PSScriptRoot "..\TestData\test_tiktok_video.mp4"
        $config = @{
            TestMediaFile = $testVideoPath
            TikTokMediaFile = $tiktokVideoPath
        }
        $script:Config = $config
    }
    Context "GetMediaInfo on valid media file" {
        It "Should extract media info successfully and return all expected keys" {
            InModuleScope AnalyzeTTBot -Parameters @{ Config = $script:Config } {
                $fileSystemService = [FileSystemService]::new((Split-Path $Config.TestMediaFile))
                $mediaInfoService = [MediaInfoExtractorService]::new($fileSystemService)
                $result = $mediaInfoService.GetMediaInfo($Config.TestMediaFile)
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                


                # Проверка основных ключей
                $result.Data.Width | Should -Be 1080
                $result.Data.Height | Should -Be 1920
                $result.Data.AspectRatio | Should -Be "1080:1920"
                $result.Data.FPS | Should -Be 60
                $result.Data.FrameCount | Should -Be 670  # Точное значение
                $result.Data.VideoCodec | Should -Be "HEVC"
                $result.Data.VideoProfile | Should -Be "Main"
                $result.Data.VideoBitRate | Should -Be 16891257  # Точное значение
                $result.Data.VideoBitRateFormatted | Should -Be "16891 kbps"
                
                # Проверка размера файла
                $result.Data.FileSize | Should -Be 23731677  # Точное значение
                $result.Data.FileSizeMB | Should -BeGreaterThan 22.5
                $result.Data.FileSizeMB | Should -BeLessThan 22.7  # Приблизительно 22.63 MiB
                
                # Проверка длительности
                $result.Data.Duration | Should -Not -BeNullOrEmpty
                # DurationFormatted может быть пустым, так как MediaInfo не всегда возвращает это поле
                $result.Data.Duration | Should -Be "11.216"
                
                # Проверка аудио
                $result.Data.HasAudio | Should -BeTrue
                $result.Data.AudioCodec | Should -Be "AAC"
                $result.Data.AudioChannels | Should -Be 2
                $result.Data.AudioBitRate | Should -Be 96000  # Точное значение
                $result.Data.AudioBitRateFormatted | Should -Be "96 kbps"
                $result.Data.AudioSampleRate | Should -Be 44100  # Точное значение
                $result.Data.AudioSampleRateFormatted | Should -Be "44.1 kHz"
            }
        }
    }
    
    Context "GetMediaInfo on TikTok video file" {
        It "Should extract media info successfully from TikTok video" {
            InModuleScope AnalyzeTTBot -Parameters @{ Config = $script:Config } {
                $fileSystemService = [FileSystemService]::new((Split-Path $Config.TikTokMediaFile))
                $mediaInfoService = [MediaInfoExtractorService]::new($fileSystemService)
                $result = $mediaInfoService.GetMediaInfo($Config.TikTokMediaFile)
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                

                # Проверка основных ключей
                $result.Data.Width | Should -Be 1080
                $result.Data.Height | Should -Be 1920
                $result.Data.AspectRatio | Should -Be "1080:1920"
                $result.Data.FPS | Should -Be 30
                $result.Data.FrameCount | Should -BeGreaterThan 395  # Рассчитано: 13.374 * 30 ≈ 401
                $result.Data.FrameCount | Should -BeLessThan 405
                $result.Data.VideoCodec | Should -Be "HEVC"
                $result.Data.VideoProfile | Should -Be "Main"  # Ожидаем "Main" без @L5@Main
                $result.Data.VideoBitRate | Should -Be 1314791  # Точное значение
                $result.Data.VideoBitRateFormatted | Should -Be "1315 kbps"
                
                # Проверка размера файла
                $result.Data.FileSize | Should -Be 2318085  # Точное значение
                $result.Data.FileSizeMB | Should -BeGreaterThan 2.1
                $result.Data.FileSizeMB | Should -BeLessThan 2.3
                
                # Проверка длительности
                $result.Data.Duration | Should -Be "13.374"
                
                # Проверка аудио
                $result.Data.HasAudio | Should -BeTrue
                $result.Data.AudioCodec | Should -Be "AAC"
                $result.Data.AudioChannels | Should -Be 2
                $result.Data.AudioBitRate | Should -BeGreaterThan 64000  # Приблизительно 64.1 kb/s
                $result.Data.AudioBitRate | Should -BeLessThan 65000
                $result.Data.AudioBitRateFormatted | Should -Match "\d+ kbps"
                $result.Data.AudioSampleRate | Should -Be 44100  # 44.1 kHz
                $result.Data.AudioSampleRateFormatted | Should -Be "44.1 kHz"
            }
        }
    }
    
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}