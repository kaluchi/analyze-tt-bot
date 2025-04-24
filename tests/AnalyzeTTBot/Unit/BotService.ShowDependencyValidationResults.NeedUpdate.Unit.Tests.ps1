#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Unit tests for BotService.ShowDependencyValidationResults method with NeedUpdate status.
.DESCRIPTION
    Tests the display and formatting of the "⚠ Update" status in the dependency validation results table.
.NOTES
    Author: TikTok Bot Team
    Created: 21.04.2025
#>

Describe "BotService.ShowDependencyValidationResults method with NeedUpdate status" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }

    It "Should display '⚠ Update' status in yellow for components with available updates" {
        InModuleScope AnalyzeTTBot {
            # Создаем мок для TelegramService
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            
            # Создаем экземпляр BotService
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
            
            # Формируем результаты валидации с данными об обновлениях
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @(
                        @{ 
                            Name = "PowerShell"
                            Valid = $true
                            Version = "7.5.0"
                            Description = "PowerShell 7.5.0 доступен"
                            CheckUpdatesResult = $null
                            SkipCheckUpdates = $false
                        },
                        @{ 
                            Name = "MediaInfo"
                            Valid = $true
                            Version = "v25.03"
                            Description = "MediaInfo v25.03 найден"
                            CheckUpdatesResult = @{
                                NewVersion = "v25.04"
                                NeedsUpdate = $true
                            }
                            SkipCheckUpdates = $false
                        },
                        @{ 
                            Name = "yt-dlp"
                            Valid = $true
                            Version = "2025.03.26"
                            Description = "yt-dlp найден"
                            CheckUpdatesResult = @{
                                NewVersion = $null
                                NeedsUpdate = $false
                            }
                            SkipCheckUpdates = $false
                        }
                    )
                }
            }
            
            # Мокируем Write-Host для проверки вызовов
            Mock Write-Host { } -ModuleName AnalyzeTTBot -Verifiable
            
            # Вызываем тестируемый метод
            $botService.ShowDependencyValidationResults($validationResults)
            
            # Проверяем наличие статуса ⚠ Update для MediaInfo с жёлтым цветом
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "⚠ Update" -and $ForegroundColor -eq "Yellow" -and $Object -match "MediaInfo"
            } -Because "Должен быть статус '⚠ Update' с жёлтым цветом для MediaInfo"
            
            # Проверяем наличие информации об обновлении в колонке "Примечание"
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "Есть обновление: v25.04" -and $ForegroundColor -eq "Yellow"
            } -Because "Должна быть информация об обновлении в колонке 'Примечание'"
            
            # Проверяем наличие статуса OK для yt-dlp (без обновления) с зелёным цветом
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "✓ OK" -and $ForegroundColor -eq "Green" -and $Object -match "yt-dlp"
            } -Because "Должен быть статус 'OK' с зелёным цветом для yt-dlp"
        }
    }

    It "Should skip update checks when SkipCheckUpdates is true" {
        InModuleScope AnalyzeTTBot {
            # Создаем мок для TelegramService
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            
            # Создаем экземпляр BotService
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
            
            # Формируем результаты валидации с пропуском проверки обновлений
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @(
                        @{ 
                            Name = "MediaInfo"
                            Valid = $true
                            Version = "v25.03"
                            Description = "MediaInfo v25.03 найден"
                            CheckUpdatesResult = $null
                            SkipCheckUpdates = $true
                        }
                    )
                }
            }
            
            # Мокируем Write-Host для проверки вызовов
            Mock Write-Host { } -ModuleName AnalyzeTTBot -Verifiable
            
            # Вызываем тестируемый метод
            $botService.ShowDependencyValidationResults($validationResults)
            
            # Проверяем наличие статуса ✓ OK для MediaInfo, несмотря на возможность обновления
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "✓ OK" -and $ForegroundColor -eq "Green" -and $Object -match "MediaInfo"
            } -Because "Должен быть статус 'OK' с зелёным цветом для MediaInfo при SkipCheckUpdates = true"
            
            # Проверяем отсутствие информации об обновлении
            Should -Not -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "Есть обновление"
            } -Because "Не должно быть информации об обновлении при SkipCheckUpdates = true"
        }
    }

    It "Should handle missing CheckUpdatesResult field" {
        InModuleScope AnalyzeTTBot {
            # Создаем мок для TelegramService
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { param($a,$b,$c,$d) @{ Success = $true } } -Force
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($a) @{ Success = $true; Data = @{} } } -Force
            
            # Создаем экземпляр BotService
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,$null,$null,$null,$null,$null)
            
            # Формируем результаты валидации без поля CheckUpdatesResult
            $validationResults = [PSCustomObject]@{
                Success = $true
                Data = [PSCustomObject]@{
                    AllValid = $true
                    Dependencies = @(
                        @{ 
                            Name = "PSFramework"
                            Valid = $true
                            Version = "1.12.346"
                            Description = "PSFramework 1.12.346 установлен"
                            # Отсутствует поле CheckUpdatesResult
                        }
                    )
                }
            }
            
            # Мокируем Write-Host для проверки вызовов
            Mock Write-Host { } -ModuleName AnalyzeTTBot -Verifiable
            
            # Вызываем тестируемый метод
            $botService.ShowDependencyValidationResults($validationResults)
            
            # Проверяем наличие статуса ✓ OK для PSFramework
            Should -Invoke Write-Host -ModuleName AnalyzeTTBot -ParameterFilter { 
                $Object -match "✓ OK" -and $ForegroundColor -eq "Green" -and $Object -match "PSFramework"
            } -Because "Должен быть статус 'OK' с зелёным цветом для PSFramework при отсутствии CheckUpdatesResult"
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}