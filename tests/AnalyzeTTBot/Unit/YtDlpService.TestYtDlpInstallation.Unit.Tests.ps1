#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода TestYtDlpInstallation сервиса YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода TestYtDlpInstallation сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "YtDlpService.TestYtDlpInstallation Tests" {
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

    Context "Installation detection" {
        It "Should detect yt-dlp installation correctly" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" }
                # Не мокируем CheckUpdates, тестируем реальную логику
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return @{ Success = $true; Data = @{ CurrentVersion = "2025.03.26"; NewVersion = "2025.03.31"; NeedsUpdate = $true } }
                } -Force
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeTrue
                $result.Data.Name | Should -Be "yt-dlp"
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "2025.03.26"
                $result.Data.Description | Should -Match "Version 2025.03.26 detected"
            }
        }

        It "Should detect yt-dlp installation correctly (with and without SkipCheckUpdates)" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" }
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return @{ Success = $true; Data = @{ CurrentVersion = "2025.03.26"; NewVersion = "2025.03.31"; NeedsUpdate = $true } }
                } -Force
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeTrue
                $result.Data.Name | Should -Be "yt-dlp"
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "2025.03.26"
                $result.Data.Description | Should -Match "Version 2025.03.26 detected"
                $result.Data.CheckUpdatesResult | Should -Not -BeNullOrEmpty
                $result.Data.CheckUpdatesResult.NeedsUpdate | Should -BeTrue
                $result.Data.CheckUpdatesResult.CurrentVersion | Should -Be "2025.03.26"
                $result.Data.CheckUpdatesResult.NewVersion | Should -Be "2025.03.31"
                $result.Data.SkipCheckUpdates | Should -BeFalse
                # Проверка с SkipCheckUpdates
                $resultSkip = $ytDlpService.TestYtDlpInstallation([switch]::Present)
                $resultSkip.Success | Should -BeTrue
                $resultSkip.Data.Name | Should -Be "yt-dlp"
                $resultSkip.Data.Valid | Should -BeTrue
                $resultSkip.Data.Version | Should -Be "2025.03.26"
                $resultSkip.Data.Description | Should -Match "Version 2025.03.26 detected"
                $resultSkip.Data.CheckUpdatesResult | Should -BeNullOrEmpty
                $resultSkip.Data.SkipCheckUpdates | Should -BeTrue
            }
        }

        It "Should detect yt-dlp installation correctly (with and without SkipCheckUpdates, all fields)" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" }
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return @{ Success = $true; Data = @{ CurrentVersion = "2025.03.26"; NewVersion = "2025.03.31"; NeedsUpdate = $true } }
                } -Force
                # Проверка с CheckUpdates (по умолчанию)
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result | Should -BeOfType hashtable
                $result.Success | Should -BeTrue
                $result.Keys -contains 'Data' | Should -BeTrue
                $result.Data | Should -BeOfType hashtable
                $result.Data.Keys -contains 'Name' | Should -BeTrue
                $result.Data.Name | Should -BeExactly 'yt-dlp'
                $result.Data.Keys -contains 'Valid' | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Keys -contains 'Version' | Should -BeTrue
                $result.Data.Version | Should -BeExactly '2025.03.26'
                $result.Data.Keys -contains 'Description' | Should -BeTrue
                $result.Data.Description | Should -Match "Version 2025.03.26 detected"
                $result.Data.Keys -contains 'CheckUpdatesResult' | Should -BeTrue
                $result.Data.CheckUpdatesResult | Should -BeOfType hashtable
                $result.Data.CheckUpdatesResult.Keys -contains 'CurrentVersion' | Should -BeTrue
                $result.Data.CheckUpdatesResult.CurrentVersion | Should -BeExactly '2025.03.26'
                $result.Data.CheckUpdatesResult.Keys -contains 'NewVersion' | Should -BeTrue
                $result.Data.CheckUpdatesResult.NewVersion | Should -BeExactly '2025.03.31'
                $result.Data.CheckUpdatesResult.Keys -contains 'NeedsUpdate' | Should -BeTrue
                $result.Data.CheckUpdatesResult.NeedsUpdate | Should -BeTrue
                $result.Data.Keys -contains 'SkipCheckUpdates' | Should -BeTrue
                $result.Data.SkipCheckUpdates | Should -BeFalse
                # Проверка набора ключей (PowerShell 5.1 совместимо)
                $expectedKeys = @('Name','Valid','Version','Description','CheckUpdatesResult','SkipCheckUpdates')
                foreach ($key in $expectedKeys) { $result.Data.Keys | Should -Contain $key }
                ($result.Data.Keys.Count -eq $expectedKeys.Count) | Should -BeTrue
                # Проверка с SkipCheckUpdates
                $resultSkip = $ytDlpService.TestYtDlpInstallation([switch]::Present)
                $resultSkip | Should -BeOfType hashtable
                $resultSkip.Success | Should -BeTrue
                $resultSkip.Keys -contains 'Data' | Should -BeTrue
                $resultSkip.Data | Should -BeOfType hashtable
                $resultSkip.Data.Keys -contains 'Name' | Should -BeTrue
                $resultSkip.Data.Name | Should -BeExactly 'yt-dlp'
                $resultSkip.Data.Keys -contains 'Valid' | Should -BeTrue
                $resultSkip.Data.Valid | Should -BeTrue
                $resultSkip.Data.Keys -contains 'Version' | Should -BeTrue
                $resultSkip.Data.Version | Should -BeExactly '2025.03.26'
                $resultSkip.Data.Keys -contains 'Description' | Should -BeTrue
                $resultSkip.Data.Description | Should -Match "Version 2025.03.26 detected"
                $resultSkip.Data.Keys -contains 'CheckUpdatesResult' | Should -BeTrue
                $resultSkip.Data.CheckUpdatesResult | Should -BeNullOrEmpty
                $resultSkip.Data.Keys -contains 'SkipCheckUpdates' | Should -BeTrue
                $resultSkip.Data.SkipCheckUpdates | Should -BeTrue
                foreach ($key in $expectedKeys) { $resultSkip.Data.Keys | Should -Contain $key }
                ($resultSkip.Data.Keys.Count -eq $expectedKeys.Count) | Should -BeTrue
            }
        }

        It "Should handle missing yt-dlp" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ Success = $false; Output = ""; Error = "Command not found: yt-dlp"; ExitCode = 1 }
                } -ParameterFilter { $ArgumentList -contains "--version" }
                # Не мокируем CheckUpdates, тестируем реальную логику
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "yt-dlp returned error"
                $result.Data | Should -BeNullOrEmpty
            }
        }

        It "Should handle exception during test" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess { throw "Test exception" } -ParameterFilter { $ArgumentList -contains "--version" }
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result.Success | Should -BeFalse
                $result.error | Should -Match "Failed to test yt-dlp"
                $result.Data | Should -BeNullOrEmpty
            }
        }

        It "Should return correct structure for success and error" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ Success = $true; Output = "2025.03.26"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ArgumentList -contains "--version" }
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "CheckUpdates" -Value {
                    return @{ Success = $true; Data = @{ CurrentVersion = "2025.03.26"; NewVersion = "2025.03.31"; NeedsUpdate = $true } }
                } -Force
                $result = $ytDlpService.TestYtDlpInstallation($null)
                $result | Should -BeOfType hashtable
                $result.Data | Should -BeOfType hashtable
                $result.Data.Keys -contains 'Name' | Should -BeTrue
                $result.Data.Keys -contains 'Valid' | Should -BeTrue
                $result.Data.Keys -contains 'Version' | Should -BeTrue
                $result.Data.Keys -contains 'Description' | Should -BeTrue
                $result.Data.Keys -contains 'CheckUpdatesResult' | Should -BeTrue
                $result.Data.Keys -contains 'SkipCheckUpdates' | Should -BeTrue
                # Ошибка
                Mock Invoke-ExternalProcess {
                    return @{ Success = $false; Output = ""; Error = "fail"; ExitCode = 1 }
                } -ParameterFilter { $ArgumentList -contains "--version" }
                $resultErr = $ytDlpService.TestYtDlpInstallation($null)
                $resultErr | Should -BeOfType hashtable
                $resultErr.Keys -contains 'Error' | Should -BeTrue
                $resultErr.Success | Should -BeFalse
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}