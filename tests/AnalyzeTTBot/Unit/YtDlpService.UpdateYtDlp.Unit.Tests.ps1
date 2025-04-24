#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода UpdateYtDlp сервиса YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода UpdateYtDlp сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "YtDlpService.UpdateYtDlp Tests" {
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

    Context "Update functionality" {
        It "Should update yt-dlp successfully" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ success = $true; Output = "yt-dlp is up to date (2025.03.26)"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ExecutablePath -eq "yt-dlp" -and $ArgumentList -contains "-U" }
                $result = $ytDlpService.UpdateYtDlp()
                $result.Success | Should -BeTrue
                $result.data.Status | Should -Be "Success"
                $result.data.IsUpToDate | Should -BeTrue
            }
        }

        It "Should handle update failures" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ success = $false; Output = ""; Error = "Error updating yt-dlp"; ExitCode = 1 }
                } -ParameterFilter { $ExecutablePath -eq "yt-dlp" -and $ArgumentList -contains "-U" }
                $result = $ytDlpService.UpdateYtDlp()
                $result.Success | Should -BeFalse
                $result.error | Should -Match "Process failed with exit code"
            }
        }

        It "Should report update successful when yt-dlp is updated" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                Mock Invoke-ExternalProcess {
                    return @{ success = $true; Output = "Updated yt-dlp to version 2025.04.01"; Error = ""; ExitCode = 0 }
                } -ParameterFilter { $ExecutablePath -eq "yt-dlp" -and $ArgumentList -contains "-U" }
                $result = $ytDlpService.UpdateYtDlp()
                $result.Success | Should -BeTrue
                $result.data.Status | Should -Be "Success"
                $result.data.IsUpToDate | Should -BeFalse
                $result.data.Message | Should -Match "Updated yt-dlp"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}