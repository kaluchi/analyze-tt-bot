#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ProcessMetadata в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ProcessMetadata сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

#region YtDlpService.ProcessMetadata.Unit.Tests

<#
.SYNOPSIS
    Тесты для метода ProcessMetadata класса YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ProcessMetadata.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Обновлено: 20.04.2025 - Создание тестов для метода ProcessMetadata
#>

Describe 'YtDlpService.ProcessMetadata method' {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        # Очищаем все модули и переменные, чтобы не было конфликтов между тестами
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Успешно обрабатывает метаданные при наличии JSON-файла' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с моками
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем метод GetPossibleJsonPaths для возврата тестовых путей
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name GetPossibleJsonPaths -Value {
                param($outputPath)
                return @("C:\temp\video.mp4.info.json", "C:\temp\video.info.json")
            } -Force
            
            # Готовим тестовый JSON-контент
            $mockJsonContent = @{
                _filename = "C:\temp\video.mp4"
                uploader = "testuser"
                title = "Test Video Title"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # Мокаем метод FindAndReadJsonMetadata для возврата тестового контента
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindAndReadJsonMetadata -Value {
                param($jsonPaths, $url)
                return @{
                    JsonFilePath = "C:\temp\video.mp4.info.json"
                    JsonContent = $mockJsonContent
                }
            } -Force
            
            # Мокаем метод ExtractVideoInfo
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name ExtractVideoInfo -Value {
                param($jsonContent, $url)
                return @{
                    AuthorUsername = "testuser"
                    VideoTitle = "Test Video Title"
                    FullVideoUrl = "https://www.tiktok.com/@testuser/video/1234567890"
                }
            } -Force
            
            # Мокаем Test-Path вместо System.IO.File::Exists
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ProcessMetadata("https://www.tiktok.com/@testuser/video/1234567890", "C:\temp\video.mp4")
            
            # Проверяем результат
            $result.FilePath | Should -Be "C:\temp\video.mp4"
            $result.JsonFilePath | Should -Be "C:\temp\video.mp4.info.json"
            $result.JsonContent | Should -Not -BeNullOrEmpty
            $result.AuthorUsername | Should -Be "testuser"
            $result.VideoTitle | Should -Be "Test Video Title"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@testuser/video/1234567890"
        }
    }

    It 'Использует путь к файлу из JSON, если он указан в _filename' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с моками
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем метод GetPossibleJsonPaths
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name GetPossibleJsonPaths -Value {
                param($outputPath)
                return @("C:\temp\video.mp4.info.json", "C:\temp\video.info.json")
            } -Force
            
            # Готовим тестовый JSON-контент с другим _filename
            $mockJsonContent = @{
                _filename = "C:\temp\custom_name.mp4" # Отличается от входного пути
                uploader = "testuser"
                title = "Test Video Title"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # Мокаем метод FindAndReadJsonMetadata
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindAndReadJsonMetadata -Value {
                param($jsonPaths, $url)
                return @{
                    JsonFilePath = "C:\temp\video.mp4.info.json"
                    JsonContent = $mockJsonContent
                }
            } -Force
            
            # Мокаем метод ExtractVideoInfo
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name ExtractVideoInfo -Value {
                param($jsonContent, $url)
                return @{
                    AuthorUsername = "testuser"
                    VideoTitle = "Test Video Title"
                    FullVideoUrl = "https://www.tiktok.com/@testuser/video/1234567890"
                }
            } -Force
            
            # Мокаем Test-Path вместо System.IO.File::Exists
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ProcessMetadata("https://www.tiktok.com/@testuser/video/1234567890", "C:\temp\video.mp4")
            
            # Проверяем, что был использован путь из JSON
            $result.FilePath | Should -Be "C:\temp\custom_name.mp4"
            $result.JsonFilePath | Should -Be "C:\temp\video.mp4.info.json"
        }
    }

    It 'Ищет файл, если он не существует по указанному пути' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с моками
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем метод GetPossibleJsonPaths
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name GetPossibleJsonPaths -Value {
                param($outputPath)
                return @("C:\temp\video.mp4.info.json", "C:\temp\video.info.json")
            } -Force
            
            # Готовим тестовый JSON-контент без _filename
            $mockJsonContent = @{
                uploader = "testuser"
                title = "Test Video Title"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # Мокаем метод FindAndReadJsonMetadata
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindAndReadJsonMetadata -Value {
                param($jsonPaths, $url)
                return @{
                    JsonFilePath = "C:\temp\video.mp4.info.json"
                    JsonContent = $mockJsonContent
                }
            } -Force
            
            # Мокаем метод ExtractVideoInfo
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name ExtractVideoInfo -Value {
                param($jsonContent, $url)
                return @{
                    AuthorUsername = "testuser"
                    VideoTitle = "Test Video Title"
                    FullVideoUrl = "https://www.tiktok.com/@testuser/video/1234567890"
                }
            } -Force
            
            # Мокаем Test-Path для имитации отсутствия файла
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $false }
            
            # Мокаем метод FindOutputFile
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindOutputFile -Value {
                param($outputPath)
                return "C:\temp\found_video.mp4"
            } -Force
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ProcessMetadata("https://www.tiktok.com/@testuser/video/1234567890", "C:\temp\video.mp4")
            
            # Проверяем, что был использован путь, найденный через FindOutputFile
            $result.FilePath | Should -Be "C:\temp\found_video.mp4"
        }
    }

    It 'Обрабатывает случай, когда FindOutputFile возвращает пустой результат' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с моками
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем метод GetPossibleJsonPaths
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name GetPossibleJsonPaths -Value {
                param($outputPath)
                return @("C:\temp\video.mp4.info.json", "C:\temp\video.info.json")
            } -Force
            
            # Готовим тестовый JSON-контент без _filename
            $mockJsonContent = @{
                uploader = "testuser"
                title = "Test Video Title"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # Мокаем метод FindAndReadJsonMetadata
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindAndReadJsonMetadata -Value {
                param($jsonPaths, $url)
                return @{
                    JsonFilePath = "C:\temp\video.mp4.info.json"
                    JsonContent = $mockJsonContent
                }
            } -Force
            
            # Мокаем метод ExtractVideoInfo
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name ExtractVideoInfo -Value {
                param($jsonContent, $url)
                return @{
                    AuthorUsername = "testuser"
                    VideoTitle = "Test Video Title"
                    FullVideoUrl = "https://www.tiktok.com/@testuser/video/1234567890"
                }
            } -Force
            
            # Мокаем Test-Path для имитации отсутствия файла
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $false }
            
            # Мокаем метод FindOutputFile для возврата пустого результата
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindOutputFile -Value {
                param($outputPath)
                return ""
            } -Force
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ProcessMetadata("https://www.tiktok.com/@testuser/video/1234567890", "C:\temp\video.mp4")
            
            # Проверяем, что был использован исходный путь несмотря на то, что файл не существует
            $result.FilePath | Should -Be "C:\temp\video.mp4"
        }
    }

    It 'Корректно обрабатывает исключение в процессе обработки метаданных' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с моками
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем метод GetPossibleJsonPaths для имитации исключения
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name GetPossibleJsonPaths -Value {
                param($outputPath)
                throw "Test exception in GetPossibleJsonPaths"
            } -Force
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ProcessMetadata("https://www.tiktok.com/@testuser/video/1234567890", "C:\temp\video.mp4")
            
            # Проверяем, что метод вернул ошибку
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Failed to process metadata"
            $result.Data.FilePath | Should -Be "C:\temp\video.mp4"
        }
    }

    It 'Обрабатывает ошибку в FindAndReadJsonMetadata, создавая базовые метаданные' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с моками
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем метод GetPossibleJsonPaths
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name GetPossibleJsonPaths -Value {
                param($outputPath)
                return @("C:\temp\video.mp4.info.json", "C:\temp\video.info.json")
            } -Force
            
            # Мокаем метод FindAndReadJsonMetadata для имитации ошибки
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name FindAndReadJsonMetadata -Value {
                param($jsonPaths, $url)
                # Возвращаем пустой JsonContent, что имитирует ошибку чтения
                return @{
                    JsonFilePath = "C:\temp\video.mp4.info.json"
                    JsonContent = $null
                }
            } -Force
            
            # Мокаем метод ExtractVideoInfo для создания базовых метаданных
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name ExtractVideoInfo -Value {
                param($jsonContent, $url)
                # Даже с null JsonContent, этот метод должен вернуть базовую информацию
                return @{
                    AuthorUsername = "extracted_from_url"
                    VideoTitle = ""
                    FullVideoUrl = "https://www.tiktok.com/@testuser/video/1234567890"
                }
            } -Force
            
            # Мокаем Test-Path для имитации существования файла
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ProcessMetadata("https://www.tiktok.com/@testuser/video/1234567890", "C:\temp\video.mp4")
            
            # Проверяем, что метод вернул базовую информацию несмотря на отсутствие JsonContent
            $result.FilePath | Should -Be "C:\temp\video.mp4"
            $result.JsonFilePath | Should -Be "C:\temp\video.mp4.info.json"
            $result.JsonContent | Should -BeNullOrEmpty
            $result.AuthorUsername | Should -Be "extracted_from_url"
            $result.VideoTitle | Should -Be ""
        }
    }
}
#endregion
