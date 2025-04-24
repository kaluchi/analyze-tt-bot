#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода CheckUpdates сервиса YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода CheckUpdates сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "YtDlpService.CheckUpdates Tests" {
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
    }

    Context "Update check with pip index versions output" {
        It "Should correctly detect when update is needed" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                
                # Мок Invoke-ExternalProcess с разными версиями
                Mock Invoke-ExternalProcess {
                    return @{ 
                        Success = $true
                        Output = @(
                            "yt-dlp (2025.3.31)",
                            "Available versions: 2025.3.31, 2025.3.27, 2025.3.26, 2025.3.25",
                            "  INSTALLED: 2025.3.26",
                            "  LATEST:    2025.3.31"
                        )
                        Error = ""
                        ExitCode = 0 
                    }
                } -ParameterFilter { $ArgumentList -contains "versions" }
                
                $result = $ytDlpService.CheckUpdates()
                
                $result.Success | Should -BeTrue
                $result.Data.CurrentVersion | Should -Be "2025.3.26"
                $result.Data.NewVersion | Should -Be "2025.3.31"
                $result.Data.NeedsUpdate | Should -BeTrue
            }
        }

        It "Should correctly detect when no update is needed (same version strings)" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                
                # Мок Invoke-ExternalProcess с одинаковыми версиями
                Mock Invoke-ExternalProcess {
                    return @{ 
                        Success = $true
                        Output = @(
                            "yt-dlp (2025.3.31)",
                            "Available versions: 2025.3.31, 2025.3.27, 2025.3.26, 2025.3.25",
                            "  INSTALLED: 2025.3.31",
                            "  LATEST:    2025.3.31"
                        )
                        Error = ""
                        ExitCode = 0 
                    }
                } -ParameterFilter { $ArgumentList -contains "versions" }
                
                $result = $ytDlpService.CheckUpdates()
                
                $result.Success | Should -BeTrue
                $result.Data.CurrentVersion | Should -Be "2025.3.31"
                $result.Data.NewVersion | Should -Be "2025.3.31"
                $result.Data.NeedsUpdate | Should -BeFalse
            }
        }

        It "Should handle missing INSTALLED and LATEST lines and use alternative method" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                # Мокируем только Invoke-ExternalProcess, не CheckUpdates!
                Mock Invoke-ExternalProcess {
                    if ($ArgumentList -contains "versions") {
                        return @{ 
                            Success = $true
                            Output = @(
                                "yt-dlp (2025.3.31)",
                                "Available versions: 2025.3.31, 2025.3.27, 2025.3.26, 2025.3.25"
                            )
                            Error = ""
                            ExitCode = 0 
                        }
                    } elseif ($ArgumentList -contains "--version") {
                        return @{
                            Success = $true
                            Output = "2025.3.26"
                            Error = ""
                            ExitCode = 0
                        }
                    }
                }
                $result = $ytDlpService.CheckUpdates()
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Не удалось определить текущую или последнюю версию"
            }
        }

        It "Should handle identical versions returned by alternative method" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                # Мокируем только Invoke-ExternalProcess, не CheckUpdates!
                Mock Invoke-ExternalProcess {
                    if ($ArgumentList -contains "versions") {
                        return @{ 
                            Success = $true
                            Output = @(
                                "yt-dlp (2025.3.31)",
                                "Available versions: 2025.3.31, 2025.3.27, 2025.3.26, 2025.3.25"
                            )
                            Error = ""
                            ExitCode = 0 
                        }
                    } elseif ($ArgumentList -contains "--version") {
                        return @{
                            Success = $true
                            Output = "2025.3.31"
                            Error = ""
                            ExitCode = 0
                        }
                    }
                }
                $result = $ytDlpService.CheckUpdates()
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Не удалось определить текущую или последнюю версию"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}