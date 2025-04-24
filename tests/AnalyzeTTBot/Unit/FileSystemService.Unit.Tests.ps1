#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для FileSystemService.
.DESCRIPTION
    Модульные тесты для проверки функциональности FileSystemService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
#>

Describe "FileSystemService" {
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
        $script:tempFolderName = "TikTokAnalyzerTest"
        $script:testFileExtension = ".test"
        
        # Создаем тестовую директорию
        $script:TestDir = Join-Path -Path $env:TEMP -ChildPath "FileSystemServiceTest_$(Get-Random)"
        New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
    }

    Describe "Constructor and initialization" {
        Context "Basic functionality" {
            It "Should create an instance with correct temp folder name" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $fileSystemService.TempFolderName | Should -Be $tempFolderName
                }
            }
            
            It "Should create the temp folder if it doesn't exist" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $tempPath = $fileSystemService.GetTempFolderPath()
                    Test-Path -Path $tempPath | Should -BeTrue
                }
            }
        }
    }
    
    Describe "GetTempFolderPath method" {
        Context "Path validation" {
            It "Should return a valid path" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $tempPath = $fileSystemService.GetTempFolderPath()
                    Test-Path -Path $tempPath | Should -BeTrue
                }
            }
            
            It "Should include the temp folder name in the path" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $tempPath = $fileSystemService.GetTempFolderPath()
                    $tempPath | Should -Match $tempFolderName
                }
            }
        }
    }
    
    Describe "NewTempFileName method" {
        Context "Filename generation" {
            It "Should generate a unique filename with the specified extension" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName; testFileExtension = $script:testFileExtension} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $fileName = $fileSystemService.NewTempFileName($testFileExtension)
                    [System.IO.Path]::GetExtension($fileName) | Should -Be $testFileExtension
                }
            }
            
            It "Should prepend extension with a dot if needed" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $extension = "test" # without dot
                    $fileName = $fileSystemService.NewTempFileName($extension)
                    [System.IO.Path]::GetExtension($fileName) | Should -Be ".test"
                }
            }
            
            It "Should generate different filenames on each call" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName; testFileExtension = $script:testFileExtension} {
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $fileName1 = $fileSystemService.NewTempFileName($testFileExtension)
                    $fileName2 = $fileSystemService.NewTempFileName($testFileExtension)
                    $fileName1 | Should -Not -Be $fileName2
                }
            }
        }
    }
    
    Describe "EnsureFolderExists method" {
        Context "Folder creation" {
            It "Should create a folder that doesn't exist" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName; TestDir = $script:TestDir} {
                    # Создаем экземпляр сервиса
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    
                    # Создаем уникальный путь для теста
                    $testPath = Join-Path -Path $TestDir -ChildPath ("test_" + [Guid]::NewGuid().ToString())
                    
                    # Проверяем, что папки нет
                    if (Test-Path -Path $testPath) {
                        Remove-Item -Path $testPath -Force -Recurse
                    }
                    
                    Test-Path -Path $testPath | Should -BeFalse
                    
                    # Вызываем метод
                    $result = $fileSystemService.EnsureFolderExists($testPath)
                    
                    # Проверяем результат и наличие папки
                    $result.Success | Should -BeTrue
                    $result.Data | Should -Be $testPath
                    Test-Path -Path $testPath | Should -BeTrue
                    
                    # Очистка
                    Remove-Item -Path $testPath -Force -Recurse -ErrorAction SilentlyContinue
                }
            }
            
            It "Should return success response if the folder already exists" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName; TestDir = $script:TestDir} {
                    # Создаем экземпляр сервиса
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    
                    # Создаем папку
                    $testPath = Join-Path -Path $TestDir -ChildPath ("test_" + [Guid]::NewGuid().ToString())
                    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
                    
                    # Проверяем, что папка существует
                    Test-Path -Path $testPath | Should -BeTrue
                    
                    # Вызываем метод
                    $result = $fileSystemService.EnsureFolderExists($testPath)
                    
                    # Проверяем результат
                    $result.Success | Should -BeTrue
                    $result.Data | Should -Be $testPath
                    
                    # Очистка
                    Remove-Item -Path $testPath -Force -Recurse -ErrorAction SilentlyContinue
                }
            }            
            
            It "Should return error response if folder creation fails" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName} {
                    # Создаем экземпляр сервиса
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    
                    # Мокируем Test-DirectoryExists, чтобы он возвращал false
                    Mock -CommandName Test-DirectoryExists -MockWith { return $false } -ModuleName AnalyzeTTBot
                    
                    # Имитируем ошибку создания папки, используя недопустимый путь
                    $invalidPath = "X:\NonExistentDrive\InvalidPath"
                    
                    # Вызываем метод
                    $result = $fileSystemService.EnsureFolderExists($invalidPath)
                    
                    # Проверяем результат
                    $result.Success | Should -BeFalse
                    $result.Error | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
    
    Describe "RemoveTempFiles method" {
        Context "File cleanup" {
            It "Should remove files older than the specified number of days" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName; TestDir = $script:TestDir; testFileExtension = $script:testFileExtension} {
                    # Создаем экземпляр сервиса
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $tempFolderPath = $fileSystemService.GetTempFolderPath()
                    
                    # Создаем тестовые файлы
                    $oldFile = Join-Path -Path $tempFolderPath -ChildPath ("test_old" + $testFileExtension)
                    $newFile = Join-Path -Path $tempFolderPath -ChildPath ("test_new" + $testFileExtension)
                    
                    # Создаем файлы
                    "Test old file" | Out-File -FilePath $oldFile -Force
                    "Test new file" | Out-File -FilePath $newFile -Force
                    
                    # Изменяем дату создания старого файла на 10 дней назад
                    $item = Get-Item -Path $oldFile
                    $item.LastWriteTime = (Get-Date).AddDays(-10)
                    
                    # Проверяем, что файлы существуют
                    Test-Path -Path $oldFile | Should -BeTrue
                    Test-Path -Path $newFile | Should -BeTrue
                    
                    # Вызываем метод для удаления файлов старше 5 дней
                    $result = $fileSystemService.RemoveTempFiles(5)
                    
                    # Проверяем результат метода
                    $result.Success | Should -BeTrue
                    $result.Data | Should -BeGreaterOrEqual 1
                    
                    # Проверяем результат на файловой системе
                    Test-Path -Path $oldFile | Should -BeFalse
                    Test-Path -Path $newFile | Should -BeTrue
                    
                    # Очистка
                    Remove-Item -Path $newFile -Force -ErrorAction SilentlyContinue
                }
            }
            
            It "Should handle case when temp folder doesn't exist" {
                InModuleScope AnalyzeTTBot {
                    # Создаем тестовый экземпляр с несуществующей папкой
                    $nonExistentFolderName = "NonExistentFolder_" + [Guid]::NewGuid().ToString()
                    $testService = [FileSystemService]::new($nonExistentFolderName)
                    
                    # Удаляем папку, если она была создана
                    $tempPath = $testService.GetTempFolderPath()
                    if (Test-Path -Path $tempPath) {
                        Remove-Item -Path $tempPath -Force -Recurse -ErrorAction SilentlyContinue
                    }
                    
                    # Мокируем Get-ChildItem, чтобы он возвращал пустой массив
                    Mock -CommandName Get-ChildItem -MockWith { return @() } -ModuleName AnalyzeTTBot
                    
                    # Проверяем, что папка не существует
                    Test-Path -Path $tempPath | Should -BeFalse
                    
                    # Вызываем метод - он не должен выбрасывать исключение
                    $result = $testService.RemoveTempFiles(5)
                    
                    # Проверяем результат метода
                    $result.Success | Should -BeTrue
                    $result.Data | Should -Be 0
                }
            }
            
            It "Should handle errors when removing files" {
                InModuleScope AnalyzeTTBot -Parameters @{tempFolderName = $script:tempFolderName; TestDir = $script:TestDir; testFileExtension = $script:testFileExtension} {
                    # Создаем экземпляр сервиса
                    $fileSystemService = [FileSystemService]::new($tempFolderName)
                    $tempFolderPath = $fileSystemService.GetTempFolderPath()
                    
                    # Создаем тестовый файл
                    $testFile = Join-Path -Path $tempFolderPath -ChildPath ("test_error" + $testFileExtension)
                    "Test file" | Out-File -FilePath $testFile -Force
                    
                    # Изменяем дату создания файла на 10 дней назад
                    $item = Get-Item -Path $testFile
                    $item.LastWriteTime = (Get-Date).AddDays(-10)
                    
                    # Мокируем Remove-OldFiles, чтобы он выбрасывал исключение
                    Mock -CommandName Remove-OldFiles -MockWith { throw "Access denied" } -ModuleName AnalyzeTTBot
                    
                    # Вызываем метод
                    $result = $fileSystemService.RemoveTempFiles(5)
                    
                    # Проверяем результат
                    $result.Success | Should -BeFalse
                    $result.Error | Should -Not -BeNullOrEmpty
                    
                    # Очистка
                    Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    AfterAll {
        # Удаляем временную директорию после тестов
        if (Test-Path -Path $script:TestDir) {
            Remove-Item -Path $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }    
}
