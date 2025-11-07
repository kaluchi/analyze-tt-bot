#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для метода GetUpdates в TelegramService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода GetUpdates сервиса TelegramService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

#region TelegramService.GetUpdates.Unit.Tests

Describe 'TelegramService.GetUpdates method' {
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

    It 'Возвращает успешный ответ с пустым массивом при отсутствии обновлений' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Invoke-CurlMethod для имитации ответа без обновлений
            $mockResponse = @{ ok = $true; result = @() }
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { $mockResponse }
            
            # Вызываем тестируемый метод
            $result = $service.GetUpdates(0, 30)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            # Проверяем данные (может быть null или пустой массив)
            if ($null -ne $result.Data) {
                $result.Data.Count | Should -Be 0
            }
        }
    }

    It 'Возвращает успешный ответ с обновлениями, когда они доступны' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Invoke-CurlMethod для имитации ответа с обновлениями
            $mockUpdates = @(
                @{
                    update_id = 123456789
                    message = @{
                        message_id = 100
                        from = @{ id = 12345; first_name = 'Test'; username = 'testuser' }
                        chat = @{ id = 12345; type = 'private' }
                        date = 1716325814
                        text = 'Тестовое сообщение'
                    }
                },
                @{
                    update_id = 123456790
                    message = @{
                        message_id = 101
                        from = @{ id = 12345; first_name = 'Test'; username = 'testuser' }
                        chat = @{ id = 12345; type = 'private' }
                        date = 1716325820
                        text = 'Другое сообщение'
                    }
                }
            )
            
            $mockResponse = @{ ok = $true; result = $mockUpdates }
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { $mockResponse }
            
            # Вызываем тестируемый метод
            $result = $service.GetUpdates(0, 30)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            # Проверяем, что $result.Data содержит элементы
            $result.Data.Count | Should -Be 2
            # Проверяем значения элементов массива
            $result.Data[0].update_id | Should -Be 123456789
            $result.Data[0].message.text | Should -Be 'Тестовое сообщение'
            $result.Data[1].update_id | Should -Be 123456790
            $result.Data[1].message.text | Should -Be 'Другое сообщение'
        }
    }

    It 'Корректно обрабатывает параметры offset и timeout' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Создаем мок с проверкой параметров
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith {
                # Проверяем, что URL содержит правильные параметры
                $uri | Should -Match "offset=12345"
                $uri | Should -Match "timeout=60"
                return @{ ok = $true; result = @() }
            }

            # Вызываем тестируемый метод с конкретными значениями
            $result = $service.GetUpdates(12345, 60)

            # Проверяем, что мок был вызван
            Should -Invoke Invoke-CurlMethod -Times 1 -Exactly -ModuleName AnalyzeTTBot
            
            # Проверяем базовый результат
            $result.Success | Should -BeTrue
        }
    }

    It 'Возвращает ошибку, если Telegram API вернул не OK' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Invoke-CurlMethod для имитации ошибочного ответа от API
            $mockResponse = @{ ok = $false; description = 'Unauthorized' }
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { $mockResponse }
            
            # Вызываем тестируемый метод
            $result = $service.GetUpdates(0, 30)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Error getting updates: Unauthorized'
        }
    }

    It 'Возвращает ошибку при исключении во время вызова API' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('INVALID_TOKEN', 50)
            
            # Мокаем Invoke-CurlMethod для имитации исключения
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { throw 'Network error' }
            
            # Вызываем тестируемый метод
            $result = $service.GetUpdates(0, 30)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Error getting updates: Network error'
        }
    }

    It 'Обрабатывает случай, когда result равен null' {
        InModuleScope AnalyzeTTBot {
            # Создаем сервис
            $service = [TelegramService]::new('VALID_TOKEN', 50)
            
            # Мокаем Invoke-CurlMethod для имитации ответа с null result
            $mockResponse = @{ ok = $true; result = $null }
            Mock -CommandName Invoke-CurlMethod -ModuleName AnalyzeTTBot -MockWith { $mockResponse }
            
            # Вызываем тестируемый метод
            $result = $service.GetUpdates(0, 30)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            # Проверяем данные (может быть null или пустой массив)
            if ($null -ne $result.Data) {
                $result.Data.Count | Should -Be 0
            }
        }
    }
}
#endregion