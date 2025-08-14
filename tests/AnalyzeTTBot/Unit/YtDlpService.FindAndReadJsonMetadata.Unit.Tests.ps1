#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода FindAndReadJsonMetadata в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода FindAndReadJsonMetadata сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe 'YtDlpService.FindAndReadJsonMetadata method' {
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
    It 'Should cover FindAndReadJsonMetadata' {
        InModuleScope AnalyzeTTBot {
            # Arrange
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

            # Мокаем CreateBaseJsonContent для предсказуемого результата
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name CreateBaseJsonContent -Value {
                param($url, $outputPath)
                return @{ _filename = $outputPath; uploader = "testuser"; uploader_id = "testuser"; webpage_url = $url }
            } -Force

            # Мокаем Read-JsonFile для возврата тестового объекта
            Mock -CommandName Read-JsonFile -ModuleName AnalyzeTTBot -MockWith {
                param($Path)
                return @{ _filename = $Path; uploader = "testuser"; webpage_url = "https://www.tiktok.com/@testuser/video/1234567890" }
            }

            $testUrl = "https://www.tiktok.com/@testuser/video/1234567890"
            $testJsonPaths = @("C:\\temp\\video.mp4.info.json", "C:\\temp\\video.info.json")

            # Act
            $result = $ytDlpService.FindAndReadJsonMetadata($testJsonPaths, $testUrl)

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result.JsonFilePath | Should -Be "C:\\temp\\video.mp4.info.json"
            $result.JsonContent | Should -Not -BeNullOrEmpty
            $result.JsonContent.uploader | Should -Be "testuser"
            $result.JsonContent.webpage_url | Should -Be $testUrl
        }
    }
    It 'Создаёт базовый JSON, если файл не найден' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            
            # Мокаем Test-Path, чтобы он всегда возвращал $false (файл не найден)
            Mock Test-Path { return $false } -ModuleName AnalyzeTTBot

            # Мокаем Write-JsonFile, чтобы не создавать реальный файл
            Mock Write-JsonFile -ModuleName AnalyzeTTBot

            $testUrl = "https://www.tiktok.com/@testuser/video/1234567890"
            $testJsonPaths = @("C:\\temp\\video.mp4.info.json", "C:\\temp\\video.info.json")
            
            $result = $ytDlpService.FindAndReadJsonMetadata($testJsonPaths, $testUrl)
            
            $result.JsonContent | Should -Not -BeNullOrEmpty
            $result.JsonFilePath | Should -Be $testJsonPaths[0]
            $result.JsonContent.uploader | Should -Be "testuser"

            # Проверяем, что Write-JsonFile был вызван
            Should -Invoke -CommandName Write-JsonFile -ModuleName AnalyzeTTBot -Exactly 1
        }
    }

    It 'Создаёт базовый JSON, если чтение существующего файла не удалось' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

            # Мокаем Test-Path, чтобы он возвращал $true (файл найден)
            Mock Test-Path { return $true } -ModuleName AnalyzeTTBot

            # Мокаем Read-JsonFile, чтобы он возвращал $null (ошибка чтения)
            Mock Read-JsonFile { return $null } -ModuleName AnalyzeTTBot

            # Мокаем Write-JsonFile, чтобы не создавать реальный файл
            Mock Write-JsonFile -ModuleName AnalyzeTTBot

            $testUrl = "https://www.tiktok.com/@testuser/video/1234567890"
            $testJsonPaths = @("C:\\temp\\video.mp4.info.json")

            $result = $ytDlpService.FindAndReadJsonMetadata($testJsonPaths, $testUrl)

            $result.JsonContent | Should -Not -BeNullOrEmpty
            $result.JsonContent.uploader | Should -Be "testuser"

            # Проверяем, что Write-JsonFile не был вызван, так как базовый JSON создается внутри и возвращается
            Should -Not -Invoke -CommandName Write-JsonFile -ModuleName AnalyzeTTBot
        }
    }
}

