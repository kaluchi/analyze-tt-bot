#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты обработки ошибок для метода CheckUpdates в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки обработки различных ошибочных ситуаций 
    при проверке обновлений yt-dlp в методе CheckUpdates.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'YtDlpService.CheckUpdates Error Handling Tests' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    
    Context 'When pip command fails' {
        It 'Returns error response when pip command execution fails' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $false
                        ExitCode = 1
                        Error = "pip command not found"
                        Output = ""
                    }
                } -ParameterFilter { $ExecutablePath -eq "pip" }
                
                Mock Write-OperationFailed { }
                Mock Write-OperationStart { }
                Mock Write-PSFMessage { }
                
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                
                # Act
                $result = $ytDlpService.CheckUpdates()
                
                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Match "Не удалось получить список версий yt-dlp через pip index"
                Should -Invoke Write-OperationFailed -ParameterFilter { 
                    $Operation -eq "Check yt-dlp updates" -and 
                    $ErrorMessage -like "*Не удалось получить список версий yt-dlp через pip index*"
                }
            }
        }
        
        It 'Returns error response when pip output is missing version information' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = ""
                        Output = @(
                            "Available versions of yt-dlp:"
                        )
                    }
                } -ParameterFilter { $ExecutablePath -eq "pip" }
                
                Mock Write-OperationFailed { }
                Mock Write-OperationStart { }
                Mock Write-PSFMessage { }
                
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                
                # Act
                $result = $ytDlpService.CheckUpdates()
                
                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Match "Не удалось определить текущую или последнюю версию yt-dlp"
                Should -Invoke Write-OperationFailed -ParameterFilter { 
                    $Operation -eq "Check yt-dlp updates" -and 
                    $ErrorMessage -like "*Не удалось определить текущую или последнюю версию yt-dlp*"
                }
            }
        }
        
        It 'Returns error response when unexpected exception occurs' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Invoke-ExternalProcess {
                    throw "Unexpected network error"
                } -ParameterFilter { $ExecutablePath -eq "pip" }
                
                Mock Write-OperationFailed { }
                Mock Write-OperationStart { }
                
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService,
                30, "best")
                
                # Act
                $result = $ytDlpService.CheckUpdates()
                
                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Match "Failed to check yt-dlp updates: Unexpected network error"
                Should -Invoke Write-OperationFailed -ParameterFilter { 
                    $Operation -eq "Check yt-dlp updates" -and 
                    $ErrorMessage -like "*Failed to check yt-dlp updates: Unexpected network error*"
                }
            }
        }
    }
    
    Context 'When pip returns partial information' {
        It 'Handles missing LATEST line' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = ""
                        Output = @(
                            "INSTALLED: 2023.10.13"
                        )
                    }
                } -ParameterFilter { $ExecutablePath -eq "pip" }
                
                Mock Write-OperationFailed { }
                Mock Write-OperationStart { }
                Mock Write-PSFMessage { }
                
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                
                # Act
                $result = $ytDlpService.CheckUpdates()
                
                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Match "Не удалось определить текущую или последнюю версию yt-dlp"
            }
        }
        
        It 'Handles missing INSTALLED line' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = ""
                        Output = @(
                            "LATEST: 2023.11.14"
                        )
                    }
                } -ParameterFilter { $ExecutablePath -eq "pip" }
                
                Mock Write-OperationFailed { }
                Mock Write-OperationStart { }
                Mock Write-PSFMessage { }
                
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
                
                # Act
                $result = $ytDlpService.CheckUpdates()
                
                # Assert
                $result.Success | Should -Be $false
                $result.Error | Should -Match "Не удалось определить текущую или последнюю версию yt-dlp"
            }
        }
    }
}