#region MediaInfoExtractorService.TestMediaInfoDependency.Unit.Tests

<#
.SYNOPSIS
    Тесты для метода TestMediaInfoDependency класса MediaInfoExtractorService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода TestMediaInfoDependency.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 22.04.2025 - Заменено мокирование System.Diagnostics.Process на мокирование Invoke-ExternalProcess
#>

Describe 'MediaInfoExtractorService.TestMediaInfoDependency method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Возвращает успешный результат при корректной установке MediaInfo' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Invoke-ExternalProcess
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = "MediaInfo v21.09"
                    Error = ""
                    TimedOut = $false
                    Command = "mediainfo --version"
                }
            } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }
            
            # Мокаем Get-Choco-Outdated
            Mock Get-Choco-Outdated -ModuleName AnalyzeTTBot -MockWith {
                return @()
            }
            
            # Вызываем тестируемый метод
            $result = $mediaInfoService.TestMediaInfoDependency($null)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Name | Should -Be "MediaInfo"
            $result.Data.Valid | Should -BeTrue
            $result.Data.Version | Should -Match "v21.09"
            $result.Data.Description | Should -Match "MediaInfo v21.09 найден"
        }
    }

    It 'Возвращает ошибку, если MediaInfo не найден (ExitCode не 0)' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Invoke-ExternalProcess для имитации ситуации, когда MediaInfo не найден
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $false
                    ExitCode = 1
                    Output = "Command not found"
                    Error = "mediainfo is not recognized"
                    TimedOut = $false
                    Command = "mediainfo --version"
                }
            } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }
            
            # Вызываем тестируемый метод
            $result = $mediaInfoService.TestMediaInfoDependency($null)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Name | Should -Be "MediaInfo"
            $result.Data.Valid | Should -BeFalse
            $result.Data.Version | Should -Be "Не найден"
            $result.Data.Description | Should -Match "MediaInfo не найден"
        }
    }

    It 'Обрабатывает ошибку запуска процесса MediaInfo' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Invoke-ExternalProcess для имитации ошибки
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                throw "Could not start process"
            } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }
            
            # Вызываем тестируемый метод
            $result = $mediaInfoService.TestMediaInfoDependency($null)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Ошибка при проверке"
            $result.Data.Name | Should -Be "MediaInfo"
            $result.Data.Valid | Should -BeFalse
            $result.Data.Version | Should -Be "Неизвестно"
        }
    }

    It 'Корректно обрабатывает версию MediaInfo из вывода' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Тестовые случаи для разных версий MediaInfo
            $testCases = @(
                @{ Output = "MediaInfo v22.03"; ExpectedVersion = "v22.03" }
                @{ Output = "MediaInfo CLI v22.03"; ExpectedVersion = "v22.03" }
                @{ Output = "MediaInfo Command line, MediaInfoLib - v21.09"; ExpectedVersion = "v21.09" }
                @{ Output = "v21.09"; ExpectedVersion = "v21.09" }
                @{ Output = "MediaInfo v25.03.1"; ExpectedVersion = "v25.03.1" }
            )
            
            # Проверяем каждый тестовый случай
            foreach ($testCase in $testCases) {
                # Мокаем Invoke-ExternalProcess для имитации разных версий MediaInfo
                $currentOutput = $testCase.Output
                Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = $currentOutput
                        Error = ""
                        TimedOut = $false
                        Command = "mediainfo --version"
                    }
                } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }
                
                # Вызываем тестируемый метод
                $result = $mediaInfoService.TestMediaInfoDependency($null)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be $testCase.ExpectedVersion
                $result.Data.Description | Should -Match "MediaInfo.+найден"
            }
        }
    }

    It 'Корректно парсит версию из реального вывода MediaInfo (v25.03)' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)

            # Мокаем Invoke-ExternalProcess для имитации реального вывода MediaInfo
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = "MediaInfo Command line,  MediaInfoLib - v25.03"
                    Error = ""
                    TimedOut = $false
                    Command = "mediainfo --version"
                }
            } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }

            $result = $mediaInfoService.TestMediaInfoDependency($null)

            $result.Success | Should -BeTrue
            $result.Data.Valid | Should -BeTrue
            $result.Data.Version | Should -Be "v25.03"
            $result.Data.Description | Should -Match "MediaInfo v25.03 найден"
        }
    }

    It 'Проверяет обновления при сканировании зависимости' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Invoke-ExternalProcess для успешного выполнения
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = "MediaInfo v25.03"
                    Error = ""
                    TimedOut = $false
                    Command = "mediainfo --version"
                }
            } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }
            
            # Мокаем Get-Choco-Outdated чтобы вернуть что MediaInfo устарел
            Mock Get-Choco-Outdated -ModuleName AnalyzeTTBot -MockWith {
                return @(
                    [PSCustomObject]@{
                        Name = "mediainfo-cli"
                        CurrentVersion = "25.03.0"
                        AvailableVersion = "25.04.0"
                        Pinned = $false
                    }
                )
            }
            Mock Get-Choco-List -ModuleName AnalyzeTTBot -MockWith {
                return @(
                    [PSCustomObject]@{
                        Name = "mediainfo-cli"
                        Version = "25.03.0"
                    }
                )
            }
            
            # Вызываем тестируемый метод
            $result = $mediaInfoService.TestMediaInfoDependency([switch]$false)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Name | Should -Be "MediaInfo"
            $result.Data.Valid | Should -BeTrue
            $result.Data.CheckUpdatesResult.NeedsUpdate | Should -BeTrue
            $result.Data.CheckUpdatesResult.NewVersion | Should -Be "25.04.0"
            $result.Data.CheckUpdatesResult.CurrentVersion | Should -Be "25.03.0"
        }
    }

    It 'Не проверяет обновления при использовании флага SkipCheckUpdates' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Invoke-ExternalProcess для успешного выполнения
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = "MediaInfo v25.03"
                    Error = ""
                    TimedOut = $false
                    Command = "mediainfo --version"
                }
            } -ParameterFilter { $ExecutablePath -eq "mediainfo" -and $ArgumentList -contains "--version" }
            
            # Создаем мок для Get-Choco-Outdated, чтобы можно было проверить, что он не вызывался
            Mock Get-Choco-Outdated -ModuleName AnalyzeTTBot -MockWith { return @() }
            
            # Вызываем тестируемый метод с флагом SkipCheckUpdates
            $result = $mediaInfoService.TestMediaInfoDependency([switch]$true)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Name | Should -Be "MediaInfo"
            $result.Data.Valid | Should -BeTrue
            $result.Data.CheckUpdatesResult | Should -BeNullOrEmpty
            $result.Data.SkipCheckUpdates | Should -BeTrue
            
            # Проверяем, что Get-Choco-Outdated не вызывался
            Assert-MockCalled -CommandName Get-Choco-Outdated -ModuleName AnalyzeTTBot -Times 0 -Scope It
        }
    }

    It 'Проверяет правильность передачи параметров в Invoke-ExternalProcess' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [FileSystemService]::new("temp")
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Invoke-ExternalProcess с проверкой параметров
            Mock Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = "MediaInfo v25.03"
                    Error = ""
                    TimedOut = $false
                    Command = "mediainfo --version"
                }
            } -ParameterFilter { 
                $ExecutablePath -eq "mediainfo" -and 
                $ArgumentList.Count -eq 1 -and 
                $ArgumentList[0] -eq "--version" 
            }
            
            # Вызываем тестируемый метод
            $result = $mediaInfoService.TestMediaInfoDependency($null)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            
            # Проверяем, что мок был вызван с правильными параметрами
            Assert-MockCalled -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -Times 1 -Scope It -ParameterFilter {
                $ExecutablePath -eq "mediainfo" -and 
                $ArgumentList.Count -eq 1 -and 
                $ArgumentList[0] -eq "--version"
            }
        }
    }
}
#endregion
