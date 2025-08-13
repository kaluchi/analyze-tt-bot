#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ExecuteYtDlp в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ExecuteYtDlp сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe 'YtDlpService.ExecuteYtDlp method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Возвращает ошибку, если yt-dlp завершился с ошибкой' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ Success = $false; ExitCode = 1; Output = @('error'); Error = 'fail' }
            }
            $result = $ytDlpService.ExecuteYtDlp('url', 'output')
            $result.Success | Should -BeFalse
            # Проверяем наличие ErrorMessage или Error
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
            if ($result.ErrorMessage) { $result.ErrorMessage | Should -Match 'yt-dlp process failed' }
            if ($result.Error) { $result.Error | Should -Match 'yt-dlp process failed' }
        }
    }
    It 'Возвращает ошибку, если в выводе yt-dlp есть ERROR:' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ Success = $true; ExitCode = 0; Output = @('ERROR: something bad happened'); Error = '' }
            }
            $result = $ytDlpService.ExecuteYtDlp('url', 'output')
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
            if ($result.ErrorMessage) { $result.ErrorMessage | Should -Match 'something bad happened' }
            if ($result.Error) { $result.Error | Should -Match 'something bad happened' }
        }
    }
    It 'Возвращает ошибку при исключении' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                throw "Test exception"
            }
            $result = $ytDlpService.ExecuteYtDlp('url', 'output')
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
            if ($result.ErrorMessage) { $result.ErrorMessage | Should -Match 'Failed to execute yt-dlp' }
            if ($result.Error) { $result.Error | Should -Match 'Failed to execute yt-dlp' }
        }
    }
    It 'Должен возвращать ошибку, если FindAndReadJsonMetadata возвращает null' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            # Унифицированные моки для файловой системы
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            Mock -CommandName Get-ChildItem -ModuleName AnalyzeTTBot -MockWith { @() }
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { $true }
            Mock -CommandName Remove-Item -ModuleName AnalyzeTTBot -MockWith { $null }
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Read-JsonFile -ModuleName AnalyzeTTBot -MockWith { $null }
            Mock -CommandName Write-JsonFile -ModuleName AnalyzeTTBot -MockWith { $null }
            $result = $ytDlpService.SaveTikTokVideo('https://tiktok.com/video/err', 'output.mp4')
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
        }
    }
    It 'Должен возвращать ошибку при ошибке обновления yt-dlp (UpdateYtDlp)' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ Success = $false; ExitCode = 1; Output = @('fail'); Error = 'fail' }
            }
            $result = $ytDlpService.UpdateYtDlp()
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
        }
    }
    It 'Должен возвращать ошибку при неожиданном выводе UpdateYtDlp' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ Success = $true; ExitCode = 0; Output = @('Some unknown output'); Error = '' }
            }
            $result = $ytDlpService.UpdateYtDlp()
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
        }
    }
    It 'Должен возвращать ошибку при ошибке CheckUpdates' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ Success = $false; ExitCode = 1; Output = @('fail'); Error = 'fail' }
            }
            $result = $ytDlpService.CheckUpdates()
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
        }
    }
    It 'Должен возвращать ошибку при ошибке TestYtDlpInstallation' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ Success = $false; ExitCode = 1; Output = @('fail'); Error = 'fail' }
            }
            $result = $ytDlpService.TestYtDlpInstallation([switch]$false)
            $result.Success | Should -BeFalse
            ($result.ErrorMessage -or $result.Error) | Should -Not -BeNullOrEmpty
        }
    }
}

