<#
.SYNOPSIS
    Тесты для метода GetMediaInfo сервиса MediaInfoExtractorService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода GetMediaInfo сервиса MediaInfoExtractorService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "MediaInfoExtractorService.GetMediaInfo Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        # Строчка ниже устраняет эту ошибку
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        
        # Импортируем основной модуль
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
        
        # Устанавливаем тестовые параметры
        $script:testFilePath = Join-Path -Path $env:TEMP -ChildPath "test_video.mp4"
        
        # Создаем тестовый файл
        "Test video content" | Out-File -FilePath $script:testFilePath -Force
    }
    
    BeforeEach {
        InModuleScope -ModuleName AnalyzeTTBot {
            # Стандартный JSON для MediaInfo
            $script:standardMediaInfoJson = '{"media":{"track":[{"type":"General","FileSize":"5767168","Duration":"15.000","Duration_String3":"00:00:15"},{"type":"Video","Width":"1080","Height":"1920","FrameRate":"60","FrameCount":"900","Format":"h264","Format_Profile":"Main@L4.1","BitRate":"2000000"},{"type":"Audio","Format":"aac","Channels":"2","BitRate":"128000","SamplingRate":"44100"}]}}'
            
            # Создаем экземпляр IFileSystemService внутри модуля
            $script:fileSystemServiceMock = New-Object -TypeName IFileSystemService
            $script:fileSystemServiceMock | Add-Member -MemberType ScriptMethod -Name GetTempFolderPath -Value {
                return (Join-Path -Path $env:TEMP -ChildPath "TikTokAnalyzerTest")
            } -Force
            
            $script:fileSystemServiceMock | Add-Member -MemberType ScriptMethod -Name NewTempFileName -Value {
                param([string]$extension)
                $tempFolder = $this.GetTempFolderPath()
                $fileName = "test_" + [Guid]::NewGuid().ToString() + $extension
                return (Join-Path -Path $tempFolder -ChildPath $fileName)
            } -Force
            
            $script:fileSystemServiceMock | Add-Member -MemberType ScriptMethod -Name RemoveTempFiles -Value {
                param([int]$olderThanDays)
                return (New-SuccessResponse -Data 0)
            } -Force
            
            $script:fileSystemServiceMock | Add-Member -MemberType ScriptMethod -Name EnsureFolderExists -Value {
                param([string]$path)
                return (New-SuccessResponse -Data $path)
            } -Force
            
            # Создаем экземпляр MediaInfoExtractorService для тестирования
            $script:mediaInfoExtractorService = New-Object -TypeName MediaInfoExtractorService -ArgumentList @($script:fileSystemServiceMock)
            
            # Мокируем ConvertFrom-JsonSafe
            Mock -CommandName ConvertFrom-JsonSafe -MockWith { 
                # Создаем объект, соответствующий JSON-выводу MediaInfo
                return [PSCustomObject]@{
                    media = [PSCustomObject]@{
                        track = @(
                            [PSCustomObject]@{
                                type = "General"
                                FileSize = "5767168"
                                Duration = "15.000"
                                Duration_String3 = "00:00:15"
                            },
                            [PSCustomObject]@{
                                type = "Video"
                                Width = "1080"
                                Height = "1920"
                                FrameRate = "60"
                                FrameCount = "900"
                                Format = "h264"
                                Format_Profile = "Main@L4.1"
                                BitRate = "2000000"
                            },
                            [PSCustomObject]@{
                                type = "Audio"
                                Format = "aac"
                                Channels = "2"
                                BitRate = "128000"
                                SamplingRate = "44100"
                            }
                        )
                    }
                }
            } -ModuleName AnalyzeTTBot
            
            # Мокируем Test-Path
            Mock -CommandName Test-Path -MockWith { return $true } -ParameterFilter { $Path -eq $script:testFilePath } -ModuleName AnalyzeTTBot
            
            # Мокируем Invoke-ExternalProcess для стандартного успешного вызова
            Mock -CommandName Invoke-ExternalProcess -MockWith {
                return @{
                    success = $true
                    Output = $script:standardMediaInfoJson
                    Error = ""
                    ExitCode = 0
                }
            } -ModuleName AnalyzeTTBot
        }
    }
    
    Context "Media Info extraction" {
        It "Should parse MediaInfo output correctly" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{testFilePath = $script:testFilePath} {
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.GetMediaInfo($testFilePath)
                
                # Проверяем результат
                $result.Success | Should -BeTrue
                $result.Data.FileSize | Should -Be 5767168
                $result.Data.FileSizeMB | Should -Be 5.5
                $result.Data.Duration | Should -Be "15.000"
                $result.Data.DurationFormatted | Should -Be "00:00:15"
                $result.Data.Width | Should -Be 1080
                $result.Data.Height | Should -Be 1920
                $result.Data.AspectRatio | Should -Be "1080:1920"
                $result.Data.FPS | Should -Be 60
                $result.Data.FrameCount | Should -Be 900
                $result.Data.VideoCodec | Should -Be "h264"
                $result.Data.VideoProfile | Should -Be "Main@L4.1"
                $result.Data.VideoBitRate | Should -Be 2000000
                $result.Data.VideoBitRateFormatted | Should -Be "2000 kbps"
                $result.Data.HasAudio | Should -BeTrue
                $result.Data.AudioCodec | Should -Be "aac"
                $result.Data.AudioChannels | Should -Be 2
                $result.Data.AudioBitRate | Should -Be 128000
                $result.Data.AudioBitRateFormatted | Should -Be "128 kbps"
                $result.Data.AudioSampleRate | Should -Be 44100
                $result.Data.AudioSampleRateFormatted | Should -Be "44.1 kHz"
            }
        }
        
        It "Should handle non-existent file" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{testFilePath = $script:testFilePath} {
                # Мокируем Test-Path для возврата false
                Mock -CommandName Test-Path -MockWith { return $false } -ParameterFilter { $Path -eq $testFilePath } -ModuleName AnalyzeTTBot
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.GetMediaInfo($testFilePath)
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Be "File not found: $testFilePath"
            }
        }
        
        It "Should handle MediaInfo errors" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{testFilePath = $script:testFilePath} {
                # Мокируем Invoke-ExternalProcess для возврата ошибки
                Mock -CommandName Invoke-ExternalProcess -MockWith {
                    return @{
                        success = $false
                        Output = ""
                        Error = "Error processing file"
                        ExitCode = 1
                    }
                } -ModuleName AnalyzeTTBot
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.GetMediaInfo($testFilePath)
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "MediaInfo failed with exit code 1"
            }
        }
        
        It "Should handle JSON parsing errors" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{testFilePath = $script:testFilePath} {
                # Мокируем ConvertFrom-JsonSafe для симуляции ошибки парсинга
                Mock -CommandName ConvertFrom-JsonSafe -MockWith {
                    return $null
                } -ModuleName AnalyzeTTBot
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.GetMediaInfo($testFilePath)
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Failed to parse MediaInfo output"
            }
        }
        
        It "Should handle missing media tracks gracefully" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{testFilePath = $script:testFilePath} {
                # Мокируем ConvertFrom-JsonSafe для возврата данных без Video и General треков
                Mock -CommandName ConvertFrom-JsonSafe -MockWith {
                    return [PSCustomObject]@{
                        media = [PSCustomObject]@{
                            track = @(
                                [PSCustomObject]@{
                                    type = "Audio"
                                    Format = "aac"
                                }
                            )
                        }
                    }
                } -ModuleName AnalyzeTTBot
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.GetMediaInfo($testFilePath)
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "Unable to analyze video: No.*tracks found"
            }
        }
        
        It "Should handle empty MediaInfo output" {
            InModuleScope -ModuleName AnalyzeTTBot -Parameters @{testFilePath = $script:testFilePath} {
                # Мокируем Invoke-ExternalProcess для возврата пустого вывода
                Mock -CommandName Invoke-ExternalProcess -MockWith {
                    return @{
                        success = $true
                        Output = ""
                        Error = ""
                        ExitCode = 0
                    }
                } -ModuleName AnalyzeTTBot
                
                # Вызываем метод
                $result = $script:mediaInfoExtractorService.GetMediaInfo($testFilePath)
                
                # Проверяем результат
                $result.Success | Should -BeFalse
                $result.Error | Should -Match "MediaInfo returned empty output"
            }
        }
    }
    
    AfterAll {
        # Удаляем тестовый файл
        Remove-Item -Path $script:testFilePath -Force -ErrorAction SilentlyContinue
        
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}