#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Интеграционные тесты для метода TestYtDlpInstallation в YtDlpService.
.DESCRIPTION
    Тесты проверяют функциональность метода TestYtDlpInstallation, включая проверку установки yt-dlp,
    версий и доступность обновлений.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "YtDlpService.TestYtDlpInstallation Integration Tests" {
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
            DownloadTimeout = 30
            DefaultFormat = "best"
        }
        
        # Создаем временную директорию для тестов
        $script:TestTempPath = Join-Path $env:TEMP "YtDlpInstallationIntegrationTests_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $script:TestTempPath -ItemType Directory -Force | Out-Null
        
        # Конфигурация будет доступна для InModuleScope
        $script:Config = $config
    }
    
    Context "YtDlp installation check" {
        It "Should detect installed yt-dlp version" {
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
                
                # Проверка без проверки обновлений
                $skipCheckUpdates = [switch]$true
                $result = $ytDlpService.TestYtDlpInstallation($skipCheckUpdates)
                
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Not -BeNullOrEmpty
                $result.Data.Version | Should -Match '^\d{4}\.\d{1,2}\.\d{1,2}(\.\d+)?$'
                $result.Data.Description | Should -Match "Version"
            }
        }
        
        It "Should check for updates correctly" {
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
                
                # Проверяем с опцией проверки обновлений (параметр switch по умолчанию $false)
                $skipCheckUpdates = [switch]$false
                $result = $ytDlpService.TestYtDlpInstallation($skipCheckUpdates)
                
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.CheckUpdatesResult | Should -Not -BeNullOrEmpty
                $result.Data.CheckUpdatesResult.CurrentVersion | Should -Not -BeNullOrEmpty
                $result.Data.CheckUpdatesResult.NewVersion | Should -Not -BeNullOrEmpty
                $result.Data.SkipCheckUpdates | Should -BeFalse
                
                # Проверяем, что данные о версиях валидны
                $result.Data.CheckUpdatesResult.CurrentVersion | Should -Match '^\d{4}\.\d{1,2}\.\d{1,2}(\.\d+)?$'
                $result.Data.CheckUpdatesResult.NewVersion | Should -Match '^\d{4}\.\d{1,2}\.\d{1,2}(\.\d+)?$'
            }
        }
        
        It "Should bypass update check when flag is set" {
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
                
                # Проверяем с пропуском проверки обновлений
                # Создаем switch параметр и устанавливаем его в true
                $skipCheckUpdates = [switch]$true
                $result = $ytDlpService.TestYtDlpInstallation($skipCheckUpdates)
                
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.CheckUpdatesResult | Should -BeNullOrEmpty
                $result.Data.SkipCheckUpdates | Should -BeTrue
            }
        }
        
        It "Should handle missing yt-dlp installation" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                # Создаем временный сервис с неверным путем к yt-dlp
                $nonExistentPath = Join-Path $TestTempPath "non_existent_yt-dlp.exe"
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $tempService = [YtDlpService]::new(
                    $nonExistentPath,
                    $fileSystemService,
                    30,
                    "best"
                )
                
                $skipCheckUpdates = [switch]$true
                $result = $tempService.TestYtDlpInstallation($skipCheckUpdates)
                
                $result.Success | Should -BeFalse
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "yt-dlp returned error|Failed to test yt-dlp|error occurred trying to start process"
            }
        }
        
        It "Should parse pip output correctly for version information" {
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
                
                # Проверяем метод CheckUpdates напрямую
                $result = $ytDlpService.CheckUpdates()
                
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.CurrentVersion | Should -Not -BeNullOrEmpty
                $result.Data.NewVersion | Should -Not -BeNullOrEmpty
                
                # Проверяем формат версий
                $result.Data.CurrentVersion | Should -Match '^\d{4}\.\d{1,2}\.\d{1,2}(\.\d+)?$'
                $result.Data.NewVersion | Should -Match '^\d{4}\.\d{1,2}\.\d{1,2}(\.\d+)?$'
                
                # Проверяем логику NeedsUpdate
                if ($result.Data.CurrentVersion -eq $result.Data.NewVersion) {
                    $result.Data.NeedsUpdate | Should -BeFalse
                } else {
                    $result.Data.NeedsUpdate | Should -BeTrue
                }
            }
        }
    }
    
    Context "Error handling" {
        It "Should handle timeout properly when checking version" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                # Создаем сервис с очень коротким таймаутом
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $shortTimeoutService = [YtDlpService]::new(
                    $Config.YtDlpPath,
                    $fileSystemService,
                    1,  # 1 секунда - очень короткий таймаут
                    "best"
                )
                
                # Пытаемся тестировать установку с коротким таймаутом
                $skipCheckUpdates = [switch]$true
                $result = $shortTimeoutService.TestYtDlpInstallation($skipCheckUpdates)
                
                # Результат должен быть валидным (успешным или неуспешным), но не пустым
                $result | Should -Not -BeNullOrEmpty
                
                if (-not $result.Success) {
                    $result.Error | Should -Not -BeNullOrEmpty
                }
            }
        }
        
        It "Should return proper format for error scenarios" {
            InModuleScope AnalyzeTTBot -Parameters @{ 
                TestTempPath = $script:TestTempPath
                Config = $script:Config
            } {
                # Создаем сервис с заведомо неверным путем
                $fileSystemService = [FileSystemService]::new($TestTempPath)
                $invalidService = [YtDlpService]::new(
                    "invalid_yt-dlp_path",
                    $fileSystemService,
                    30,
                    "best"
                )
                
                $skipCheckUpdates = [switch]$true
                $result = $invalidService.TestYtDlpInstallation($skipCheckUpdates)
                
                # Проверяем структуру ответа
                $result.Success | Should -BeFalse
                $result.Data | Should -BeNullOrEmpty
                $result.Error | Should -Not -BeNullOrEmpty
                $result.Error | Should -Match "yt-dlp returned error|Failed to test yt-dlp|error occurred trying to start process"
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
