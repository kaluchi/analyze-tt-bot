#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Интеграционные тесты для метода TestMediaInfoDependency в MediaInfoExtractorService.
.DESCRIPTION
    Проверяет корректность проверки наличия и версии MediaInfo через MediaInfoExtractorService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe "MediaInfoExtractorService.TestMediaInfoDependency Integration Tests" {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        $script:Config = @{}
    }
    Context "TestMediaInfoDependency basic checks" {
        It "Should validate MediaInfo installation and version" {
            InModuleScope AnalyzeTTBot {
                $fileSystemService = [FileSystemService]::new($env:TEMP)
                $mediaInfoService = [MediaInfoExtractorService]::new($fileSystemService)
                $result = $mediaInfoService.TestMediaInfoDependency([switch]$false)
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                $result.Data.Valid | Should -BeTrue
                $result.Data.Version | Should -Not -BeNullOrEmpty
                $result.Data.Description | Should -Match "MediaInfo"
            }
        }
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}