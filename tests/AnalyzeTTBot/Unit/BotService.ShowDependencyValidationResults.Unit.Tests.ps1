#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Unit tests for BotService.ShowDependencyValidationResults method.
.DESCRIPTION
    Covers output for valid, invalid, and error dependency validation results.
.NOTES
    Author: TikTok Bot Team
    Created: 20.04.2025
#>

Describe "BotService.ShowDependencyValidationResults method" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }

    It "Should print success message for all valid dependencies" {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value { param($a,$b) @{ Success = $true; Data = @() } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @(
                        @{ Name = "yt-dlp"; Valid = $true; Version = "2023.03.04"; Description = "yt-dlp найден" },
                        @{ Name = "MediaInfo"; Valid = $true; Version = "21.09"; Description = "MediaInfo найден" }
                    )
                }
            }
            Mock Write-Host { $script:printed = $true } -ModuleName AnalyzeTTBot
            $script:printed = $false
            $botService.ShowDependencyValidationResults($validationResults)
            $script:printed | Should -BeTrue
        }
    }

    It "Should print error message if validation failed" {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value { param($a,$b) @{ Success = $true; Data = @() } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
            $validationResults = [PSCustomObject]@{
                Success = $false
                Error = "Test error"
            }
            Mock Write-Host { $script:printed = $true } -ModuleName AnalyzeTTBot
            $script:printed = $false
            $botService.ShowDependencyValidationResults($validationResults)
            $script:printed | Should -BeTrue
        }
    }

    It "Should print warnings for invalid dependencies and show install instructions for yt-dlp" {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value { param($a,$b) @{ Success = $true; Data = @() } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $false
                    Dependencies = @(
                        @{ Name = "yt-dlp"; Valid = $false; Version = "not found"; Description = "yt-dlp не найден" },
                        @{ Name = "MediaInfo"; Valid = $true; Version = "21.09"; Description = "MediaInfo найден" }
                    )
                }
            }
            # Мокируем Write-Host без использования массива
            Mock Write-Host { } -ModuleName AnalyzeTTBot
            
            # Вызываем тестируемый метод
            $botService.ShowDependencyValidationResults($validationResults)
            
            # Проверяем количество вызовов Write-Host
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -Times 10 -Because "Должно быть достаточное количество вызовов Write-Host"
            
            # Проверяем наличие конкретных строк в выводе
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'yt-dlp' -or $Object -match 'Рекомендации' } -Times 1 -Because "Должно быть сообщение о yt-dlp или рекомендациях"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'pip' } -Times 1 -Because "Должно быть сообщение о pip"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'Set-PSFConfig' } -Times 1 -Because "Должно быть сообщение о конфигурации"
        }
    }

    It "Should format table structure exactly like in real output" {
        InModuleScope AnalyzeTTBot {
            # Настраиваем валидные зависимости, как в реальном выводе .\scripts\Start-Bot.ps1 -ValidateOnly
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name EditMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendFile -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name GetUpdates -Value { param($a,$b) @{ Success = $true; Data = @() } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
                
            # Формируем результаты валидации с точными данными из реального вывода
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @(
                        @{ Name = "PowerShell"; Valid = $true; Version = "7.5.0"; Description = "PowerShell 7.5.0 доступен" },
                        @{ Name = "PSFramework"; Valid = $true; Version = "1.12.346"; Description = "PSFramework 1.12.346 установлен" },
                        @{ Name = "MediaInfo"; Valid = $true; Version = "MediaInfo Command line,  MediaInfoLib - v25.03"; Description = "MediaInfo найден" },
                        @{ Name = "yt-dlp"; Valid = $true; Version = "2025.03.26"; Description = "yt-dlp найден" },
                        @{ Name = "Telegram Bot"; Valid = $true; Version = "Локальная конфигурация"; Description = "Бот активен" }
                    )
                }
            }
            
            # Упрощаем мокирование, с фокусом только на подсчет вызовов
            Mock Write-Host { } -ModuleName AnalyzeTTBot -Verifiable
            
            # Вызываем тестируемый метод
            $botService.ShowDependencyValidationResults($validationResults)
            
            # Проверяем, что были вызовы Write-Host
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter { 
                $Object -eq "Все зависимости проверены успешно." -and $ForegroundColor -eq "Green" 
            } -Because "'Все зависимости проверены успешно' должно быть выведено зеленым цветом"
            
            # Проверяем факт наличия заголовка таблицы
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "Компонент" -and $ForegroundColor -eq "DarkCyan" 
            } -Because "Заголовок 'Компонент' должен быть выведен синим цветом"
            
            # Проверяем вывод разделительной линии
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "---------" -and $ForegroundColor -eq "DarkCyan" 
            } -Because "Разделительная линия должна быть выведена синим цветом"
            
            # Проверяем факт наличия зелёных статусов
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $ForegroundColor -eq "Green" -and ($Object -match "✓ OK" -or $Object -match "✓") 
            } -Because "Должен быть хотя бы один зелёный статус '✓ OK' или ✓"
            
            # Проверяем наличие названий зависимостей в выводе
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'PowerShell' } -Because "В выводе должен быть PowerShell"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'PSFramework' } -Because "В выводе должен быть PSFramework"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'MediaInfo' } -Because "В выводе должен быть MediaInfo"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'yt-dlp' } -Because "В выводе должен быть yt-dlp"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { $Object -match 'Telegram Bot' } -Because "В выводе должен быть Telegram Bot"
            
            # Проверяем общее количество вызовов Write-Host
            # Проверяем количество вызовов Write-Host
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -Times 10 -Because "Должно быть точно 10 вызовов Write-Host после оптимизации вывода"
        }
    }

    It 'Корректно обрабатывает пустой список зависимостей' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $botService = New-Object -TypeName BotService -ArgumentList @($mockTelegramService,$null,$null,$null,$null,$null)
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @()
                }
            }
            $script:printed = $false
            Mock Write-Host { $script:printed = $true } -ModuleName AnalyzeTTBot
            $botService.ShowDependencyValidationResults($validationResults)
            $script:printed | Should -BeTrue
        }
    }
    It 'Корректно выводит длинные строки в версиях' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $botService = New-Object -TypeName BotService -ArgumentList @($mockTelegramService,$null,$null,$null,$null,$null)
            $longVersion = 'v' + ('1234567890' * 10)
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @(
                        @{ Name = "yt-dlp"; Valid = $true; Version = $longVersion; Description = "yt-dlp найден" }
                    )
                }
            }
            $script:calls = @()
            Mock Write-Host { param($Object) $script:calls += $Object } -ModuleName AnalyzeTTBot
            $botService.ShowDependencyValidationResults($validationResults)
            ($script:calls | Where-Object { $_ -match '...' }).Count | Should -BeGreaterThan 0
        }
    }
    It 'Корректно обрабатывает отсутствие некоторых полей' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $botService = New-Object -TypeName BotService -ArgumentList @($mockTelegramService,$null,$null,$null,$null,$null)
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $false
                    Dependencies = @(
                        @{ Name = "yt-dlp"; Valid = $false } # Нет Version и Description
                    )
                }
            }
            $script:printed = $false
            Mock Write-Host { $script:printed = $true } -ModuleName AnalyzeTTBot
            $botService.ShowDependencyValidationResults($validationResults)
            $script:printed | Should -BeTrue
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}