#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Интеграционные тесты для метода SaveTikTokVideo в YtDlpService.
.DESCRIPTION
    Интеграционные тесты для проверки функциональности метода SaveTikTokVideo сервиса YtDlpService
    с реальными зависимостями и внешними сервисами.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "YtDlpService.SaveTikTokVideo Integration Tests" {
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

        # Проверяем наличие реальных TikTok cookies
        $cookiesPath = Join-Path $projectRoot "cookies\cookies.txt"
        $script:HasRealCookies = $false
        if (Test-Path $cookiesPath) {
            $cookiesContent = Get-Content $cookiesPath -Raw
            # Проверяем, есть ли в файле реальные cookie данные (не только комментарии)
            $script:HasRealCookies = $cookiesContent -match '^\s*\.tiktok\.com\s+' -or $cookiesContent -match '^\s*tiktok\.com\s+'
        }

        $config = @{
            YtDlpPath = $ytDlpPath
            DownloadTimeout = 60
            DefaultFormat = "best"
            ValidTikTokUrl = "https://www.tiktok.com/@yakinattyy_/video/7492429481462746384?_t=ZM-8vjNmHDakoX&_r=1"
            expectedAuthorUsername = "yakinattyy_"
            expectedVideoTitle = "тгк:яника"
            expectedFullVideoUrl = "https://www.tiktok.com/@yakinattyy_/video/7492429481462746384?_t=ZM-8vjNmHDakoX&_r=1"
            CookiesPath = if ($script:HasRealCookies) { $cookiesPath } else { "" }
        }

        # Создаем временную директорию для тестов
        $script:TestTempPath = Join-Path $env:TEMP "YtDlpServiceIntegrationTests_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $script:TestTempPath -ItemType Directory -Force | Out-Null

        # Конфигурация будет доступна для InModuleScope
        $script:Config = $config
    }
    
    Context "Successful video download scenarios" {
        It "Should download video successfully with all metadata" -Skip:(-not $script:HasRealCookies) {
            if (-not $script:HasRealCookies) {
                Set-ItResult -Skipped -Because "Real TikTok cookies are not configured. Please export cookies from browser to cookies/cookies.txt"
            }
            InModuleScope AnalyzeTTBot -Parameters @{
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                # Создаем сервисы внутри модуля
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat,
                    $Config.CookiesPath
                )
                
                $result = $ytDlpService.SaveTikTokVideo($config.ValidTikTokUrl, "")
                
                # Проверка базовых значений
                
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                
                # Проверка всех ключей
                $result.Data.FilePath | Should -Not -BeNullOrEmpty
                $result.Data.FilePath | Should -Match "tiktok_\d{8}_\d{6}_\d+\.mp4$"
                Test-Path -Path $result.Data.FilePath | Should -BeTrue
                
                $result.Data.FullVideoUrl | Should -Be $config.expectedFullVideoUrl
                
                $result.Data.JsonContent | Should -Not -BeNullOrEmpty
                $result.Data.JsonContent.id | Should -Be "7492429481462746384"
                $result.Data.JsonContent.title | Should -Be $config.expectedVideoTitle
                $result.Data.JsonContent.uploader | Should -Be $config.expectedAuthorUsername
                $result.Data.JsonContent.webpage_url | Should -Be $config.expectedFullVideoUrl
                
                $result.Data.VideoTitle | Should -Be $config.expectedVideoTitle
                $result.Data.AuthorUsername | Should -Be $config.expectedAuthorUsername
                $result.Data.InputUrl | Should -Be $config.ValidTikTokUrl
                
                $result.Data.JsonFilePath | Should -Not -BeNullOrEmpty
                $result.Data.JsonFilePath | Should -Match "tiktok_\d{8}_\d{6}_\d+\.info\.json$"
                Test-Path -Path $result.Data.JsonFilePath | Should -BeTrue
            }
        }
        
        It "Should save video to specified output path" -Skip:(-not $script:HasRealCookies) {
            if (-not $script:HasRealCookies) {
                Set-ItResult -Skipped -Because "Real TikTok cookies are not configured. Please export cookies from browser to cookies/cookies.txt"
            }
            InModuleScope AnalyzeTTBot -Parameters @{
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $ytDlpService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    $Config.DownloadTimeout,
                    $Config.DefaultFormat,
                    $Config.CookiesPath
                )
                
                $customOutputPath = Join-Path $TestTempPath "custom_video.mp4"
                $result = $ytDlpService.SaveTikTokVideo($Config.ValidTikTokUrl, $customOutputPath)
                
                $result.Success | Should -BeTrue
                $result.Data.FilePath | Should -BeExactly $customOutputPath
                Test-Path -Path $customOutputPath | Should -BeTrue
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
