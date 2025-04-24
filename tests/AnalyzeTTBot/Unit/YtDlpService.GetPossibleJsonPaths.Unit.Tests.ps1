#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода GetPossibleJsonPaths в YtDlpService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода GetPossibleJsonPaths сервиса YtDlpService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe 'YtDlpService.GetPossibleJsonPaths method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Возвращает оба варианта путей к JSON' {
        InModuleScope AnalyzeTTBot {
            $mockFileSystemService = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
            $outputPath = "C:\\temp\\video.mp4"
            $result = $ytDlpService.GetPossibleJsonPaths($outputPath)
            if ($result -isnot [System.Collections.IEnumerable] -or $result -is [string]) {
                $result = @($result)
            }
            # Нормализуем пути для сравнения: убираем все слэши и сравниваем только имена файлов
            $normalized = $result | ForEach-Object { [System.IO.Path]::GetFileName($_) }
            $normalized.Count | Should -Be 2
            $normalized | Should -Contain "video.mp4.info.json"
            $normalized | Should -Contain "video.info.json"
        }
    }
}
