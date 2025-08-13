#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода CreateBaseJsonContent в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода CreateBaseJsonContent сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe 'YtDlpService.CreateBaseJsonContent method' {
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
    It 'Should cover CreateBaseJsonContent' {
        InModuleScope AnalyzeTTBot {
            # Arrange
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")

            # Мокаем ExtractUsernameFromUrl для предсказуемого результата
            $ytDlpService | Add-Member -MemberType ScriptMethod -Name ExtractUsernameFromUrl -Value {
                param($url)
                return "testuser"
            } -Force

            $testUrl = "https://www.tiktok.com/@testuser/video/1234567890"
            $testOutputPath = "C:\\temp\\video.mp4.info.json"

            # Act
            $result = $ytDlpService.CreateBaseJsonContent($testUrl, $testOutputPath)

            # Assert
            $result | Should -Not -BeNullOrEmpty
            $result["_filename"] | Should -Be $testOutputPath
            $result["uploader"] | Should -Be "testuser"
            $result["uploader_id"] | Should -Be "testuser"
            $result["webpage_url"] | Should -Be $testUrl
        }
    }
}

