#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода HandleException в BotService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода HandleException сервиса BotService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'BotService.HandleException method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Должен логировать исключение с уровнем Error' {
        InModuleScope AnalyzeTTBot {
            # Mock Write-PSFMessage чтобы отслеживать вызовы логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            # Создаем экземпляр BotService с null зависимостями, так как они не нужны для этого теста
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Создаем тестовое исключение
            $testException = [System.Exception]::new("Тестовое исключение")
            $functionName = "TestFunction"
            
            # Вызываем тестируемый метод
            $botService.HandleException($testException, $functionName)
            
            # Проверяем, что Write-PSFMessage был вызван с правильными параметрами
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and 
                $FunctionName -eq $functionName -and
                $Message -eq "Error: $($testException.Message)" -and
                $Exception -eq $testException
            }
        }
    }
    
    It 'Должен корректно обрабатывать вложенные исключения' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Создаем вложенное исключение
            $innerException = [System.Exception]::new("Внутреннее исключение")
            $outerException = [System.Exception]::new("Внешнее исключение", $innerException)
            $functionName = "TestFunctionWithNested"
            
            $botService.HandleException($outerException, $functionName)
            
            # Проверяем, что Write-PSFMessage был вызван с внешним исключением
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and 
                $FunctionName -eq $functionName -and
                $Message -eq "Error: $($outerException.Message)" -and
                $Exception -eq $outerException
            }
        }
    }
    
    It 'Должен корректно обрабатывать пустое имя функции' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            $testException = [System.Exception]::new("Исключение без имени функции")
            $emptyFunctionName = ""
            
            $botService.HandleException($testException, $emptyFunctionName)
            
            # Проверяем, что Write-PSFMessage был вызван с пустым именем функции
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and 
                $FunctionName -eq $emptyFunctionName -and
                $Message -eq "Error: $($testException.Message)" -and
                $Exception -eq $testException
            }
        }
    }
    
    It 'Должен корректно обрабатывать специфичные типы исключений' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Создаем специфичный тип исключения
            $nullReferenceException = [System.NullReferenceException]::new("Ссылка на объект не установлена")
            $functionName = "TestNullReference"
            
            $botService.HandleException($nullReferenceException, $functionName)
            
            # Проверяем, что Write-PSFMessage был вызван со специфичным типом исключения
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and 
                $FunctionName -eq $functionName -and
                $Message -eq "Error: $($nullReferenceException.Message)" -and
                $Exception -eq $nullReferenceException -and
                $Exception -is [System.NullReferenceException]
            }
        }
    }
    
    It 'Должен корректно обрабатывать $null имя функции' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            $testException = [System.Exception]::new("Исключение с null именем функции")
            $nullFunctionName = $null
            
            $botService.HandleException($testException, $nullFunctionName)
            
            # Проверяем, что Write-PSFMessage был вызван с учетом того, что в случае null значение может быть преобразовано в пустую строку
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and 
                ($FunctionName -eq $nullFunctionName -or [string]::IsNullOrEmpty($FunctionName)) -and
                $Message -eq "Error: $($testException.Message)" -and
                $Exception -eq $testException
            }
        }
    }
    
    It 'Должен сохранять детали исключения для последующего анализа' {
        InModuleScope AnalyzeTTBot {
            # Переменная для хранения параметров вызова
            $script:capturedParams = $null
            
            Mock Write-PSFMessage { 
                param($Level, $FunctionName, $Message, $Exception)
                $script:capturedParams = @{
                    Level = $Level
                    FunctionName = $FunctionName
                    Message = $Message
                    Exception = $Exception
                }
            } -ModuleName AnalyzeTTBot
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Создаем исключение с дополнительными свойствами
            $complexException = [System.Exception]::new("Сложное исключение")
            $complexException.Data.Add("ErrorCode", 500)
            $complexException.Data.Add("Context", "ProcessingTikTokURL")
            $functionName = "ComplexErrorFunction"
            
            $botService.HandleException($complexException, $functionName)
            
            # Проверяем, что все детали исключения были сохранены в параметрах
            $script:capturedParams | Should -Not -BeNullOrEmpty
            $script:capturedParams.Exception | Should -Be $complexException
            $script:capturedParams.Exception.Data["ErrorCode"] | Should -Be 500
            $script:capturedParams.Exception.Data["Context"] | Should -Be "ProcessingTikTokURL"
        }
    }
    
    It 'Должен обрабатывать исключения с длинными сообщениями' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Создаем исключение с очень длинным сообщением
            $longMessage = "Это очень длинное сообщение об ошибке" + " " * 1000 + "которое может вызвать проблемы при логировании"
            $longException = [System.Exception]::new($longMessage)
            $functionName = "LongMessageFunction"
            
            $botService.HandleException($longException, $functionName)
            
            # Проверяем, что Write-PSFMessage был вызван с длинным сообщением
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -Times 1 -ParameterFilter {
                $Level -eq 'Error' -and 
                $FunctionName -eq $functionName -and
                $Message -eq "Error: $($longException.Message)" -and
                $Exception -eq $longException
            }
        }
    }
}
