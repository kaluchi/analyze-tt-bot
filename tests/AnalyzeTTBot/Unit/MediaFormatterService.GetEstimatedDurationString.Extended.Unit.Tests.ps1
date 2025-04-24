#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Расширенные тесты для метода GetEstimatedDurationString сервиса MediaFormatterService.
.DESCRIPTION
    Дополнительные модульные тесты для проверки функциональности метода GetEstimatedDurationString 
    сервиса MediaFormatterService в различных краевых случаях.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "MediaFormatterService.GetEstimatedDurationString Extended Tests" {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }

    Context "Edge Cases in Duration Calculation" {
        It "Should handle both zero videoBitRate and audioBitRate" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем данные с нулевыми значениями битрейта
                $mediaInfo = @{
                    FileSize = 1000000  # 1MB файл
                    FileSizeMB = 1
                    VideoBitRate = 0
                    AudioBitRate = 0
                }
                
                # Вызываем метод
                $result = $mediaFormatterService.GetEstimatedDurationString($mediaInfo)
                
                # Проверяем, что метод корректно использует значения по умолчанию
                # По умолчанию VideoBitRate = 500000, AudioBitRate = 64000 если они <= 0
                # Итого 564000 бит/сек, для 1MB файла (8000000 бит) получаем примерно 14.18 секунд
                $result | Should -Match "Duration: 14 s \d+ ms"
            }
        }
        
        It "Should handle zero FileSize with valid bitrates" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем данные с нулевым размером файла
                $mediaInfo = @{
                    FileSize = 0
                    FileSizeMB = 0
                    VideoBitRate = 1000000
                    AudioBitRate = 128000
                }
                
                # Вызываем метод
                $result = $mediaFormatterService.GetEstimatedDurationString($mediaInfo)
                
                # Проверяем, что возвращается значение по умолчанию для неизвестной длительности
                $result | Should -BeExactly "Duration: 15 s 0 ms`n"
            }
        }
        
        It "Should correctly calculate duration for very small files" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем данные для очень маленького файла
                $mediaInfo = @{
                    FileSize = 5000  # 5KB файл
                    FileSizeMB = 0.005
                    VideoBitRate = 1000000
                    AudioBitRate = 128000
                }
                
                # Вызываем метод
                $result = $mediaFormatterService.GetEstimatedDurationString($mediaInfo)
                
                # 5000 * 8 = 40000 бит / 1128000 бит/сек = примерно 0.035 сек
                $result | Should -Match "Duration: 0 s \d+ ms"
            }
        }
        
        It "Should correctly calculate duration for large files" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр сервиса
                $mediaFormatterService = New-Object -TypeName MediaFormatterService
                
                # Создаем данные для большого файла
                $mediaInfo = @{
                    FileSize = 50000000  # 50MB файл
                    FileSizeMB = 50
                    VideoBitRate = 1000000
                    AudioBitRate = 128000
                }
                
                # Вызываем метод
                $result = $mediaFormatterService.GetEstimatedDurationString($mediaInfo)
                
                # 50MB = 50000000 * 8 = 400000000 бит / 1128000 бит/сек = около 354 секунд
                $result | Should -Match "Duration: 35\d s \d+ ms"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}