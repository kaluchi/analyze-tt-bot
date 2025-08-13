#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ExtractVideoInfo в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ExtractVideoInfo сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

#region YtDlpService.ExtractVideoInfo.Unit.Tests

<#
.SYNOPSIS
    Тесты для метода ExtractVideoInfo класса YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ExtractVideoInfo.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Обновлено: 20.04.2025 - Создание тестов для метода ExtractVideoInfo
#>

Describe 'YtDlpService.ExtractVideoInfo method' {
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

    It 'Извлекает информацию из корректного JSON-контента' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент
            $jsonContent = @{
                uploader = "testuser"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@testuser/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "testuser"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@testuser/video/1234567890"
        }
    }

    It 'Извлекает имя автора из uploader_id, если uploader отсутствует' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент без uploader
            $jsonContent = @{
                uploader_id = "alternative_username"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@testuser/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "alternative_username"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@testuser/video/1234567890"
        }
    }

    It 'Извлекает имя автора из поля creator, если uploader и uploader_id отсутствуют' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент без uploader и uploader_id
            $jsonContent = @{
                creator = "creator_username"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@testuser/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "creator_username"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@testuser/video/1234567890"
        }
    }

    It 'Извлекает имя автора из поля channel, если другие поля отсутствуют' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент без uploader, uploader_id и creator
            $jsonContent = @{
                channel = "channel_username"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@testuser/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "channel_username"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@testuser/video/1234567890"
        }
    }

    It 'Использует channel_id, если channel отсутствует' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент с channel_id
            $jsonContent = @{
                channel_id = "channel_id_value"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@testuser/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@testuser/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "channel_id_value"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@testuser/video/1234567890"
        }
    }

    It 'Генерирует имя автора на основе ID TikTok, если extractor_key присутствует' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент с extractor_key
            $jsonContent = @{
                extractor_key = "TikTok"
                id = "1234567890"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@unknown/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@unknown/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "TikTokUser_1234567890"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@unknown/video/1234567890"
        }
    }

    It 'Извлекает имя автора из URL, если в JSON нет информации об авторе' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент без информации об авторе
            $jsonContent = @{
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@url_username/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@url_username/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "url_username"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@url_username/video/1234567890"
        }
    }

    It 'Использует значение по умолчанию, если имя автора не найдено нигде' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент без информации об авторе
            $jsonContent = @{
                title = "Test TikTok Video"
                webpage_url = "https://tiktok.com/video/1234567890" # URL без имени пользователя
            }
            
            # URL для теста без имени пользователя
            $url = "https://tiktok.com/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "TikTokUser"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://tiktok.com/video/1234567890"
        }
    }

    It 'Обрабатывает случай с сокращенным URL TikTok (vm.tiktok.com)' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент с полным URL
            $jsonContent = @{
                uploader = "vm_testuser"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@vm_testuser/video/1234567890"
            }
            
            # Сокращенный URL для теста
            $url = "https://vm.tiktok.com/ABC123/"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "vm_testuser"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@vm_testuser/video/1234567890"
        }
    }

    It 'Обрабатывает случай с null JSON-контентом' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # URL для теста
            $url = "https://www.tiktok.com/@fallback_username/video/1234567890"
            
            # Вызываем тестируемый метод с null вместо JSON-контента
            $result = $ytDlpService.ExtractVideoInfo($null, $url)
            
            # Проверяем результат
            $result.AuthorUsername | Should -Be "fallback_username"
            $result.VideoTitle | Should -Be ""
            $result.FullVideoUrl | Should -Be $url
        }
    }

    It 'Игнорирует некорректные значения "NA" для имени автора' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Создаем тестовый JSON-контент с некорректным значением NA
            $jsonContent = @{
                uploader = "NA"
                title = "Test TikTok Video"
                webpage_url = "https://www.tiktok.com/@real_username/video/1234567890"
            }
            
            # URL для теста
            $url = "https://www.tiktok.com/@real_username/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
            
            # Проверяем результат - должен извлечь имя из URL вместо использования "NA"
            $result.AuthorUsername | Should -Be "real_username"
            $result.VideoTitle | Should -Be "Test TikTok Video"
            $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@real_username/video/1234567890"
        }
    }
}
#endregion
