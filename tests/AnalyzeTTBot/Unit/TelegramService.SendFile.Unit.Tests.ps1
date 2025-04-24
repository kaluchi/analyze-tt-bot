#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода SendFile в TelegramService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода SendFile сервиса TelegramService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

#region TelegramService.SendFile.Unit.Tests

Describe 'TelegramService.SendFile method' {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        # Очищаем все модули и переменные, чтобы не было конфликтов между тестами
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Возвращает ошибку, если файл не найден' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Test-Path для возврата false (файл не существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $false }
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'несуществующий_файл.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'File not found'
            $result.Data.reason | Should -Be 'file_not_found'
        }
    }

    It 'Возвращает ошибку, если файл слишком большой' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис с ограничением 10 МБ
            $service = [TelegramService]::new('VALID_TOKEN', 10)
            
            # Мокаем Test-Path для возврата true (файл существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Мокаем Get-Item для возврата объекта с размером больше лимита (20MB)
            $mockFileInfo = New-Object -TypeName PSObject
            $mockFileInfo | Add-Member -MemberType NoteProperty -Name Length -Value (20 * 1024 * 1024)
            Mock -CommandName Get-Item -ModuleName AnalyzeTTBot -MockWith { return $mockFileInfo }
            
            # Подготавливаем мок для метода SendMessage
            $service | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { 
                param([long]$chatId, [string]$text, [int]$replyToMessageId, [string]$parseMode)
                return New-SuccessResponse -Data @{
                    result = @{
                        message_id = 1000
                    }
                }
            } -Force
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'большой_файл.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'File is too large'
            $result.Data.reason | Should -Be 'file_too_large'
            $result.Data.file_size | Should -Be 20
        }
    }

    It 'Успешно отправляет файл с использованием нативного метода PowerShell 7' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Test-Path для возврата true (файл существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Мокаем Get-Item для возврата объекта с допустимым размером (5MB)
            $mockFileInfo = New-Object -TypeName PSObject
            $mockFileInfo | Add-Member -MemberType NoteProperty -Name Length -Value (5 * 1024 * 1024)
            Mock -CommandName Get-Item -ModuleName AnalyzeTTBot -MockWith { return $mockFileInfo }
            
            # Мокаем Invoke-RestMethod для имитации успешной отправки файла
            $mockResponse = @{
                ok = $true
                result = @{
                    message_id = 100
                    document = @{
                        file_id = "ABC123"
                        file_name = "test.txt"
                    }
                }
            }
            Mock -CommandName Invoke-RestMethod -ModuleName AnalyzeTTBot -MockWith { return $mockResponse }
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'test.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.message_id | Should -Be 100
            $result.Data.document.file_id | Should -Be "ABC123"
        }
    }

    It 'Успешно отправляет файл с использованием резервного метода curl' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Test-Path для возврата true (файл существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Мокаем Get-Item для возврата объекта с допустимым размером (5MB)
            $mockFileInfo = New-Object -TypeName PSObject
            $mockFileInfo | Add-Member -MemberType NoteProperty -Name Length -Value (5 * 1024 * 1024)
            Mock -CommandName Get-Item -ModuleName AnalyzeTTBot -MockWith { return $mockFileInfo }
            
            # Мокаем Invoke-RestMethod для имитации неудачи (чтобы код перешел к curl)
            Mock -CommandName Invoke-RestMethod -ModuleName AnalyzeTTBot -MockWith { throw "Невозможно отправить файл" }
            
            # Мокаем Invoke-ExternalProcess (для curl) для имитации успешной отправки
            $mockCurlOutput = '{"ok":true,"result":{"message_id":101,"document":{"file_id":"DEF456","file_name":"test.txt"}}}'
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = $mockCurlOutput
                    Error = ""
                }
            }
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'test.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.message_id | Should -Be 101
            $result.Data.document.file_id | Should -Be "DEF456"
        }
    }

    It 'Возвращает ошибку при проблеме с curl' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Test-Path для возврата true (файл существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Мокаем Get-Item для возврата объекта с допустимым размером (5MB)
            $mockFileInfo = New-Object -TypeName PSObject
            $mockFileInfo | Add-Member -MemberType NoteProperty -Name Length -Value (5 * 1024 * 1024)
            Mock -CommandName Get-Item -ModuleName AnalyzeTTBot -MockWith { return $mockFileInfo }
            
            # Мокаем Invoke-RestMethod для имитации неудачи (чтобы код перешел к curl)
            Mock -CommandName Invoke-RestMethod -ModuleName AnalyzeTTBot -MockWith { throw "Невозможно отправить файл" }
            
            # Мокаем Invoke-ExternalProcess (для curl) для имитации ошибки curl
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $false
                    ExitCode = 1
                    Output = ""
                    Error = "curl: command not found"
                }
            }
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'test.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "curl error"
            $result.Data.reason | Should -Be "curl_error"
        }
    }

    It 'Обрабатывает ошибку "Request Entity Too Large" при использовании curl' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Test-Path для возврата true (файл существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Мокаем Get-Item для возврата объекта с допустимым размером (5MB)
            $mockFileInfo = New-Object -TypeName PSObject
            $mockFileInfo | Add-Member -MemberType NoteProperty -Name Length -Value (5 * 1024 * 1024)
            Mock -CommandName Get-Item -ModuleName AnalyzeTTBot -MockWith { return $mockFileInfo }
            
            # Мокаем Invoke-RestMethod для имитации неудачи (чтобы код перешел к curl)
            Mock -CommandName Invoke-RestMethod -ModuleName AnalyzeTTBot -MockWith { throw "Невозможно отправить файл" }
            
            # Мокаем Invoke-ExternalProcess (для curl) для имитации ошибки "Request Entity Too Large"
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                return @{
                    Success = $true
                    ExitCode = 0
                    Output = 'Request Entity Too Large'
                    Error = ""
                }
            }
            
            # Подготавливаем мок для метода SendMessage
            $service | Add-Member -MemberType ScriptMethod -Name SendMessage -Value { 
                param([long]$chatId, [string]$text, [int]$replyToMessageId, [string]$parseMode)
                return New-SuccessResponse -Data @{
                    result = @{
                        message_id = 1000
                    }
                }
            } -Force
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'test.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Request Entity Too Large"
            $result.Data.reason | Should -Be "request_entity_too_large"
        }
    }

    It 'Обрабатывает исключение при вызове curl' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Test-Path для возврата true (файл существует)
            Mock -CommandName Test-Path -ModuleName AnalyzeTTBot -MockWith { return $true }
            
            # Мокаем Get-Item для возврата объекта с допустимым размером (5MB)
            $mockFileInfo = New-Object -TypeName PSObject
            $mockFileInfo | Add-Member -MemberType NoteProperty -Name Length -Value (5 * 1024 * 1024)
            Mock -CommandName Get-Item -ModuleName AnalyzeTTBot -MockWith { return $mockFileInfo }
            
            # Мокаем Invoke-RestMethod для имитации неудачи (чтобы код перешел к curl)
            Mock -CommandName Invoke-RestMethod -ModuleName AnalyzeTTBot -MockWith { throw "Невозможно отправить файл" }
            
            # Мокаем Invoke-ExternalProcess для имитации исключения
            Mock -CommandName Invoke-ExternalProcess -ModuleName AnalyzeTTBot -MockWith {
                throw "curl not available on this system"
            }
            
            # Вызываем тестируемый метод
            $result = $service.SendFile(12345, 'test.txt', 'тестовый текст', $null)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match "Failed to send file with curl"
            $result.Data.reason | Should -Be "curl_error"
        }
    }
}
#endregion