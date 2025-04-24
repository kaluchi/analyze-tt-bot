#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода SaveTikTokVideo в YtDlpService - обработка ошибок.
.DESCRIPTION
    Модульные тесты для проверки обработки ошибок в методе SaveTikTokVideo сервиса YtDlpService.
    Фокус на непокрытых сценариях ошибок (строки 33-41).
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'YtDlpService.SaveTikTokVideo error handling' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    
    It 'Должен возвращать ошибку при пустом URL' {
        InModuleScope AnalyzeTTBot {
            Mock Write-OperationFailed { } -ModuleName AnalyzeTTBot
            
            # Создаем мок FileSystemService
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value {
                return "C:\Temp"
            } -Force
            
            # Создаем экземпляр YtDlpService
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
            
            # Тестируем пустой URL
            $result = $ytDlpService.SaveTikTokVideo("", "")
            
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Empty URL provided"
                
            Should -Invoke -CommandName Write-OperationFailed -ModuleName AnalyzeTTBot -ParameterFilter {
                $Operation -eq "Save TikTok video" -and
                $ErrorMessage -match "Empty URL provided"
            }
        }
    }
    
    It 'Должен обрабатывать исключения при создании директории' {
        InModuleScope AnalyzeTTBot {
            Mock Write-OperationFailed { } -ModuleName AnalyzeTTBot
            
            # Создаем мок FileSystemService, который вызывает ошибку при создании директории
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                param($path)
                return $false
            } -Force
            
            $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
            
            $result = $ytDlpService.SaveTikTokVideo("https://tiktok.com/video/123", "C:\test\output.mp4")
            
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Failed to create output directory"
            
            # Проверяем, что было вызвано логирование ошибки
            Should -Invoke -CommandName Write-OperationFailed -ModuleName AnalyzeTTBot -ParameterFilter {
                $Operation -eq "Save TikTok video" -and
                $ErrorMessage -match "Failed to create output directory"
            }
        }
    }
}
