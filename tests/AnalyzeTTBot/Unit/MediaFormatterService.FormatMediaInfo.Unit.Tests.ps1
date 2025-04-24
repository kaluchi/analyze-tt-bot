#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода FormatMediaInfo сервиса MediaFormatterService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода FormatMediaInfo сервиса MediaFormatterService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "MediaFormatterService.FormatMediaInfo Tests" {
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
        
        # Устанавливаем тестовые параметры
        $script:testFilePath = Join-Path -Path $env:TEMP -ChildPath "test_video.mp4"
        $script:testAuthorUsername = "test_user"
        $script:testVideoUrl = "https://www.tiktok.com/@test_user/video/1234567890"
        $script:testFullVideoUrl = "https://www.tiktok.com/@test_user/video/1234567890"
        $script:testVideoTitle = "Test Video Title"
        
        # Загружаем пример отчета для сравнения
        $script:exampleReportPath = Join-Path $PSScriptRoot "..\TestData\analyse-report-format-example.md"
        if (Test-Path $script:exampleReportPath) {
            $script:exampleReport = Get-Content -Path $script:exampleReportPath -Raw
        } else {
            Write-Warning "Не найден файл примера отчета: $script:exampleReportPath"
        }
    }

    Context "Basic Formatting" {
        It "Should format media info correctly" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{
                testAuthorUsername = $script:testAuthorUsername
                testVideoUrl = $script:testVideoUrl
                testFullVideoUrl = $script:testFullVideoUrl
                testFilePath = $script:testFilePath
                testVideoTitle = $script:testVideoTitle
            } {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Формируем тестовые данные
                $mediaInfo = New-SuccessResponse -Data @{
                    FileSize = 5767168
                    FileSizeMB = 5.5
                    Duration = "15.000"
                    DurationFormatted = "00:00:15"
                    Width = 1080
                    Height = 1920
                    AspectRatio = "1080:1920"
                    FPS = 60
                    FrameCount = 900
                    VideoCodec = "h264"
                    VideoProfile = "Main@L4.1"
                    VideoBitRate = 2000000
                    VideoBitRateFormatted = "2000 kbps"
                    HasAudio = $true
                    AudioCodec = "aac"
                    AudioChannels = 2
                    AudioBitRate = 128000
                    AudioBitRateFormatted = "128 kbps"
                    AudioSampleRate = 44100
                    AudioSampleRateFormatted = "44.1 kHz"
                }
                
                # Вызываем метод с правильной сигнатурой, включая все необходимые параметры
                $result = $mediaFormatterService.FormatMediaInfo($mediaInfo, $testAuthorUsername, $testVideoUrl, $testFullVideoUrl, $testFilePath, $testVideoTitle)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data | Should -Match "Link: $testVideoUrl"
                
                # Проверяем присутствие автора, используя упрощенную проверку
                $result.Data | Should -Match "@$testAuthorUsername"
                
                # Проверяем наличие основных разделов
                $result.Data | Should -Match "🎬 VIDEO"
                $result.Data | Should -Match "Resolution: 1080 x 1920"
                $result.Data | Should -Match "FPS: 60"
                $result.Data | Should -Match "Bitrate: 2000 kb/s"
                $result.Data | Should -Match "Codec: h264"
                $result.Data | Should -Match "Channels: 2"
                $result.Data | Should -Match "Sampling Rate: 44.1 kHz"
                $result.Data | Should -Match "Duration: 15 s 0 ms"
                $result.Data | Should -Match "File Size:"
            }
        }
        
        It "Should handle error media info" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{
                testAuthorUsername = $script:testAuthorUsername
                testVideoUrl = $script:testVideoUrl
                testFullVideoUrl = $script:testFullVideoUrl
                testFilePath = $script:testFilePath
            } {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем ошибочную информацию о медиа
                $errorMediaInfo = New-ErrorResponse -ErrorMessage "Test error message"
                
                # Вызываем метод
                $result = $mediaFormatterService.FormatMediaInfo($errorMediaInfo, $testAuthorUsername, $testVideoUrl, $testFullVideoUrl, $testFilePath, "")
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Test error message"
            }
        }
        
        It "Should handle missing author" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{
                testVideoUrl = $script:testVideoUrl
                testFullVideoUrl = $script:testFullVideoUrl
                testFilePath = $script:testFilePath
            } {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Формируем тестовые данные
                $mediaInfo = New-SuccessResponse -Data @{
                    FileSize = 5767168
                    FileSizeMB = 5.5
                    Duration = "15.000"
                    Width = 1080
                    Height = 1920
                    FPS = 60
                    VideoCodec = "h264"
                    VideoBitRate = 2000000
                    VideoBitRateFormatted = "2000 kbps"
                    HasAudio = $true
                    AudioCodec = "aac"
                    AudioChannels = 2
                    AudioBitRate = 128000
                    AudioBitRateFormatted = "128 kbps"
                    AudioSampleRate = 44100
                    AudioSampleRateFormatted = "44.1 kHz"
                }
                
                # Вызываем метод без автора
                $result = $mediaFormatterService.FormatMediaInfo($mediaInfo, "", $testVideoUrl, $testFullVideoUrl, $testFilePath, "")
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data | Should -Match "Link: $testVideoUrl"
                $result.Data | Should -Not -Match "Author:"
            }
        }
        
        It "Should handle missing URL" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{
                testAuthorUsername = $script:testAuthorUsername
                testFilePath = $script:testFilePath
            } {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Формируем тестовые данные
                $mediaInfo = New-SuccessResponse -Data @{
                    FileSize = 5767168
                    FileSizeMB = 5.5
                    Duration = "15.000"
                    Width = 1080
                    Height = 1920
                    FPS = 60
                    VideoCodec = "h264"
                    VideoBitRate = 2000000
                    VideoBitRateFormatted = "2000 kbps"
                    HasAudio = $true
                    AudioCodec = "aac"
                    AudioChannels = 2
                    AudioBitRate = 128000
                    AudioBitRateFormatted = "128 kbps"
                    AudioSampleRate = 44100
                    AudioSampleRateFormatted = "44.1 kHz"
                }
                
                # Вызываем метод без URL
                $result = $mediaFormatterService.FormatMediaInfo($mediaInfo, $testAuthorUsername, "", "", $testFilePath, "")
                
                # Проверяем результат - автор должен присутствовать, используя упрощенную проверку
                $result.Success | Should -BeTrue
                $result.Data | Should -Match "@$testAuthorUsername"
            }
        }
    }
    
    Context "Report Format Compatibility" {
        It "Should reproduce the example report with correct parameters" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{
                exampleReport = $script:exampleReport
            } {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем параметры на основе анализа примера отчета
                $mediaInfo = New-SuccessResponse -Data @{
                    FileSize = 653 * 1KB        # Размер в байтах
                    FileSizeMB = 0.638          # Размер в мегабайтах
                    Duration = "6.385"          # Длительность в секундах
                    Width = 1080                # Ширина
                    Height = 1920               # Высота
                    AspectRatio = "1080:1920"   # Соотношение сторон
                    FPS = 30                    # Кадры в секунду
                    VideoCodec = "HEVC"         # Кодек видео
                    VideoBitRate = 765000       # Битрейт видео в bps
                    VideoBitRateFormatted = "765 kbps"  # Форматированный битрейт
                    HasAudio = $true            # Наличие аудио
                    AudioCodec = "AAC"          # Кодек аудио
                    AudioChannels = 2           # Количество аудиоканалов
                    AudioBitRate = 64000        # Битрейт аудио в bps
                    AudioBitRateFormatted = "64 kbps"  # Форматированный битрейт
                    AudioSampleRate = 44100     # Частота дискретизации
                    AudioSampleRateFormatted = "44.1 kHz"  # Форматированная частота
                }
                
                $authorUsername = "olafflee"
                $videoUrl = "https://vm.tiktok.com/ZMBskEM99/"
                $fullVideoUrl = "https://www.tiktok.com/@olafflee/video/7493548584726727958?_t=ZM-8vcptHBnUcH&_r=1"
                $filePath = ""
                $videoTitle = ""
                
                # Вызываем метод с правильной сигнатурой - важно включить все 6 параметров
                $result = $mediaFormatterService.FormatMediaInfo($mediaInfo, $authorUsername, $videoUrl, $fullVideoUrl, $filePath, $videoTitle)
                
                # Проверяем, что результат соответствует примеру
                $result.Success | Should -BeTrue
                
                # Проверяем наличие всех основных значений
                $result.Data | Should -Match $videoUrl
                $result.Data | Should -Match $authorUsername
                $result.Data | Should -Match "Resolution: 1080 x 1920"
                $result.Data | Should -Match "FPS: 30"
                $result.Data | Should -Match "Bitrate: 765 kb/s"
                $result.Data | Should -Match "Codec: HEVC"
                $result.Data | Should -Match "Duration: 6 s 385 ms"
                $result.Data | Should -Match "File Size: 653 KiB"
                
                # Если есть файл примера, проверяем основные блоки
                if ($exampleReport) {
                    $cleanExample = $exampleReport.Trim() -replace '[\r\n]+', "`n"
                    
                    # Проверяем, что основные блоки информации содержатся в примере
                    $cleanExample | Should -Match "Resolution: 1080 x 1920"
                    $cleanExample | Should -Match "FPS: 30"
                    $cleanExample | Should -Match "Bitrate: 765 kb/s"
                    $cleanExample | Should -Match "Codec: HEVC"
                    $cleanExample | Should -Match "Duration: 6 s 385 ms"
                    $cleanExample | Should -Match "File Size: 653 KiB"
                }
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