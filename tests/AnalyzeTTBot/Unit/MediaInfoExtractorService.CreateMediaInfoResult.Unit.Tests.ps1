<#
.SYNOPSIS
    Тесты для метода CreateMediaInfoResult сервиса MediaInfoExtractorService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода CreateMediaInfoResult сервиса MediaInfoExtractorService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "MediaInfoExtractorService.CreateMediaInfoResult Tests" {
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
    }
    
    BeforeEach {
        InModuleScope -ModuleName AnalyzeTTBot {
            # Создаем экземпляр IFileSystemService внутри модуля
            $script:fileSystemServiceMock = New-Object -TypeName IFileSystemService
            
            # Создаем экземпляр MediaInfoExtractorService для тестирования
            $script:mediaInfoExtractorService = New-Object -TypeName MediaInfoExtractorService -ArgumentList @($script:fileSystemServiceMock)
        }
    }
    
    Context "Media info result creation" {
        It "Should create correct media info structure" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем тестовые треки
                $generalTrack = [PSCustomObject]@{
                    FileSize = "1024000"
                    Duration = "10.5"
                    Duration_String3 = "00:00:10.500"
                }
                
                $videoTrack = [PSCustomObject]@{
                    Width = "1280"
                    Height = "720"
                    FrameRate = "30"
                    FrameCount = "315"
                    Format = "h264"
                    Format_Profile = "Main@L3.1"
                    BitRate = "1000000"
                }
                
                $audioTrack = [PSCustomObject]@{
                    Format = "aac"
                    Channels = "2"
                    BitRate = "128000"
                    SamplingRate = "44100"
                }
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.CreateMediaInfoResult($generalTrack, $videoTrack, $audioTrack)
                
                # Проверяем результат
                $result.FileSize | Should -Be 1024000
                $result.FileSizeMB | Should -Be 0.98
                $result.Duration | Should -Be "10.5"
                $result.DurationFormatted | Should -Be "00:00:10.500"
                $result.Width | Should -Be 1280
                $result.Height | Should -Be 720
                $result.AspectRatio | Should -Be "1280:720"
                $result.FPS | Should -Be 30
                $result.FrameCount | Should -Be 315
                $result.VideoCodec | Should -Be "h264"
                $result.VideoProfile | Should -Be "Main@L3.1"
                $result.VideoBitRate | Should -Be 1000000
                $result.VideoBitRateFormatted | Should -Be "1000 kbps"
                $result.HasAudio | Should -BeTrue
                $result.AudioCodec | Should -Be "aac"
                $result.AudioChannels | Should -Be 2
                $result.AudioBitRate | Should -Be 128000
                $result.AudioBitRateFormatted | Should -Be "128 kbps"
                $result.AudioSampleRate | Should -Be 44100
                $result.AudioSampleRateFormatted | Should -Be "44.1 kHz"
            }
        }
        
        It "Should handle missing audio track" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем тестовые треки без аудио
                $generalTrack = [PSCustomObject]@{
                    FileSize = "1024000"
                    Duration = "10.5"
                    Duration_String3 = "00:00:10.500"
                }
                
                $videoTrack = [PSCustomObject]@{
                    Width = "1280"
                    Height = "720"
                    FrameRate = "30"
                    FrameCount = "315"
                    Format = "h264"
                    Format_Profile = "Main@L3.1"
                    BitRate = "1000000"
                }
                
                # Вызываем метод без аудио трека
                $result = $script:mediaInfoExtractorService.CreateMediaInfoResult($generalTrack, $videoTrack, $null)
                
                # Проверяем результат
                $result.HasAudio | Should -BeFalse
                $result.AudioCodec | Should -BeNullOrEmpty
                $result.AudioChannels | Should -BeNullOrEmpty
                $result.AudioBitRate | Should -BeNullOrEmpty
                $result.AudioBitRateFormatted | Should -BeNullOrEmpty
                $result.AudioSampleRate | Should -BeNullOrEmpty
                $result.AudioSampleRateFormatted | Should -BeNullOrEmpty
            }
        }
        
        It "Should handle missing or zero values" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем треки с отсутствующими или нулевыми значениями
                $generalTrack = [PSCustomObject]@{
                    # Отсутствует FileSize
                    Duration = ""  # Пустая строка
                }
                
                $videoTrack = [PSCustomObject]@{
                    Width = "0"
                    Height = "0"
                    # Отсутствует FrameRate
                    # Отсутствует FrameCount
                    Format = ""  # Пустая строка
                    # Отсутствует Format_Profile
                    BitRate = "0"
                }
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.CreateMediaInfoResult($generalTrack, $videoTrack, $null)
                
                # Проверяем результат с запасными значениями
                $result.FileSize | Should -Be 0
                $result.FileSizeMB | Should -Be 0
                $result.Width | Should -Be 0
                $result.Height | Should -Be 0
                $result.AspectRatio | Should -Be "0:0"
                $result.FPS | Should -Be 0
                $result.VideoCodec | Should -Be ""
                $result.VideoBitRate | Should -Be 0
                $result.VideoBitRateFormatted | Should -Be "Unknown"
                $result.HasAudio | Should -BeFalse
            }
        }
    }
    
    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}