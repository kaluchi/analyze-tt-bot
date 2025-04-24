<#
.SYNOPSIS
    Тесты для ChocoHelper.
.DESCRIPTION
    Модульные тесты для проверки функциональности ChocoHelper, используемого для работы с Chocolatey.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "ChocoHelper" {
    BeforeAll {
        # Эта строка необходима для корректной работы PSFramework
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        
        # Определяем пути к модулю
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..") 
        $modulePath = Join-Path -Path $projectRoot -ChildPath "src\AnalyzeTTBot"
        $manifestPath = Join-Path -Path $modulePath -ChildPath "AnalyzeTTBot.psd1"
        
        # Проверяем наличие модуля и импортируем его
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        
        # Проверяем успешность импорта модуля
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        
        # Проверяем наличие PSFramework
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
    }
    
    Context "Get-Choco-List Tests" {
        It "Should return an array of installed packages when execution is successful" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess для успешного выполнения
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = @"
Chocolatey v2.3.0
ant 1.10.14
bazelisk 1.20.0
chocolatey 2.3.0
chromium 128.0.6613.114
exiftool 13.25.0
mediainfo-cli 25.3.0
nodejs-lts 20.17.0
pnpm 10.8.0
8 packages installed.
"@
                        Error = ""
                        TimedOut = $false
                        Command = "choco list"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "list" }
                
                # Тестируем функцию
                $result = Get-Choco-List
                
                # Проверяем результат
                $result | Should -HaveCount 8
                $result[0].Name | Should -Be "ant"
                $result[0].Version | Should -Be "1.10.14"
                $result[3].Name | Should -Be "chromium"
                $result[3].Version | Should -Be "128.0.6613.114"
                $result[-1].Name | Should -Be "pnpm"
                $result[-1].Version | Should -Be "10.8.0"
            }
        }
        
        It "Should handle empty package list correctly" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess для случая без установленных пакетов
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = @"
Chocolatey v2.3.0
0 packages installed.
"@
                        Error = ""
                        TimedOut = $false
                        Command = "choco list"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "list" }
                
                # Тестируем функцию
                $result = Get-Choco-List
                
                # Проверяем результат
                $result | Should -HaveCount 0
            }
        }
        
        It "Should return empty array on execution failure" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess для неуспешного выполнения
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $false
                        ExitCode = 1
                        Output = ""
                        Error = "Chocolatey not found"
                        TimedOut = $false
                        Command = "choco list"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "list" }
                
                # Тестируем функцию
                $result = Get-Choco-List
                
                # Проверяем результат
                $result | Should -HaveCount 0
            }
        }
        
        It "Should handle exception when parsing output" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess с некорректным выводом
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = $null  # Некорректный вывод
                        Error = ""
                        TimedOut = $false
                        Command = "choco list"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "list" }
                
                # Тестируем функцию
                $result = Get-Choco-List
                
                # Проверяем результат
                $result | Should -HaveCount 0
            }
        }
    }
    
    Context "Get-Choco-Outdated Tests" {
        It "Should return array of outdated packages when execution is successful" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess для успешного выполнения
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = @"
Chocolatey v2.3.0
Outdated Packages
 Output is package name | current version | available version | pinned?     

ant|1.10.14|1.10.15|false
bazelisk|1.20.0|1.26.0|false
chocolatey|2.3.0|2.4.3|false
chromium|128.0.6613.114|135.0.7049.96|false
exiftool|13.25.0|13.27.0|false
nodejs-lts|20.17.0|22.14.0|false
pnpm|10.8.0|10.8.1|false

Chocolatey has determined 7 package(s) are outdated.
"@
                        Error = ""
                        TimedOut = $false
                        Command = "choco outdated"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "outdated" }
                
                # Тестируем функцию
                $result = Get-Choco-Outdated
                
                # Проверяем результат
                $result | Should -HaveCount 7
                $result[0].Name | Should -Be "ant"
                $result[0].CurrentVersion | Should -Be "1.10.14"
                $result[0].AvailableVersion | Should -Be "1.10.15"
                $result[0].Pinned | Should -BeFalse
                $result[3].Name | Should -Be "chromium"
                $result[3].CurrentVersion | Should -Be "128.0.6613.114"
                $result[3].AvailableVersion | Should -Be "135.0.7049.96"
                $result[3].Pinned | Should -BeFalse
            }
        }
        
        It "Should handle no outdated packages correctly" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess для случая без устаревших пакетов
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = @"
Chocolatey v2.3.0
Outdated Packages
 Output is package name | current version | available version | pinned?     

Chocolatey has determined 0 package(s) are outdated.
"@
                        Error = ""
                        TimedOut = $false
                        Command = "choco outdated"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "outdated" }
                
                # Тестируем функцию
                $result = Get-Choco-Outdated
                
                # Проверяем результат
                $result | Should -HaveCount 0
            }
        }
        
        It "Should return empty array on execution failure" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess для неуспешного выполнения
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $false
                        ExitCode = 1
                        Output = ""
                        Error = "Chocolatey not found"
                        TimedOut = $false
                        Command = "choco outdated"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "outdated" }
                
                # Тестируем функцию
                $result = Get-Choco-Outdated
                
                # Проверяем результат
                $result | Should -HaveCount 0
            }
        }
        
        It "Should handle package with pinned status correctly" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess с pinned пакетом
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = @"
Chocolatey v2.3.0
Outdated Packages
 Output is package name | current version | available version | pinned?     

nodejs-lts|20.17.0|22.14.0|true

Chocolatey has determined 1 package(s) are outdated.
"@
                        Error = ""
                        TimedOut = $false
                        Command = "choco outdated"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "outdated" }
                
                # Тестируем функцию
                $result = Get-Choco-Outdated
                
                # Проверяем результат
                $result | Should -HaveCount 1
                $result[0].Name | Should -Be "nodejs-lts"
                $result[0].Pinned | Should -BeTrue
            }
        }
        
        It "Should handle exception when parsing output" {
            InModuleScope AnalyzeTTBot {
                # Мокируем Invoke-ExternalProcess с некорректным выводом
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = $null  # Некорректный вывод
                        Error = ""
                        TimedOut = $false
                        Command = "choco outdated"
                    }
                } -ParameterFilter { $ExecutablePath -eq "choco" -and $ArgumentList -contains "outdated" }
                
                # Тестируем функцию
                $result = Get-Choco-Outdated
                
                # Проверяем результат
                $result | Should -HaveCount 0
            }
        }
    }
    
    AfterAll {
        # Очистка после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
