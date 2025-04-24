#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для валидации формата вывода сервиса MediaFormatterService.
.DESCRIPTION
    Модульные тесты для проверки структуры и формата вывода сервиса MediaFormatterService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "MediaFormatterService.OutputFormatValidation Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        # Строчка ниже устраняет эту ошибку
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")

        # Импортируем основной модуль
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
        
        # Вспомогательные модули для тестирования
        $helperPath = Join-Path $PSScriptRoot "..\Helpers\TestResponseHelper.psm1"
        if (Test-Path $helperPath) {
            Import-Module -Name $helperPath -Force -ErrorAction Stop
        }
    }

    Context "Format Requirements" {
        It "Should maintain specific format according to requirements" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Используем данные из примера
                $mediaInfo = New-SuccessResponse -Data @{
                    FileSize = 1005 * 1KB # Около 1005 KiB
                    FileSizeMB = 0.98
                    Duration = "14.651"
                    DurationFormatted = "14 s 651 ms"
                    Width = 1080
                    Height = 1440
                    AspectRatio = "1080:1440"
                    FPS = 60
                    VideoCodec = "HEVC"
                    VideoBitRate = 487000
                    VideoBitRateFormatted = "487 kbps"
                    HasAudio = $true
                    AudioCodec = "AAC"
                    AudioChannels = 2
                    AudioBitRate = 64100
                    AudioBitRateFormatted = "64.1 kbps"
                    AudioSampleRate = 44100
                    AudioSampleRateFormatted = "44.1 kHz"
                }
                
                # Пример данных
                $authorUsername = "nopowerb"
                $videoUrl = "https://vm.tiktok.com/ZMBfhPX7E/"
                $fullVideoUrl = "https://www.tiktok.com/@nopowerb/video/7486440806862032144"
                
                # Вызываем метод
                $result = $mediaFormatterService.FormatMediaInfo($mediaInfo, $authorUsername, $videoUrl, $fullVideoUrl, "", "")
                
                # Проверяем, что формат вывода соответствует требованиям
                $result.Success | Should -BeTrue
                $result.Data | Should -Match "🔗 Link:"
                $result.Data | Should -Match "👤 Author:"
                $result.Data | Should -Match "🎬 VIDEO"
                $result.Data | Should -Match "Resolution: 1080 x 1440"
                $result.Data | Should -Match "FPS: 60"
                $result.Data | Should -Match "Codec: HEVC"
                $result.Data | Should -Match "📁 General information:"
                $result.Data | Should -Match "Duration:"
                
                # Проверяем, что формат сообщения не содержит нежелательный формат
                $result.Data | Should -Not -Match "Технический анализ"
                $result.Data | Should -Not -Match "Автор:"
                $result.Data | Should -Not -Match "Разрешение:"
                $result.Data | Should -Not -Match "Частота кадров:"
                $result.Data | Should -Not -Match "Ссылка на видео:"
            }
        }
        
        It "Should have correctly grouped sections separated by empty lines" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Используем данные из примера
                $mediaInfo = New-SuccessResponse -Data @{
                    FileSize = 653 * 1KB
                    FileSizeMB = 0.638
                    Duration = "6.385"
                    Width = 1080
                    Height = 1920
                    AspectRatio = "1080:1920"
                    FPS = 30
                    VideoCodec = "HEVC"
                    VideoBitRate = 765000
                    VideoBitRateFormatted = "765 kbps"
                    HasAudio = $true
                    AudioCodec = "AAC"
                    AudioChannels = 2
                    AudioBitRate = 64000
                    AudioBitRateFormatted = "64 kbps"
                    AudioSampleRate = 44100
                    AudioSampleRateFormatted = "44.1 kHz"
                }
                
                $authorUsername = "olafflee"
                $videoUrl = "https://vm.tiktok.com/ZMBskEM99/"
                $fullVideoUrl = "https://www.tiktok.com/@olafflee/video/7493548584726727958?_t=ZM-8vcptHBnUcH&_r=1"
                
                # Вызываем метод
                $result = $mediaFormatterService.FormatMediaInfo($mediaInfo, $authorUsername, $videoUrl, $fullVideoUrl, "", "")
                
                # Проверяем наличие 4 групп, разделенных пустыми строками
                $resultLines = $result.Data -split "`n"
                
                # Проверяем первую группу - ссылка и автор
                $resultLines[0] | Should -Match "🔗 Link:"
                $resultLines[1] | Should -Match "👤 Author:"
                $resultLines[2] | Should -BeNullOrEmpty  # Пустая строка после первой группы
                
                # Проверяем вторую группу - Video
                $resultLines[3] | Should -Match "🎬 VIDEO"
                $resultLines[4] | Should -Match "Resolution:"
                $resultLines[5] | Should -Match "FPS:"
                $resultLines[6] | Should -Match "Bitrate:"
                $resultLines[7] | Should -Match "Codec:"
                $resultLines[8] | Should -BeNullOrEmpty  # Пустая строка после второй группы
                
                # Проверяем третью группу - Audio
                $resultLines[9] | Should -Match "🔊 AUDIO"
                $resultLines[10] | Should -Match "Format:"
                $resultLines[11] | Should -Match "Bitrate:"
                $resultLines[12] | Should -Match "Channels:"
                $resultLines[13] | Should -Match "Sampling Rate:"
                $resultLines[14] | Should -BeNullOrEmpty  # Пустая строка после третьей группы
                
                # Проверяем четвертую группу - General information
                $resultLines[15] | Should -Match "📁 General information:"
                $resultLines[16] | Should -Match "Duration:"
                $resultLines[17] | Should -Match "File Size:"
                
                # Проверяем наличие всех необходимых ключей в отчете
                $result.Data | Should -Match "🔗 Link:"
                $result.Data | Should -Match "👤 Author:"
                $result.Data | Should -Match "🎬 VIDEO"
                $result.Data | Should -Match "Resolution:"
                $result.Data | Should -Match "FPS:"
                $result.Data | Should -Match "Bitrate:"
                $result.Data | Should -Match "Codec:"
                $result.Data | Should -Match "🔊 AUDIO"
                $result.Data | Should -Match "Format:"
                $result.Data | Should -Match "Channels:"
                $result.Data | Should -Match "Sampling Rate:"
                $result.Data | Should -Match "📁 General information:"
                $result.Data | Should -Match "Duration:"
                $result.Data | Should -Match "File Size:"
            }
        }
    }

    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
        if (Get-Module -Name TestResponseHelper) {
            Remove-Module -Name TestResponseHelper -Force -ErrorAction SilentlyContinue
        }
    }
}