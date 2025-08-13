#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Unit-тесты для метода GetOutputPath класса YtDlpService.
.DESCRIPTION
    Проверяет корректность возвращаемого пути при явном указании outputPath и при его отсутствии.
#>

Describe 'YtDlpService.GetOutputPath method' {
    BeforeAll {
        # В минимальном окружении PSFramework падает без ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath('CommonApplicationData')
        $projectRoot  = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
        $manifestPath = Join-Path $projectRoot 'src/AnalyzeTTBot/AnalyzeTTBot.psd1'
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Возвращает исходный путь, если он указан' {
        InModuleScope AnalyzeTTBot {
            $mockFs = [IFileSystemService]::new()
            $ytDlpService = [YtDlpService]::new('yt-dlp',$mockFs,30,'best','')
            $explicitPath = 'C:\Temp\explicit.mp4'
            $resultPath   = $ytDlpService.GetOutputPath($explicitPath)
            $resultPath | Should -Be $explicitPath
        }
    }

    It 'Генерирует временный файл, если путь не указан' {
        InModuleScope AnalyzeTTBot {
            $mockFs = [IFileSystemService]::new()
            # Переопределяем NewTempFileName, чтобы вернуть предсказуемое значение
            $mockFs | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value {
                param($ext)
                return "C:\\Temp\\generated$ext"
            } -Force
            $ytDlpService = [YtDlpService]::new('yt-dlp',$mockFs,30,'best','')
            $resultPath   = $ytDlpService.GetOutputPath('')
            $resultPath | Should -Be 'C:\\Temp\\generated.mp4'
        }
    }
}