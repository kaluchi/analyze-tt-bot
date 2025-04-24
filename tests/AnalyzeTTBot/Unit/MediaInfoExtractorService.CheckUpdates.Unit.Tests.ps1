<#
.SYNOPSIS
    Тесты для метода CheckUpdates класса MediaInfoExtractorService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода CheckUpdates,
    который использует ChocoHelper для проверки обновлений MediaInfo.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "MediaInfoExtractorService.CheckUpdates method" {
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
    }
    
    Context "Update status checks" {
        It "Should detect available update for mediainfo-cli" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок FileSystemService
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFilePath -Value { 
                    param($fileName)
                    return "C:\temp\$fileName"
                } -Force
                
                # Создаем сервис 
                $service = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Мокируем Get-Choco-Outdated чтобы вернуть mediainfo-cli в списке устаревших
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
                
                # Вызываем метод
                $result = $service.CheckUpdates()
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.NeedsUpdate | Should -BeTrue
                $result.Data.CurrentVersion | Should -Be "25.03.0"
                $result.Data.NewVersion | Should -Be "25.04.0"
            }
        }
        
        It "Should report no update needed when mediainfo-cli is up to date" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок FileSystemService
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFilePath -Value { 
                    param($fileName)
                    return "C:\temp\$fileName"
                } -Force
                
                # Создаем сервис
                $service = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Мокируем Get-Choco-Outdated чтобы вернуть пустой список (нет устаревших)
                Mock Get-Choco-Outdated -ModuleName AnalyzeTTBot -MockWith {
                    return @()
                }
                
                # Мокируем Get-Choco-List чтобы вернуть текущую версию
                Mock Get-Choco-List -ModuleName AnalyzeTTBot -MockWith {
                    return @(
                        [PSCustomObject]@{
                            Name = "mediainfo-cli"
                            Version = "25.04.0"
                        }
                    )
                }
                
                # Вызываем метод
                $result = $service.CheckUpdates()
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.NeedsUpdate | Should -BeFalse
                $result.Data.CurrentVersion | Should -Be "25.04.0"
                $result.Data.NewVersion | Should -BeNullOrEmpty
            }
        }
        
        It "Should handle when mediainfo-cli is not installed via Chocolatey" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок FileSystemService
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFilePath -Value { 
                    param($fileName)
                    return "C:\temp\$fileName"
                } -Force
                
                # Создаем сервис
                $service = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Мокируем Get-Choco-Outdated чтобы вернуть пустой список
                Mock Get-Choco-Outdated -ModuleName AnalyzeTTBot -MockWith {
                    return @()
                }
                
                # Мокируем Get-Choco-List чтобы вернуть список без mediainfo-cli
                Mock Get-Choco-List -ModuleName AnalyzeTTBot -MockWith {
                    return @(
                        [PSCustomObject]@{
                            Name = "other-package"
                            Version = "1.0.0"
                        }
                    )
                }
                
                # Вызываем метод
                $result = $service.CheckUpdates()
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.NeedsUpdate | Should -BeFalse
                $result.Data.CurrentVersion | Should -BeNullOrEmpty
                $result.Data.NewVersion | Should -BeNullOrEmpty
            }
        }
        
        It "Should handle exceptions from ChocoHelper gracefully" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок FileSystemService
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFilePath -Value { 
                    param($fileName)
                    return "C:\temp\$fileName"
                } -Force
                
                # Создаем сервис
                $service = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Мокируем Get-Choco-Outdated чтобы выбросить исключение
                Mock Get-Choco-Outdated -ModuleName AnalyzeTTBot -MockWith {
                    throw "Chocolatey error: command not found"
                }
                
                # Вызываем метод
                $result = $service.CheckUpdates()
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Failed to check MediaInfo updates"
            }
        }
    }
    
    AfterAll {
        # Очистка после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
