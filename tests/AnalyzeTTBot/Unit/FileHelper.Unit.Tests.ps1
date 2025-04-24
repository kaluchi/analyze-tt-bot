#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для модуля FileHelper.
.DESCRIPTION
    Модульные тесты для проверки функциональности FileHelper.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
#>

Describe "FileHelper" {
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
        
        # Создаем временную директорию для тестов
        $script:TestDir = Join-Path -Path $env:TEMP -ChildPath "FileHelperTest_$(Get-Random)"
        New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
        
        # Создаем тестовый файл
        $script:TestFile = Join-Path -Path $script:TestDir -ChildPath "testfile.txt"
        "Test content" | Out-File -FilePath $script:TestFile -Encoding utf8
        
        # Импортируем вспомогательный модуль, если он существует
        $helperPath = Join-Path $PSScriptRoot "..\Helpers\TestResponseHelper.psm1"
        if (Test-Path $helperPath) {
            Import-Module -Name $helperPath -Force -ErrorAction SilentlyContinue
        }
    }

    Describe "Test-DirectoryExists" {
        Context "Directory validation" {
            It "Should return true for existing directory" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    $result = Test-DirectoryExists -Path $TestDir
                    $result | Should -BeTrue
                }
            }
            
            It "Should return false for nonexistent directory" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    $nonExistentDir = Join-Path -Path $TestDir -ChildPath "nonexistent"
                    $result = Test-DirectoryExists -Path $nonExistentDir
                    $result | Should -BeFalse
                }
            }
            
            It "Should create directory if -Create specified" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    $newDir = Join-Path -Path $TestDir -ChildPath "newdir"
                    $result = Test-DirectoryExists -Path $newDir -Create
                    $result | Should -BeTrue
                    Test-Path -Path $newDir -PathType Container | Should -BeTrue
                }
            }
        }
    }
    
    Describe "New-TemporaryFilePath" {
        Context "Path generation" {
            It "Should generate valid temporary file path" {
                InModuleScope AnalyzeTTBot {
                    $result = New-TemporaryFilePath
                    $result | Should -Not -BeNullOrEmpty
                    [System.IO.Path]::GetExtension($result) | Should -Be ".tmp"
                    Split-Path -Parent $result | Should -Be $env:TEMP
                }
            }
            
            It "Should use specified extension" {
                InModuleScope AnalyzeTTBot {
                    $result = New-TemporaryFilePath -Extension ".test"
                    [System.IO.Path]::GetExtension($result) | Should -Be ".test"
                }
            }
            
            It "Should add dot to extension if missing" {
                InModuleScope AnalyzeTTBot {
                    $result = New-TemporaryFilePath -Extension "test"
                    [System.IO.Path]::GetExtension($result) | Should -Be ".test"
                }
            }
            
            It "Should use specified prefix" {
                InModuleScope AnalyzeTTBot {
                    $prefix = "testprefix_"
                    $result = New-TemporaryFilePath -Prefix $prefix
                    [System.IO.Path]::GetFileName($result) | Should -Match "^$prefix"
                }
            }
            
            It "Should use specified directory" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    $result = New-TemporaryFilePath -Directory $TestDir
                    Split-Path -Parent $result | Should -Be $TestDir
                }
            }
        }
    }
    
    Describe "Remove-OldFiles" {
        Context "File cleanup" {
            It "Should remove old files" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    # Создаем тестовые файлы с разными датами
                    $oldFile = Join-Path -Path $TestDir -ChildPath "oldfile.txt"
                    "Old content" | Out-File -FilePath $oldFile -Encoding utf8
                    
                    $newFile = Join-Path -Path $TestDir -ChildPath "newfile.txt"
                    "New content" | Out-File -FilePath $newFile -Encoding utf8
                    
                    # Устанавливаем дату старого файла
                    $item = Get-Item -Path $oldFile
                    $item.LastWriteTime = (Get-Date).AddDays(-10)
                    
                    # Удаляем файлы старше 5 дней
                    $result = Remove-OldFiles -Path $TestDir -OlderThanDays 5 -Filter "*.txt"
                    
                    # Проверяем результат
                    $result | Should -Be 1
                    Test-Path -Path $oldFile | Should -BeFalse
                    Test-Path -Path $newFile | Should -BeTrue
                }
            }
            
            It "Should return 0 for nonexistent directory" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    $nonExistentDir = Join-Path -Path $TestDir -ChildPath "nonexistent"
                    $result = Remove-OldFiles -Path $nonExistentDir -OlderThanDays 5
                    $result | Should -Be 0
                }
            }
        }
    }
    
    Describe "Get-FileHash256" {
        Context "Hash calculation" {
            It "Should calculate correct hash for file" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    # Создаем файл с известным содержимым
                    $knownContent = "Test content for hash"
                    $hashFile = Join-Path -Path $TestDir -ChildPath "hashfile.txt"
                    $knownContent | Out-File -FilePath $hashFile -Encoding utf8
                    
                    # Рассчитываем ожидаемый хеш
                    $expectedHash = (Get-FileHash -Path $hashFile -Algorithm SHA256).Hash.ToLower()
                    
                    # Вызываем нашу функцию
                    $result = Get-FileHash256 -Path $hashFile
                    
                    # Проверяем результат
                    $result | Should -Be $expectedHash
                }
            }
            
            It "Should return null for nonexistent file" {
                InModuleScope AnalyzeTTBot -Parameters @{TestDir = $script:TestDir} {
                    $nonExistentFile = Join-Path -Path $TestDir -ChildPath "nonexistent.txt"
                    $result = Get-FileHash256 -Path $nonExistentFile
                    $result | Should -BeNullOrEmpty
                }
            }
        }
    }
    
    Describe "Get-EnsuredTempPath" {
        Context "Temp directory management" {
            It "Should return system temp path if no subpath specified" {
                InModuleScope AnalyzeTTBot {
                    $result = Get-EnsuredTempPath
                    $result | Should -Be $env:TEMP
                }
            }
            
            It "Should create subpath in temp directory" {
                InModuleScope AnalyzeTTBot {
                    $subPath = "TestSubDir_$(Get-Random)"
                    $result = Get-EnsuredTempPath -SubPath $subPath
                    
                    $expected = Join-Path -Path $env:TEMP -ChildPath $subPath
                    $result | Should -Be $expected
                    Test-Path -Path $result -PathType Container | Should -BeTrue
                    
                    # Очистка
                    if (Test-Path -Path $result) {
                        Remove-Item -Path $result -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    AfterAll {
        # Удаляем временную директорию после тестов
        if (Test-Path -Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Удаляем вспомогательные модули
        if (Get-Module -Name TestResponseHelper) {
            Remove-Module -Name TestResponseHelper -Force -ErrorAction SilentlyContinue
        }

        # Удаляем основной модуль после выполнения тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}