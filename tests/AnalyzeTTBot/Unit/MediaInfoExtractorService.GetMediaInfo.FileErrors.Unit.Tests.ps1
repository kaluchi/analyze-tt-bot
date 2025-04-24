#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода GetMediaInfo в MediaInfoExtractorService - проверка обработки ошибок файловой системы.
.DESCRIPTION
    Модульные тесты для проверки обработки ошибок файлов в методе GetMediaInfo сервиса MediaInfoExtractorService.
    Фокус на непокрытых сценариях отсутствующих файлов и ошибок обработки (строки 26-27, 38-40).
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'MediaInfoExtractorService.GetMediaInfo file errors' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    
    It 'Должен возвращать ошибку для пустого пути' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Создаем мок FileSystemService
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value {
                return "C:\\Temp"
            } -Force
            
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value {
                param([string]$extension)
                return "C:\\Temp\\mockfile$extension"
            } -Force
            
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name RemoveTempFiles -Value {
                param([int]$olderThanDays)
                return @{ Success = $true; Data = 0; Error = $null }
            } -Force
            
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                param([string]$path)
                return @{ Success = $true; Data = $path; Error = $null }
            } -Force
            
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            # MediaInfoExtractorService использует Test-Path, поэтому мокаем его
            Mock Test-Path { 
                if ([string]::IsNullOrWhiteSpace($Path)) { 
                    return $false 
                }
                return $false 
            } -ModuleName AnalyzeTTBot
            
            $emptyPaths = @("", "   ", "`t`n")
            foreach ($path in $emptyPaths) {
                $result = $mediaInfoService.GetMediaInfo($path)
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "File not found"
            }
            
            # Для null path тест должен вернуть другую ошибку из-за особенностей работы Test-Path
            try {
                $mediaInfoService.GetMediaInfo($null)
            } catch {
                $_.Exception.Message | Should -Match "because it is (null|an empty string)"
            }
        }
    }
    
    It 'Должен возвращать ошибку для несуществующего файла' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Создаем мок FileSystemService
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param([string]$extension); return "C:\\Temp\\mockfile$extension" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name RemoveTempFiles -Value { param([int]$olderThanDays); return @{ Success = $true; Data = 0; Error = $null } } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param([string]$path); return @{ Success = $true; Data = $path; Error = $null } } -Force
            
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Test-Path для несуществующего файла
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq "C:\NonExistent\video.mp4" } -ModuleName AnalyzeTTBot
            
            $nonExistentPath = "C:\NonExistent\video.mp4"
            $result = $mediaInfoService.GetMediaInfo($nonExistentPath)
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "File not found"
        }
    }
    
    It 'Должен обрабатывать ошибки доступа к файлу' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Создаем мок FileSystemService
            $mockFileSystemService = [IFileSystemService]::new()
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value { return "C:\\Temp" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value { param([string]$extension); return "C:\\Temp\\mockfile$extension" } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name RemoveTempFiles -Value { param([int]$olderThanDays); return @{ Success = $true; Data = 0; Error = $null } } -Force
            $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value { param([string]$path); return @{ Success = $true; Data = $path; Error = $null } } -Force
            
            $mediaInfoService = [MediaInfoExtractorService]::new($mockFileSystemService)
            
            # Мокаем Test-Path, чтобы он возвращал true, но затем мокаем Invoke-ExternalProcess с ошибкой доступа
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq "C:\Protected\video.mp4" } -ModuleName AnalyzeTTBot
            Mock Invoke-ExternalProcess {
                throw "Отказано в доступе при чтении файла"
            } -ModuleName AnalyzeTTBot
            
            $result = $mediaInfoService.GetMediaInfo("C:\Protected\video.mp4")
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Отказано в доступе"
        }
    }
}
