#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ExecuteYtDlp в YtDlpService - сетевые ошибки.
.DESCRIPTION
    Модульные тесты для проверки обработки сетевых ошибок в методе ExecuteYtDlp сервиса YtDlpService.
    Фокус на непокрытых сценариях сетевых ошибок (строки 139-162).
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'YtDlpService.ExecuteYtDlp network errors' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    
    It 'Должен обрабатывать таймаут сети' {
        InModuleScope AnalyzeTTBot {
            Mock Write-OperationFailed { } -ModuleName AnalyzeTTBot
            
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 1, "best", "") # Короткий таймаут
            
            # Мокаем Invoke-ExternalProcess для симуляции таймаута
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ 
                    Success = $false
                    ExitCode = -1
                    Output = @('ERROR: Network timeout: Unable to download webpage')
                    Error = 'Process timed out'
                }
            }
            
            $result = $ytDlpService.ExecuteYtDlp('https://tiktok.com/slow-video', 'output.mp4')
            
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Network timeout'
            
            # Проверяем логирование ошибки таймаута
            Should -Invoke -CommandName Write-OperationFailed -ModuleName AnalyzeTTBot -ParameterFilter {
                $Operation -eq "Execute yt-dlp"
            }
        }
    }
    
    It 'Должен обрабатывать отсутствие сетевого подключения' {
        InModuleScope AnalyzeTTBot {
            Mock Write-OperationFailed { } -ModuleName AnalyzeTTBot
            
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем Invoke-ExternalProcess для симуляции отсутствия сети
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ 
                    Success = $false
                    ExitCode = 1
                    Output = @('ERROR: Unable to extract data: Network is unreachable', 'ERROR: No internet connection')
                    Error = 'Network error'
                }
            }
            
            $result = $ytDlpService.ExecuteYtDlp('https://tiktok.com/video/123', 'output.mp4')
            
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Unable to extract data'
            
            # Проверяем логирование ошибки сети
            Should -Invoke -CommandName Write-OperationFailed -ModuleName AnalyzeTTBot -Exactly 1
        }
    }
    
    It 'Должен обрабатывать HTTP ошибки' {
        InModuleScope AnalyzeTTBot {
            Mock Write-OperationFailed { } -ModuleName AnalyzeTTBot
            
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем Invoke-ExternalProcess для симуляции HTTP ошибки
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{ 
                    Success = $false
                    ExitCode = 1
                    Output = @('ERROR: HTTP Error 403: Forbidden', 'ERROR: Access denied')
                    Error = 'HTTP error'
                }
            }
            
            $result = $ytDlpService.ExecuteYtDlp('https://tiktok.com/private-video', 'output.mp4')
            
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'HTTP Error 403|Access denied'
        }
    }
}

