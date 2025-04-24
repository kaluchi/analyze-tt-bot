#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Интеграционные тесты для проверки обработки плохих URL в YtDlpService.
.DESCRIPTION
    Тесты проверяют корректную обработку невалидных, устаревших и некорректных URL при попытке 
    скачивания видео через метод SaveTikTokVideo.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "YtDlpService.BadUrls Integration Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
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
        
        # Создаем тестовую конфигурацию
        $ytDlpPath = (Get-Command yt-dlp -ErrorAction SilentlyContinue).Source
        if (-not $ytDlpPath) {
            throw "yt-dlp не найден в системе"
        }
        
        $config = @{
            YtDlpPath = $ytDlpPath
            DownloadTimeout = 60
            DefaultFormat = "best"
        }
        
        # Создаем временную директорию для тестов
        $script:TestTempPath = Join-Path $env:TEMP "YtDlpBadUrlsIntegrationTests_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $script:TestTempPath -ItemType Directory -Force | Out-Null
        
        # Конфигурация будет доступна для InModuleScope
        $script:Config = $config
    }
    
    Context "Invalid URL formats" {
        It "Should handle invalid URL format" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                $invalidUrl = "not-a-url"
                $result = $ytDlpService.SaveTikTokVideo($invalidUrl, "")
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "Failed to download|cannot find the URL|invalid|error"
            }
        }
        
        It "Should handle malformed TikTok URLs" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                $malformedUrl = "https://tiktok.com/bad/path/format"
                $result = $ytDlpService.SaveTikTokVideo($malformedUrl, "")
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "Unsupported|Failed to download|yt-dlp process failed"
            }
        }
        
        It "Should handle empty URL strings" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                $result = $ytDlpService.SaveTikTokVideo("", "")
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Be "Empty URL provided"
            }
        }
    }
    
    Context "Expired and non-existent URLs" {
        It "Should handle expired TikTok links (short URLs)" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                # Искусственно создаем короткую ссылку, которая точно не существует
                $expiredUrl = "https://vm.tiktok.com/expired123"
                $result = $ytDlpService.SaveTikTokVideo($expiredUrl, "")
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Not -BeNullOrEmpty
                # yt-dlp должен вернуть ошибку для несуществующего/устаревшего URL
                $result.Error | Should -Match "Unsupported|Failed to download|yt-dlp process failed"
            }
        }
        
        It "Should handle non-existent video URLs" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                # Создаем URL на видео, которое точно не существует
                $nonExistentUrl = "https://www.tiktok.com/@nonexistentuser99999/video/0000000000000000000"
                $result = $ytDlpService.SaveTikTokVideo($nonExistentUrl, "")
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "Unsupported|Failed to download|yt-dlp process failed"
            }
        }
    }
    
    Context "Other platform URLs" {
        It "Should handle URLs from other platforms" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                $youtubeUrl = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
                $result = $ytDlpService.SaveTikTokVideo($youtubeUrl, "")
                
                # Хотя yt-dlp поддерживает YouTube, в контексте TikTokService это должно возвращать ошибку
                # или успешно скачивать видео, но с другими метаданными
                # Мы проверяем, что процесс завершается без краха
                $result | Should -Not -BeNullOrEmpty
                
                if ($result.Success) {
                    # Если успешно (yt-dlp скачал YouTube видео), проверяем что метаданные отличаются
                    $result.Data.AuthorUsername | Should -Not -Match "tiktok"
                } else {
                    # Если ошибка, проверяем что она корректно обработана
                    $result.Error | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
    
    Context "Error handling and reporting" {
        It "Should provide detailed error messages for failed downloads" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat
                )
                
                $badUrl = "https://tiktok.com/completely/invalid/path/structure"
                $result = $ytDlpService.SaveTikTokVideo($badUrl, "")
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Not -BeNullOrEmpty
                # Проверяем, что сообщение об ошибке содержит полезную информацию
                $result.Error.Length | Should -BeGreaterThan 10
                
                # Проверяем, что в результате есть дополнительные данные об ошибке
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "yt-dlp process failed with exit code";
                
            }
        }
        
        It "Should handle network errors gracefully" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    1, # Маленький таймаут для симуляции сетевых проблем
                    $Config.DefaultFormat
                )
                
                $result = $ytDlpService.SaveTikTokVideo("https://www.tiktok.com/@veryslowvideo/video/123456789", "")
                
                $result | Should -Not -BeNullOrEmpty
                if (-not $result.Success) {
                    $result.Error | Should -Not -BeNullOrEmpty
                    # Проверяем, что ошибка связана с таймаутом или сетью
                    $result.Error | Should -Match "yt-dlp process failed with exit code"
                }
            }
        }
    }
    
    AfterAll {
        # Очистка временных файлов
        if ($script:TestTempPath -and (Test-Path $script:TestTempPath)) {
            Remove-Item -Path $script:TestTempPath -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
