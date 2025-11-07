#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода FindOutputFile в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода FindOutputFile сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'YtDlpService.FindOutputFile method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    
    Context 'When output file does not exist at expected path' {
        It 'Returns empty string when directory does not exist' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Test-Path { return $false } -ParameterFilter { $Path -like "*nonexistent_dir*" }
                Mock Write-PSFMessage { }

                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

                # Act
                $result = $ytDlpService.FindOutputFile("C:\nonexistent_dir\video.mp4")

                # Assert
                $result | Should -BeExactly ""
                Should -Invoke Write-PSFMessage -ParameterFilter {
                    $Message -like "*Output directory does not exist*" -and $Level -eq 'Warning'
                }
            }
        }
        
        It 'Returns empty string when no matching files are found' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Test-Path { return $true }
                Mock Get-ChildItem { return @() }
                Mock Write-PSFMessage { }

                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

                # Act
                $result = $ytDlpService.FindOutputFile("C:\existing_dir\video.mp4")

                # Assert
                $result | Should -BeExactly ""
                Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*No matching files found in directory*" -and $Level -eq 'Warning'
                }
            }
        }
        
        It 'Returns the most recently created matching file' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Test-Path { return $true }

                $mockFiles = @(
                    [PSCustomObject]@{
                        FullName = "C:\existing_dir\video[01].mp4"
                        LastWriteTime = (Get-Date).AddMinutes(-1)
                        Extension = ".mp4"
                    },
                    [PSCustomObject]@{
                        FullName = "C:\existing_dir\video[02].mp4"
                        LastWriteTime = (Get-Date).AddSeconds(-30)
                        Extension = ".mp4"
                    }
                )

                Mock Get-ChildItem { return $mockFiles }
                Mock Write-PSFMessage { }

                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

                # Act
                $result = $ytDlpService.FindOutputFile("C:\existing_dir\video.mp4")

                # Assert - нормализуем путь для кросс-платформенности
                $result | Should -Match "video\[02\]\.mp4"
                Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*Found recently created file*" -and $Level -eq 'Debug'
                }
            }
        }
        
        It 'Only returns files with valid media extensions' {
            InModuleScope AnalyzeTTBot {
                # Arrange
                Mock Test-Path { return $true }

                $mockFiles = @(
                    [PSCustomObject]@{
                        FullName = "C:\existing_dir\video.txt"
                        LastWriteTime = (Get-Date).AddSeconds(-10)
                        Extension = ".txt"
                    },
                    [PSCustomObject]@{
                        FullName = "C:\existing_dir\video.mp4"
                        LastWriteTime = (Get-Date).AddMinutes(-1)
                        Extension = ".mp4"
                    }
                )

                Mock Get-ChildItem { return $mockFiles }
                Mock Write-PSFMessage { }

                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

                # Act
                $result = $ytDlpService.FindOutputFile("C:\existing_dir\video.mp4")

                # Assert - нормализуем путь для кросс-платформенности
                $result | Should -Match "video\.mp4"
                Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter {
                    $Message -like "*Found recently created file*" -and $Level -eq 'Debug'
                }
            }
        }
    }
}

