#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Дополнительные тесты для метода SaveTikTokVideo в YtDlpService.
.DESCRIPTION
    Расширенные модульные тесты для покрытия непротестированных веток кода в методе SaveTikTokVideo.
    Фокус на edge cases, error paths и integration scenarios.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 13.08.2025
    Цель: Повысить покрытие с 70.54% до 85%+
#>

Describe "YtDlpService.SaveTikTokVideo Extended Coverage Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
    }

    Context "Edge cases and error paths" {
        It "Should handle ProcessMetadata failure after successful download" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                    param($path)
                    return New-SuccessResponse -Data @{}
                } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value {
                    return "C:\Temp\TestFolder"
                } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value {
                    param($extension)
                    return "C:\Temp\TestFolder\test.mp4"
                } -Force
                
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем Test-Path для проверки существования файла
                Mock Test-Path { return $true } -ModuleName AnalyzeTTBot
                
                # Мокируем GetOutputPath
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "GetOutputPath" -Value {
                    param($outputPath)
                    return "C:\temp\test.mp4"
                } -Force
                
                # Мокируем ExecuteYtDlp для успеха
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    return New-SuccessResponse -Data @{ RawOutput = @("Downloaded successfully"); OutputPath = $outputPath }
                } -Force
                
                # Мокируем ProcessMetadata для неудачи
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ProcessMetadata" -Value {
                    param ($url, $outputPath)
                    throw "Failed to process metadata"
                } -Force
                
                $result = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", "")
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Failed to process metadata"
            }
        }

        It "Should handle null or whitespace URL properly" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Test null URL
                $result1 = $ytDlpService.SaveTikTokVideo($null, "C:\temp\output.mp4")
                $result1.Success | Should -BeFalse
                $result1.Error | Should -Be "Empty URL provided"
                
                # Test whitespace URL
                $result2 = $ytDlpService.SaveTikTokVideo("   ", "C:\temp\output.mp4")
                $result2.Success | Should -BeFalse
                $result2.Error | Should -Be "Empty URL provided"
                
                # Test empty string URL
                $result3 = $ytDlpService.SaveTikTokVideo("", "C:\temp\output.mp4")
                $result3.Success | Should -BeFalse
                $result3.Error | Should -Be "Empty URL provided"
            }
        }

        It "Should handle GetOutputPath integration correctly" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value {
                    return "C:\Temp\MockFolder"
                } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value {
                    param($extension)
                    return "C:\Temp\MockFolder\generated_file.mp4"
                } -Force
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                    param($path)
                    return New-SuccessResponse -Data @{}
                } -Force
                
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем GetOutputPath
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "GetOutputPath" -Value {
                    param($outputPath)
                    if ([string]::IsNullOrEmpty($outputPath)) {
                        return "C:\Temp\MockFolder\generated_file.mp4"
                    } else {
                        return $outputPath
                    }
                } -Force
                
                # Глобальные переменные для отслеживания вызовов
                $global:executedWithPath = ""
                $global:processedWithPath = ""
                
                # Мокируем Test-Path для проверки существования файла
                Mock Test-Path { return $true } -ModuleName AnalyzeTTBot
                
                # Мокируем ExecuteYtDlp
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    $global:executedWithPath = $outputPath
                    return New-SuccessResponse -Data @{ RawOutput = @("Success"); OutputPath = $outputPath }
                } -Force
                
                # Мокируем ProcessMetadata
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ProcessMetadata" -Value {
                    param ($url, $outputPath)
                    $global:processedWithPath = $outputPath
                    return @{ 
                        FilePath = $outputPath
                        JsonFilePath = "$outputPath.info.json"
                        JsonContent = @{ title = "Test Video" }
                        AuthorUsername = "testuser"
                        VideoTitle = "Test Video"
                        FullVideoUrl = $url 
                    }
                } -Force
                
                # Тестируем с пустым outputPath - должен использовать временный файл
                $result = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", "")
                
                $result.Success | Should -BeTrue
                $global:executedWithPath | Should -Be "C:\Temp\MockFolder\generated_file.mp4"
                $global:processedWithPath | Should -Be "C:\Temp\MockFolder\generated_file.mp4"
                $result.Data.OutputPath | Should -Be "C:\Temp\MockFolder\generated_file.mp4"
            }
        }

        It "Should handle ExecuteYtDlp returning null or malformed response" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                    param($path)
                    return New-SuccessResponse -Data @{}
                } -Force
                
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем GetOutputPath
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "GetOutputPath" -Value {
                    param($outputPath)
                    if ([string]::IsNullOrEmpty($outputPath)) {
                        return "C:\Users\TestUser\Downloads\TikTok\2025\August\video.mp4"
                    } else {
                        return $outputPath
                    }
                } -Force
                
                # Мокируем Test-Path для проверки существования файла
                Mock Test-Path { return $true } -ModuleName AnalyzeTTBot
                
                # Test null response
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    return $null
                } -Force
                
                $result1 = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", "C:\temp\output.mp4")
                $result1.Success | Should -BeFalse
                
                # Test response without Success property
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    return @{ Data = @{} }  # Missing Success property
                } -Force
                
                $result2 = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", "C:\temp\output.mp4")
                $result2.Success | Should -BeFalse
            }
        }

        It "Should handle exception in ExecuteYtDlp method" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                    param($path)
                    return New-SuccessResponse -Data @{}
                } -Force
                
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем Test-Path для проверки существования файла
                Mock Test-Path { return $true } -ModuleName AnalyzeTTBot
                
                # Мокируем GetOutputPath
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "GetOutputPath" -Value {
                    param($outputPath)
                    return $outputPath
                } -Force
                
                # Мокируем ExecuteYtDlp для выброса исключения
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    throw "Network timeout exception"
                } -Force
                
                $result = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", "C:\temp\output.mp4")
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Network timeout exception"
            }
        }

        It "Should return all required fields in success response" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                    param($path)
                    return New-SuccessResponse -Data @{}
                } -Force
                
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем GetOutputPath
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "GetOutputPath" -Value {
                    param($outputPath)
                    if ([string]::IsNullOrEmpty($outputPath)) {
                        return "C:\temp\final.mp4"
                    } else {
                        return $outputPath
                    }
                } -Force
                
                # Мокируем Test-Path для проверки существования файла
                Mock Test-Path { return $true } -ModuleName AnalyzeTTBot
                
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    return New-SuccessResponse -Data @{ RawOutput = @("success"); OutputPath = $outputPath }
                } -Force
                
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ProcessMetadata" -Value {
                    param ($url, $outputPath)
                    return @{ 
                        FilePath = "C:\temp\final.mp4"
                        JsonFilePath = "C:\temp\final.mp4.info.json"
                        JsonContent = @{ title = "Test Video"; id = "123456" }
                        AuthorUsername = "testauthor"
                        VideoTitle = "Amazing Test Video"
                        FullVideoUrl = "https://tiktok.com/@testauthor/video/123456" 
                    }
                } -Force
                
                $result = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", "C:\temp\output.mp4")
                
                $result.Success | Should -BeTrue
                $result.Data | Should -Not -BeNullOrEmpty
                
                # Проверяем все обязательные поля
                $result.Data.FilePath | Should -Be "C:\temp\final.mp4"
                $result.Data.JsonFilePath | Should -Be "C:\temp\final.mp4.info.json"
                $result.Data.JsonContent | Should -Not -BeNullOrEmpty
                $result.Data.AuthorUsername | Should -Be "testauthor"
                $result.Data.VideoTitle | Should -Be "Amazing Test Video"
                $result.Data.FullVideoUrl | Should -Be "https://tiktok.com/@testauthor/video/123456"
                $result.Data.InputUrl | Should -Be "https://tiktok.com/@user/video/123456"
                $result.Data.OutputPath | Should -Be "C:\temp\output.mp4"
            }
        }

        It "Should handle complex directory structure creation" {
            InModuleScope AnalyzeTTBot {
                $mockFileSystemService = [IFileSystemService]::new()
                
                # Глобальная переменная для отслеживания пути создания директории
                $global:directoryCreated = ""
                
                $mockFileSystemService | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                    param($path)
                    $global:directoryCreated = $path
                    return New-SuccessResponse -Data @{}
                } -Force
                
                $ytDlpService = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best", "")
                
                # Мокируем GetOutputPath
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "GetOutputPath" -Value {
                    param($outputPath)
                    return $outputPath
                } -Force
                
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
                    param ($url, $outputPath)
                    return New-SuccessResponse -Data @{ RawOutput = @("success"); OutputPath = $outputPath }
                } -Force
                
                # Мокируем Test-Path и [System.IO.File]::Exists для проверки существования файла
                Mock Test-Path { return $true } -ModuleName AnalyzeTTBot
                
                $ytDlpService | Add-Member -MemberType ScriptMethod -Name "ProcessMetadata" -Value {
                    param ($url, $outputPath)
                    return @{ 
                        FilePath = $outputPath
                        JsonFilePath = "$outputPath.info.json"
                        JsonContent = @{ title = "Test" }
                        AuthorUsername = "user"
                        VideoTitle = "Test"
                        FullVideoUrl = $url 
                    }
                } -Force
                
                # Тестируем с вложенной структурой директорий
                $complexPath = "C:\Users\TestUser\Downloads\TikTok\2025\August\video.mp4"
                $result = $ytDlpService.SaveTikTokVideo("https://tiktok.com/@user/video/123456", $complexPath)
                
                $result.Success | Should -BeTrue
                $global:directoryCreated | Should -Be "C:\Users\TestUser\Downloads\TikTok\2025\August"
            }
        }
    }

    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}
