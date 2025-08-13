#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Расширенные тесты для метода ExtractVideoInfo в YtDlpService.
.DESCRIPTION
    Дополнительные модульные тесты для проверки сложных сценариев работы метода ExtractVideoInfo.
    Тесты фокусируются на случаях, которые не покрыты основными тестами.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'YtDlpService.ExtractVideoInfo.Extended method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    Context 'Сложные случаи извлечения имени автора' {
        It 'Корректно обрабатывает ситуацию, когда идентификатор содержит слеш в URL' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент без информации об авторе
                $jsonContent = @{
                    title = "Test TikTok Video"
                    webpage_url = "https://www.tiktok.com/tag/test/video/1234567890"
                }
                
                # URL для теста с нестандартным форматом
                $url = "https://www.tiktok.com/tag/test/video/1234567890"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат
                $result.AuthorUsername | Should -Be "TikTokUser" # Должен использовать значение по умолчанию
                $result.VideoTitle | Should -Be "Test TikTok Video"
                $result.FullVideoUrl | Should -Be $url
                
                # Проверяем вызов логгера
                Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                    $Level -eq 'Debug' -and 
                    $FunctionName -eq 'ExtractVideoInfo' -and
                    $Message -match "Using default author: TikTokUser"
                }
            }
        }
        
        It 'Корректно обрабатывает случай, когда в URL есть "@", но не в стандартном формате' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент без информации об авторе
                $jsonContent = @{
                    title = "Test Video with @ Symbol"
                    webpage_url = "https://www.tiktok.com/explore/video@trending/1234567890"
                }
                
                # URL для теста с @ символом в нестандартном месте
                $url = "https://www.tiktok.com/explore/video@trending/1234567890"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат - в данном случае выделяется значение 'трендинг'
                $result.AuthorUsername | Should -Be "trending"
                $result.VideoTitle | Should -Be "Test Video with @ Symbol"
                $result.FullVideoUrl | Should -Be $url
            }
        }
        
        It 'Корректно обрабатывает ситуацию, когда имя пользователя "na" (не совсем пустое)' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент с "na" в качестве имени пользователя (нижний регистр)
                $jsonContent = @{
                    uploader = "na"
                    title = "Test TikTok Video"
                    webpage_url = "https://www.tiktok.com/@realusername/video/1234567890"
                }
                
                # URL для теста
                $url = "https://www.tiktok.com/@realusername/video/1234567890"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат - должен извлечь имя из URL
                $result.AuthorUsername | Should -Be "realusername"
                $result.VideoTitle | Should -Be "Test TikTok Video"
                $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@realusername/video/1234567890"
                
                # Проверяем вызов логгера
                Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                    $Level -eq 'Debug' -and 
                    $FunctionName -eq 'ExtractVideoInfo' -and
                    $Message -match "Extracted author from URL: realusername"
                }
            }
        }
        
        It 'Корректно обрабатывает случай, когда uploader имеет значение "NA" в верхнем регистре' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент с "NA" в качестве имени пользователя (верхний регистр)
                $jsonContent = @{
                    uploader = "NA"
                    title = "Test TikTok Video"
                    webpage_url = "https://www.tiktok.com/@different_user/video/1234567890"
                }
                
                # URL для теста
                $url = "https://www.tiktok.com/@different_user/video/1234567890"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат - должен извлечь имя из URL
                $result.AuthorUsername | Should -Be "different_user"
                $result.VideoTitle | Should -Be "Test TikTok Video"
                $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@different_user/video/1234567890"
            }
        }
    }
    
    Context 'Специальные случаи URL и метаданных' {
        It 'Корректно обрабатывает URL с дополнительными параметрами и хэшем' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент
                $jsonContent = @{
                    uploader = "complex_username"
                    title = "Test TikTok Video"
                    webpage_url = "https://www.tiktok.com/@complex_username/video/1234567890?is_copy_url=1&is_from_webapp=v1&lang=en#primary"
                }
                
                # URL для теста с параметрами и хэшем
                $url = "https://www.tiktok.com/@complex_username/video/1234567890?is_copy_url=1&is_from_webapp=v1&lang=en#primary"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат
                $result.AuthorUsername | Should -Be "complex_username"
                $result.VideoTitle | Should -Be "Test TikTok Video"
                $result.FullVideoUrl | Should -Be $url
            }
        }
        
        It 'Корректно обрабатывает случай, когда webpage_url в JSON отличается от входного URL' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент с другим URL
                $jsonContent = @{
                    uploader = "original_user"
                    title = "Test TikTok Video"
                    webpage_url = "https://www.tiktok.com/@original_user/video/9876543210" # Отличается от входного URL
                }
                
                # Входной URL
                $url = "https://vm.tiktok.com/ABC123/"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат - должен использовать полный URL из JSON
                $result.AuthorUsername | Should -Be "original_user"
                $result.VideoTitle | Should -Be "Test TikTok Video"
                $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@original_user/video/9876543210"
                
                # Проверяем вызов логгера
                Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                    $Level -eq 'Debug' -and 
                    $FunctionName -eq 'ExtractVideoInfo' -and
                    $Message -match "Using full video URL from JSON for shortened URL:"
                }
            }
        }
        
        It 'Корректно обрабатывает случай с пустым JSON-контентом (не null)' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем пустой JSON-контент
                $jsonContent = @{}
                
                # URL для теста
                $url = "https://www.tiktok.com/@empty_json_user/video/1234567890"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат - должен извлечь имя из URL
                $result.AuthorUsername | Should -Be "empty_json_user"
                $result.VideoTitle | Should -Be ""
                $result.FullVideoUrl | Should -Be $url
                
                # Проверяем вызов логгера
                Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                    $Level -eq 'Debug' -and 
                    $FunctionName -eq 'ExtractVideoInfo' -and
                    $Message -match "Extracted author from URL: empty_json_user"
                }
            }
        }
    }
    
    Context 'Приоритет полей в JSON' {
        It 'Должен использовать uploader с приоритетом перед всеми другими полями' {
            InModuleScope AnalyzeTTBot {
                # Подготовка мок-сервиса
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp\\TestFolder" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param($extension) return "C:\\Temp\\TestFolder\\test.mp4" } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param($path) return @{ Success = $true } } -Force
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Создаем JSON-контент со всеми возможными полями имени пользователя
                $jsonContent = @{
                    uploader = "priority_uploader"
                    uploader_id = "lower_priority_uploader_id"
                    creator = "lower_priority_creator"
                    channel = "lower_priority_channel"
                    channel_id = "lower_priority_channel_id"
                    extractor_key = "TikTok"
                    id = "1234567890"
                    title = "Test TikTok Video"
                    webpage_url = "https://www.tiktok.com/@url_username/video/1234567890"
                }
                
                # URL для теста
                $url = "https://www.tiktok.com/@url_username/video/1234567890"
                
                # Mock логгера для проверки логирования
                Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
                
                # Вызываем тестируемый метод
                $result = $ytDlpService.ExtractVideoInfo($jsonContent, $url)
                
                # Проверяем результат - должен выбрать uploader с наивысшим приоритетом
                $result.AuthorUsername | Should -Be "priority_uploader"
                $result.VideoTitle | Should -Be "Test TikTok Video"
                $result.FullVideoUrl | Should -Be "https://www.tiktok.com/@url_username/video/1234567890"
                
                # Проверяем вызов логгера
                Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                    $Level -eq 'Debug' -and 
                    $FunctionName -eq 'ExtractVideoInfo' -and
                    $Message -match "Found author from JSON metadata: priority_uploader"
                }
            }
        }
    }
}
