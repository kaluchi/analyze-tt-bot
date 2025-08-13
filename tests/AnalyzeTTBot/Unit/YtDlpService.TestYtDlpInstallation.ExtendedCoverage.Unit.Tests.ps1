#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Расширенные тесты для метода TestYtDlpInstallation в YtDlpService.
.DESCRIPTION
    Дополнительные модульные тесты для покрытия непротестированных веток кода в методе TestYtDlpInstallation.
    Фокус на error handling, edge cases и различные сценарии проверки обновлений.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 13.08.2025
    Цель: Покрыть оставшиеся 22 непокрытые команды из 36
#>

Describe "YtDlpService.TestYtDlpInstallation Extended Coverage Tests" {
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

    Context "Error handling and edge cases" {
        It "Should handle Invoke-ExternalProcess returning null" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем Invoke-ExternalProcess для возврата null
                Mock Invoke-ExternalProcess { return $null } -ModuleName AnalyzeTTBot
                
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "yt-dlp returned error"
            }
        }

        It "Should handle Invoke-ExternalProcess with missing Success property" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем Invoke-ExternalProcess для возврата объекта без Success
                Mock Invoke-ExternalProcess { 
                    return @{ Output = "2025.03.26"; Error = ""; ExitCode = 0 } 
                } -ModuleName AnalyzeTTBot
                
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "yt-dlp returned error"
            }
        }

        It "Should handle CheckUpdates method returning error" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                # Мокируем CheckUpdates для возврата ошибки
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return New-ErrorResponse -ErrorMessage "Failed to check updates: Network error"
                } -Force
                
                $result = $ytDlpService.TestYtDlpInstallation($null)
                
                # Метод должен завершиться успешно, даже если CheckUpdates не сработал
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "2025.03.26"
                # CheckUpdatesResult должен быть null при ошибке
                $result.Data.CheckUpdatesResult | Should -BeNullOrEmpty
            }
        }

        It "Should handle CheckUpdates returning null or malformed response" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                # Тест 1: CheckUpdates возвращает null
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return $null
                } -Force
                
                $result1 = $ytDlpService.TestYtDlpInstallation($null)
                $result1.Success | Should -BeTrue
                $result1.Data.CheckUpdatesResult | Should -BeNullOrEmpty
                
                # Тест 2: CheckUpdates возвращает объект без Success
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return @{ Data = @{} } # Missing Success property
                } -Force
                
                $result2 = $ytDlpService.TestYtDlpInstallation($null)
                $result2.Success | Should -BeTrue
                $result2.Data.CheckUpdatesResult | Should -BeNullOrEmpty
            }
        }

        It "Should handle different exit codes from yt-dlp" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Тест с exit code 127 (command not found)
                Mock Invoke-ExternalProcess {
                    return @{ Success = $false; Output = ""; Error = "yt-dlp: command not found"; ExitCode = 127 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                $result1 = $ytDlpService.TestYtDlpInstallation($null)
                $result1.Success | Should -BeFalse
                $result1.Error | Should -Match "yt-dlp returned error"
                
                # Тест с exit code 2 (other error)
                Mock Invoke-ExternalProcess {
                    return @{ Success = $false; Output = ""; Error = "Permission denied"; ExitCode = 2 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                $result2 = $ytDlpService.TestYtDlpInstallation($null)
                $result2.Success | Should -BeFalse
                $result2.Error | Should -Match "yt-dlp returned error"
            }
        }

        It "Should handle empty or whitespace version output" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Тест с пустым выводом
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = ""; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                $result1 = $ytDlpService.TestYtDlpInstallation($null)
                $result1.Success | Should -BeTrue
                $result1.Data.Version | Should -Be ""
                $result1.Data.Description | Should -Match "Version  detected"
                
                # Тест с whitespace выводом
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "   "; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                $result2 = $ytDlpService.TestYtDlpInstallation($null)
                $result2.Success | Should -BeTrue
                $result2.Data.Version | Should -Be ""
            }
        }

        It "Should handle complex version strings correctly" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Тест с многострочным выводом
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26`nAdditional info"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return New-SuccessResponse -Data @{ 
                        CurrentVersion = "2025.03.26`nAdditional info"
                        NewVersion = "2025.04.01"
                        NeedsUpdate = $true 
                    }
                } -Force
                
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeTrue
                $result.Data.Version | Should -Be "2025.03.26`nAdditional info"
                $result.Data.Description | Should -Match "Version 2025.03.26"
            }
        }

        It "Should correctly set SkipCheckUpdates flag in different scenarios" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                # Тест 1: SkipCheckUpdates = false (по умолчанию)
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return New-SuccessResponse -Data @{ 
                        CurrentVersion = "2025.03.26"
                        NewVersion = "2025.04.01"
                        NeedsUpdate = $true 
                    }
                } -Force
                
                $result1 = $ytDlpService.TestYtDlpInstallation($false)
                $result1.Data.SkipCheckUpdates | Should -BeFalse
                $result1.Data.CheckUpdatesResult | Should -Not -BeNullOrEmpty
                
                # Тест 2: SkipCheckUpdates = true
                $result2 = $ytDlpService.TestYtDlpInstallation($true)
                $result2.Data.SkipCheckUpdates | Should -BeTrue
                $result2.Data.CheckUpdatesResult | Should -BeNullOrEmpty
                
                # Тест 3: передача $null (должно интерпретироваться как false)
                $result3 = $ytDlpService.TestYtDlpInstallation($null)
                $result3.Data.SkipCheckUpdates | Should -BeFalse
                $result3.Data.CheckUpdatesResult | Should -Not -BeNullOrEmpty
            }
        }

        It "Should provide detailed error information when version check fails" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                Mock Invoke-ExternalProcess {
                    return @{ 
                        Success = $false
                        Output = "Partial output before error"
                        Error = "ERROR: Access denied to executable file"
                        ExitCode = 1 
                    }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeFalse
                # Ошибка должна содержать подробную информацию
                $result.Error | Should -Match "yt-dlp returned error"
                $result.Error | Should -Match "Access denied to executable file"
            }
        }
    }

    Context "Integration with CheckUpdates method" {
        It "Should handle CheckUpdates success with different update scenarios" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2024.12.01"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" } -ModuleName AnalyzeTTBot
                
                # Сценарий 1: Обновление необходимо
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return New-SuccessResponse -Data @{ 
                        CurrentVersion = "2024.12.01"
                        NewVersion = "2025.03.26"
                        NeedsUpdate = $true 
                    }
                } -Force
                
                $result1 = $ytDlpService.TestYtDlpInstallation($null)
                $result1.Success | Should -BeTrue
                $result1.Data.CheckUpdatesResult.NeedsUpdate | Should -BeTrue
                $result1.Data.CheckUpdatesResult.NewVersion | Should -Be "2025.03.26"
                
                # Сценарий 2: Обновление не нужно
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return New-SuccessResponse -Data @{ 
                        CurrentVersion = "2025.03.26"
                        NewVersion = "2025.03.26"
                        NeedsUpdate = $false 
                    }
                } -Force
                
                $result2 = $ytDlpService.TestYtDlpInstallation($null)
                $result2.Success | Should -BeTrue
                $result2.Data.CheckUpdatesResult.NeedsUpdate | Should -BeFalse
                $result2.Data.CheckUpdatesResult.CurrentVersion | Should -Be "2025.03.26"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
