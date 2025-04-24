#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для HashtagGeneratorService.
.DESCRIPTION
    Модульные тесты для проверки функциональности HashtagGeneratorService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
#>

Describe "HashtagGeneratorService" {
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
        
        # Устанавливаем тестовые параметры
        $script:testAuthorUsername = "test_user"
    }

    Describe "Constructor and initialization" {
        Context "Basic functionality" {
            It "Should create an instance correctly" {
                InModuleScope AnalyzeTTBot {
                    $hashtagGeneratorService = [HashtagGeneratorService]::new()
                    $hashtagGeneratorService | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
    
    Describe "GetVideoHashtags method" {
        Context "Hashtag generation" {

            It "Should generate hashtags correctly" {
                InModuleScope AnalyzeTTBot -Parameters @{testAuthorUsername = $script:testAuthorUsername} {
                    # Создаем экземпляр сервиса
                    $hashtagGeneratorService = [HashtagGeneratorService]::new()
                    
                    # Используем заранее подготовленный объект данных
                    $mediaInfoData = @{
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
                    $mediaInfo = New-SuccessResponse -Data $mediaInfoData
                    
                    # Вызываем метод
                    $result = $hashtagGeneratorService.GetVideoHashtags($mediaInfo, $testAuthorUsername)
                    
                    # Проверяем результат
                    $result.Success | Should -BeTrue
                    $hashtags = $result.Data
                    $hashtags | Should -Match "#$testAuthorUsername"
                    $hashtags | Should -Match "#60fps"
                    $hashtags | Should -Match "#1080x1920"
                    $hashtags | Should -Match "#1000kbps"
                    $hashtags | Should -Match "#1500kbps"
                    $hashtags | Should -Match "#2000kbps"
                    # Теперь мы не ожидаем битрейты выше фактического битрейта видео
                    $hashtags | Should -Not -Match "#2500kbps"
                    $hashtags | Should -Not -Match "#3000kbps"
                    $hashtags | Should -Not -Match "#3500kbps"
                    $hashtags | Should -Not -Match "#4000kbps"
                    $hashtags | Should -Not -Match "#4500kbps"
                    $hashtags | Should -Not -Match "#5000kbps"
                    $hashtags | Should -Not -Match "#5500kbps"
                    $hashtags | Should -Not -Match "#6000kbps"
                    $hashtags | Should -Not -Match "#6500kbps"
                }
            }
        
            It "Should handle standard resolutions" {
                InModuleScope AnalyzeTTBot -Parameters @{testAuthorUsername = $script:testAuthorUsername} {
                    # Создаем экземпляр сервиса
                    $hashtagGeneratorService = [HashtagGeneratorService]::new()
                    
                    # Создаем информацию о медиа с стандартным разрешением
                    $mediaInfoData = @{
                        Width = 1920
                        Height = 1080
                        FPS = 30
                        VideoCodec = "h264"
                        VideoBitRate = 2000000
                    }
                    $mediaInfo = New-SuccessResponse -Data $mediaInfoData
                    
                    # Вызываем метод
                    $result = $hashtagGeneratorService.GetVideoHashtags($mediaInfo, $testAuthorUsername)
                    
                    # Проверяем результат
                    $result.Success | Should -BeTrue
                    $result.Data | Should -Match "#$testAuthorUsername"
                    $result.Data | Should -Match "#30fps"
                    $result.Data | Should -Match "#1920x1080"
                    $result.Data | Should -Match "#1000kbps"
                    $result.Data | Should -Match "#1500kbps"
                    $result.Data | Should -Match "#2000kbps"
                    # Теперь мы не ожидаем битрейты выше фактического битрейта видео
                    $result.Data | Should -Not -Match "#2500kbps"
                    $result.Data | Should -Not -Match "#3000kbps"
                    $result.Data | Should -Not -Match "#3500kbps"
                    $result.Data | Should -Not -Match "#4000kbps"
                    $result.Data | Should -Not -Match "#4500kbps"
                    $result.Data | Should -Not -Match "#5000kbps"
                    $result.Data | Should -Not -Match "#5500kbps"
                    $result.Data | Should -Not -Match "#6000kbps"
                    $result.Data | Should -Not -Match "#6500kbps"
                }
            }
        
            It "Should handle 4K resolution" {
                InModuleScope AnalyzeTTBot -Parameters @{testAuthorUsername = $script:testAuthorUsername} {
                    # Создаем экземпляр сервиса
                    $hashtagGeneratorService = [HashtagGeneratorService]::new()
                    
                    # Создаем информацию о медиа с 4K разрешением
                    $mediaInfoData = @{
                        Width = 3840
                        Height = 2160
                        FPS = 30
                        VideoCodec = "h264"
                        VideoBitRate = 2000000
                    }
                    $mediaInfo = New-SuccessResponse -Data $mediaInfoData
                    
                    # Вызываем метод
                    $result = $hashtagGeneratorService.GetVideoHashtags($mediaInfo, $testAuthorUsername)
                    
                    # Проверяем результат
                    $result.Success | Should -BeTrue
                    $result.Data | Should -Match "#$testAuthorUsername"
                    $result.Data | Should -Match "#30fps"
                    $result.Data | Should -Match "#3840x2160"
                    $result.Data | Should -Match "#1000kbps"
                    $result.Data | Should -Match "#1500kbps"
                    $result.Data | Should -Match "#2000kbps"
                    # Теперь мы не ожидаем битрейты выше фактического битрейта видео
                    $result.Data | Should -Not -Match "#2500kbps"
                    $result.Data | Should -Not -Match "#3000kbps"
                    $result.Data | Should -Not -Match "#3500kbps"
                    $result.Data | Should -Not -Match "#4000kbps"
                    $result.Data | Should -Not -Match "#4500kbps"
                    $result.Data | Should -Not -Match "#5000kbps"
                    $result.Data | Should -Not -Match "#5500kbps"
                    $result.Data | Should -Not -Match "#6000kbps"
                    $result.Data | Should -Not -Match "#6500kbps"
                }
            }
        
            It "Should handle error media info" {
                InModuleScope AnalyzeTTBot -Parameters @{testAuthorUsername = $script:testAuthorUsername} {
                    # Создаем экземпляр сервиса
                    $hashtagGeneratorService = [HashtagGeneratorService]::new()
                    
                    # Создаем ошибочную информацию о медиа
                    $errorMediaInfo = New-ErrorResponse -ErrorMessage "Test error message"
                    
                    # Вызываем метод
                    $result = $hashtagGeneratorService.GetVideoHashtags($errorMediaInfo, $testAuthorUsername)
                    
                    # Проверяем результат
                    $result.Success | Should -BeFalse
                    $result.Error | Should -Not -BeNullOrEmpty
                }
            }
        
            It "Should handle missing author" {
                InModuleScope AnalyzeTTBot -Parameters @{testAuthorUsername = $script:testAuthorUsername} {
                    # Создаем экземпляр сервиса
                    $hashtagGeneratorService = [HashtagGeneratorService]::new()
                    
                    # Используем заранее подготовленный объект данных
                    $mediaInfoData = @{
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
                    $mediaInfo = New-SuccessResponse -Data $mediaInfoData
                    
                    # Вызываем метод без автора
                    $result = $hashtagGeneratorService.GetVideoHashtags($mediaInfo, "")
                    
                    # Проверяем результат
                    $result.Success | Should -BeTrue
                    $result.Data | Should -Not -Match "#test_user"
                    $result.Data | Should -Match "#1080x1920"
                    $result.Data | Should -Match "#60fps"
                }
            }
        }
    }
    
    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
