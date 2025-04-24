#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для модуля JsonHelper.
.DESCRIPTION
    Модульные тесты для проверки функциональности JsonHelper.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
#>


Describe "JsonHelper" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        # Строчка ниже устраняет эту ошибку
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")

        # Импортируем основной модуль
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
   Describe "JsonHelper-Tests" {
        BeforeAll {
            # Создаем временную директорию для тестов
            $script:TestDir = Join-Path -Path $env:TEMP -ChildPath "JsonHelperTest_$(Get-Random)"
            New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
            
            # Создаем тестовый JSON-файл
            $script:TestJsonFile = Join-Path -Path $script:TestDir -ChildPath "test.json"
            $script:TestJsonObject = [PSCustomObject]@{
                Name = "Test"
                Value = 123
                Nested = [PSCustomObject]@{
                    SubName = "SubTest"
                    SubValue = 456
                }
            }
            
            $script:TestJsonObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:TestJsonFile -Encoding utf8
            
            # Создаем некорректный JSON-файл
            $script:InvalidJsonFile = Join-Path -Path $script:TestDir -ChildPath "invalid.json"
            "{invalid:json" | Out-File -FilePath $script:InvalidJsonFile -Encoding utf8
        }
        
        Context "Read-JsonFile" {
            It "Should read valid JSON file" {
                # Выполняем тест вне InModuleScope
                $result = Read-JsonFile -Path $script:TestJsonFile
                
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be "Test"
                $result.Value | Should -Be 123
                $result.Nested.SubName | Should -Be "SubTest"
                $result.Nested.SubValue | Should -Be 456
            }
            
            It "Should return null for nonexistent file" {
                $nonExistentFile = Join-Path -Path $script:TestDir -ChildPath "nonexistent.json"
                $result = Read-JsonFile -Path $nonExistentFile
                $result | Should -BeNullOrEmpty
            }
            
            It "Should return null for invalid JSON file" {
                $result = Read-JsonFile -Path $script:InvalidJsonFile
                $result | Should -BeNullOrEmpty
            }
            
            It "Should not throw when SuppressErrors is specified" {
                { Read-JsonFile -Path $script:InvalidJsonFile -SuppressErrors } | Should -Not -Throw
            }
        }
        
        Context "Write-JsonFile" {
            It "Should write JSON file" {
                $outputFile = Join-Path -Path $script:TestDir -ChildPath "output.json"
                $testObject = [PSCustomObject]@{
                    Name = "WriteTest"
                    Value = 789
                }
                
                $result = Write-JsonFile -Path $outputFile -InputObject $testObject
                
                $result | Should -BeTrue
                Test-Path -Path $outputFile | Should -BeTrue
                
                # Проверяем содержимое файла
                $content = Get-Content -Path $outputFile -Raw | ConvertFrom-Json
                $content.Name | Should -Be "WriteTest"
                $content.Value | Should -Be 789
            }
            
            It "Should create directories if needed" {
                $nestedDir = Join-Path -Path $script:TestDir -ChildPath "nested\subfolder"
                $nestedFile = Join-Path -Path $nestedDir -ChildPath "nested.json"
                
                $result = Write-JsonFile -Path $nestedFile -InputObject @{ Name = "Nested" }
                
                $result | Should -BeTrue
                Test-Path -Path $nestedFile | Should -BeTrue
            }
            
            It "Should not overwrite existing file without -Force" {
                $result = Write-JsonFile -Path $script:TestJsonFile -InputObject @{ Name = "Overwrite" }
                $result | Should -BeFalse
                
                # Проверяем, что содержимое файла не изменилось
                $content = Get-Content -Path $script:TestJsonFile -Raw | ConvertFrom-Json
                $content.Name | Should -Be "Test"
            }
            
            It "Should overwrite existing file with -Force" {
                $result = Write-JsonFile -Path $script:TestJsonFile -InputObject @{ Name = "Overwrite" } -Force
                $result | Should -BeTrue
                
                # Проверяем, что содержимое файла изменилось
                $content = Get-Content -Path $script:TestJsonFile -Raw | ConvertFrom-Json
                $content.Name | Should -Be "Overwrite"
                
                # Восстанавливаем исходный JSON-файл для следующих тестов
                $script:TestJsonObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:TestJsonFile -Encoding utf8
            }
        }
        
        Context "ConvertFrom-JsonSafe" {
            It "Should parse valid JSON string" {
                $jsonString = '{"Name":"JsonString","Value":456}'
                $result = ConvertFrom-JsonSafe -Json $jsonString
                
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be "JsonString"
                $result.Value | Should -Be 456
            }
            
            It "Should return null for invalid JSON string" {
                $invalidJson = '{invalid:json}'
                $result = ConvertFrom-JsonSafe -Json $invalidJson
                $result | Should -BeNullOrEmpty
            }
            
            It "Should return default value for invalid JSON string" {
                $invalidJson = '{invalid:json}'
                $defaultValue = [PSCustomObject]@{ Name = "Default" }
                $result = ConvertFrom-JsonSafe -Json $invalidJson -DefaultValue $defaultValue
                $result.Name | Should -Be "Default"
            }
            
            It "Should return null for empty string" {
                $result = ConvertFrom-JsonSafe -Json ""
                $result | Should -BeNullOrEmpty
            }
            
            It "Should not throw when SuppressErrors is specified" {
                { ConvertFrom-JsonSafe -Json '{invalid:json}' -SuppressErrors } | Should -Not -Throw
            }
        }
        
        Context "Update-JsonFileProperty" {
            BeforeEach {
                # Восстанавливаем исходный JSON-файл перед каждым тестом
                $script:TestJsonObject | ConvertTo-Json -Depth 10 | Out-File -FilePath $script:TestJsonFile -Encoding utf8
            }
            
            It "Should update existing property" {
                $result = Update-JsonFileProperty -Path $script:TestJsonFile -Property "Value" -Value 999
                
                $result | Should -BeTrue
                
                # Проверяем, что свойство обновилось
                $content = Get-Content -Path $script:TestJsonFile -Raw | ConvertFrom-Json
                $content.Value | Should -Be 999
                $content.Name | Should -Be "Test" # Другие свойства не изменились
            }
            
            It "Should add new property" {
                $result = Update-JsonFileProperty -Path $script:TestJsonFile -Property "NewProperty" -Value "NewValue"
                
                $result | Should -BeTrue
                
                # Проверяем, что свойство добавилось
                $content = Get-Content -Path $script:TestJsonFile -Raw | ConvertFrom-Json
                $content.NewProperty | Should -Be "NewValue"
                $content.Name | Should -Be "Test" # Другие свойства не изменились
            }
            
            It "Should create new file with -Force" {
                $newFile = Join-Path -Path $script:TestDir -ChildPath "newfile.json"
                $result = Update-JsonFileProperty -Path $newFile -Property "InitialProperty" -Value "InitialValue" -Force
                
                $result | Should -BeTrue
                Test-Path -Path $newFile | Should -BeTrue
                
                # Проверяем содержимое созданного файла
                $content = Get-Content -Path $newFile -Raw | ConvertFrom-Json
                $content.InitialProperty | Should -Be "InitialValue"
            }
            
            It "Should return false for nonexistent file without -Force" {
                $nonExistentFile = Join-Path -Path $script:TestDir -ChildPath "nonexistent.json"
                $result = Update-JsonFileProperty -Path $nonExistentFile -Property "Test" -Value "Value"
                $result | Should -BeFalse
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
}