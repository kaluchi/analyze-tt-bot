#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Расширенные тесты для метода TestMediaInfoDependency в MediaInfoExtractorService.
.DESCRIPTION
    Модульные тесты для проверки дополнительных сценариев работы метода TestMediaInfoDependency, 
    включая обработку ошибок, специальные случаи и форматирование версий.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'MediaInfoExtractorService.TestMediaInfoDependency Extended Tests' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    
    Context 'Обработка ошибок и нестандартных случаев' {
        It 'Корректно обрабатывает ошибку выполнения команды mediainfo' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса, чтобы она возвращала ошибку
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $false
                        ExitCode = 1
                        Error = "Command mediainfo not found"
                        Output = $null
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с пустыми зависимостями
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Запускаем метод с флагом пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$true)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeFalse
                $result.Data.Version | Should -Be "Не найден"
                $result.Data.Description | Should -Match "MediaInfo не найден или не работает"
            }
        }
        
        It 'Корректно обрабатывает нестандартный формат вывода версии (числовая версия)' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса, чтобы она возвращала только числовую версию
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = $null
                        Output = "22.03.1"
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с пустыми зависимостями
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Запускаем метод с флагом пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$true)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "22.03.1"
                $result.Data.Description | Should -Match "MediaInfo 22.03.1 найден"
            }
        }
        
        It 'Корректно обрабатывает формат версии с префиксом MediaInfo' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса, чтобы она возвращала версию с префиксом
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = $null
                        Output = "MediaInfo CLI 3.04"
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с пустыми зависимостями
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Запускаем метод с флагом пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$true)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "3.04"
                $result.Data.Description | Should -Match "MediaInfo 3.04 найден"
            }
        }
        
        It 'Корректно обрабатывает версию с префиксом v' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса, чтобы она возвращала версию с префиксом v
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = $null
                        Output = "MediaInfo CLI v21.09.1"
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с пустыми зависимостями
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Запускаем метод с флагом пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$true)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "v21.09.1"
                $result.Data.Description | Should -Match "MediaInfo v21.09.1 найден"
            }
        }
        
        It 'Возвращает общую ошибку при необработанном исключении' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса, чтобы она бросала исключение
                Mock Invoke-ExternalProcess {
                    throw "Unexpected error occurred"
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с пустыми зависимостями
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Запускаем метод с флагом пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$true)
                
                # Проверяем результат - ожидаем общую ошибку
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Ошибка при проверке MediaInfo:"
                $result.Data.Valid | Should -BeFalse
                $result.Data.Version | Should -Be "Неизвестно"
                $result.Data.Description | Should -Match "Ошибка при проверке MediaInfo:"
            }
        }
    }
    
    Context 'Проверка обновлений' {
        It 'Запускает проверку обновлений, если флаг пропуска не установлен' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса для проверки версии
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = $null
                        Output = "MediaInfo CLI v22.12"
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с моком CheckUpdates
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Мокаем метод CheckUpdates, чтобы отслеживать его вызов
                $checkUpdatesCalled = $false
                $mediaInfoService | Add-Member -MemberType ScriptMethod -Name 'CheckUpdates' -Value {
                    $script:checkUpdatesCalled = $true
                    return @{
                        Success = $true
                        Data = @{
                            NewVersion = "23.01"
                            NeedsUpdate = $true
                            CurrentVersion = "22.12"
                        }
                    }
                } -Force
                
                # Запускаем метод БЕЗ флага пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency($false)
                
                # Проверяем, что метод CheckUpdates был вызван
                $script:checkUpdatesCalled | Should -BeTrue
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "v22.12"
                $result.Data.CheckUpdatesResult | Should -Not -BeNullOrEmpty
                $result.Data.CheckUpdatesResult.NeedsUpdate | Should -BeTrue
                $result.Data.CheckUpdatesResult.NewVersion | Should -Be "23.01"
            }
        }
        
        It 'Проверяет флаг SkipCheckUpdates в результатах при его установке' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса для проверки версии
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = $null
                        Output = "MediaInfo CLI v22.12"
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Создаем переменную для конвертации в [switch]
                $skipCheckUpdatesSwitchParam = $true
                
                # Запускаем метод С флагом пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$skipCheckUpdatesSwitchParam)
                
                # Проверяем результат - важно чтобы был установлен флаг SkipCheckUpdates
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "v22.12"
                
                # Проверяем что в результате установлен флаг SkipCheckUpdates
                $result.Data.SkipCheckUpdates | Should -BeTrue
            }
        }
        
        It 'Корректно обрабатывает ошибку при проверке обновлений' {
            InModuleScope AnalyzeTTBot {
                # Мокаем функцию вызова внешнего процесса для проверки версии
                Mock Invoke-ExternalProcess {
                    return @{
                        Success = $true
                        ExitCode = 0
                        Error = $null
                        Output = "MediaInfo CLI v22.12"
                    }
                } -ModuleName AnalyzeTTBot
                
                # Создаем экземпляр MediaInfoExtractorService с моком CheckUpdates
                $mockFileSystemService = [IFileSystemService]::new()
                $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
                
                # Мокаем метод CheckUpdates, чтобы он возвращал ошибку
                $mediaInfoService | Add-Member -MemberType ScriptMethod -Name 'CheckUpdates' -Value {
                    return @{
                        Success = $false
                        Error = "Failed to check updates"
                        Data = $null
                    }
                } -Force
                
                # Запускаем метод БЕЗ флага пропуска проверки обновлений
                $result = $mediaInfoService.TestMediaInfoDependency($false)
                
                # Проверяем результат - основная проверка должна быть успешной, несмотря на ошибку обновления
                $result.Success | Should -BeTrue
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Be "v22.12"
                $result.Data.CheckUpdatesResult | Should -BeNullOrEmpty
            }
        }
    }
}