#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ExtractUsernameFromUrl в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ExtractUsernameFromUrl сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe 'YtDlpService.ExtractUsernameFromUrl method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Корректно извлекает username из разных ссылок' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
            $ytDlpService.ExtractUsernameFromUrl("https://www.tiktok.com/@testuser/video/1234567890") | Should -Be "testuser"
            $ytDlpService.ExtractUsernameFromUrl("https://tiktok.com/@another_user/video/987654321") | Should -Be "another_user"
            $ytDlpService.ExtractUsernameFromUrl("https://www.tiktok.com/@user123") | Should -Be "user123"
            $ytDlpService.ExtractUsernameFromUrl("https://tiktok.com/@user.name/video/111") | Should -Be "user.name"
            $ytDlpService.ExtractUsernameFromUrl("https://tiktok.com/video/123456") | Should -Be ""
            $ytDlpService.ExtractUsernameFromUrl("") | Should -Be ""
        }
    }
}

