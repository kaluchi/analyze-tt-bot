#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#
.SYNOPSIS
    Тесты для модуля LoggingHelper.
.DESCRIPTION
    Модульные тесты для проверки функциональности LoggingHelper.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
#>

Describe "LoggingHelper" {
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
        
        # Импортируем вспомогательный модуль, если он существует
        $helperPath = Join-Path $PSScriptRoot "..\Helpers\TestResponseHelper.psm1"
        if (Test-Path $helperPath) {
            Import-Module -Name $helperPath -Force -ErrorAction SilentlyContinue
        }
    }

    Describe "Write-OperationStart" {
        Context "Basic functionality" {
            It "Should log operation start without error" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова
                    Mock Write-PSFMessage {}
                    
                    # Выполняем функцию
                    { Write-OperationStart -Operation "Test operation" } | Should -Not -Throw
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
            
            It "Should include target in message when specified" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова с правильным сообщением
                    Mock Write-PSFMessage {
                        $Message | Should -Match "Test operation.*on.*Test target"
                    }
                    
                    # Выполняем функцию
                    Write-OperationStart -Operation "Test operation" -Target "Test target"
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
            
            It "Should use specified function name" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова с правильной функцией
                    Mock Write-PSFMessage {
                        $FunctionName | Should -Be "CustomFunction"
                    }
                    
                    # Выполняем функцию
                    Write-OperationStart -Operation "Test operation" -FunctionName "CustomFunction"
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
        }
    }
    
    Describe "Write-OperationSucceeded" {
        Context "Basic functionality" {
            It "Should log operation success without error" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова
                    Mock Write-PSFMessage {}
                    
                    # Выполняем функцию
                    { Write-OperationSucceeded -Operation "Test operation" } | Should -Not -Throw
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
            
            It "Should include details in message when specified" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова с правильным сообщением
                    Mock Write-PSFMessage {
                        $Message | Should -Match "Test operation.*Test details"
                    }
                    
                    # Выполняем функцию
                    Write-OperationSucceeded -Operation "Test operation" -Details "Test details"
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
        }
    }
    
    Describe "Write-OperationFailed" {
        Context "Basic functionality" {
            It "Should log operation failure without error" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова
                    Mock Write-PSFMessage {}
                    
                    # Выполняем функцию
                    { Write-OperationFailed -Operation "Test operation" } | Should -Not -Throw
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
            
            It "Should include error message when specified" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова с правильным сообщением
                    Mock Write-PSFMessage {
                        $Message | Should -Match "Test operation.*Test error"
                    }
                    
                    # Выполняем функцию
                    Write-OperationFailed -Operation "Test operation" -ErrorMessage "Test error"
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
            
            It "Should pass ErrorRecord when specified" {
                InModuleScope AnalyzeTTBot {
                    # Создаем тестовый ErrorRecord
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Test exception"),
                        "TestErrorId",
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        $null
                    )
                    
                    # Мокаем Write-PSFMessage для проверки вызова с ErrorRecord
                    Mock Write-PSFMessage {}
                    
                    # Выполняем функцию
                    Write-OperationFailed -Operation "Test operation" -ErrorRecord $errorRecord
                    
                    # Проверяем, что Write-PSFMessage был вызван с правильными параметрами
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter {
                        $null -ne $ErrorRecord
                    }
                }
            }
        }
    }
    
    Describe "Get-SanitizedLogMessage" {
        Context "Sanitation rules" {
            It "Should sanitize Telegram token" {
                InModuleScope AnalyzeTTBot {
                    $message = "Using token: 1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"
                    $result = Get-SanitizedLogMessage -Message $message
                    $result | Should -Not -Match "1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                    $result | Should -Match "\[TELEGRAM_TOKEN\]"
                }
            }
            
            It "Should sanitize API keys" {
                InModuleScope AnalyzeTTBot {
                    $message = "API Key: abcdef1234567890 and apikey=secretvalue123"
                    $result = Get-SanitizedLogMessage -Message $message
                    $result | Should -Not -Match "abcdef1234567890"
                    $result | Should -Not -Match "secretvalue123"
                    $result | Should -Match "\[REDACTED\]"
                }
            }
            
            It "Should sanitize credentials in URLs" {
                InModuleScope AnalyzeTTBot {
                    $message = "URL: https://username:password@example.com"
                    $result = Get-SanitizedLogMessage -Message $message
                    $result | Should -Not -Match "username:password"
                    $result | Should -Match "\[USER\]:\[PASSWORD\]"
                }
            }
            
            It "Should not modify messages without sensitive data" {
                InModuleScope AnalyzeTTBot {
                    $message = "This is a normal message with no sensitive data"
                    $result = Get-SanitizedLogMessage -Message $message
                    $result | Should -Be $message
                }
            }
        }
    }
    
    Describe "Write-PSFMessageSafe" {
        Context "Message sanitation" {
            It "Should sanitize message before logging" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем основную функцию Write-PSFMessage
                    Mock Write-PSFMessage {
                        # Проверяем, что сообщение прошло санитизацию
                        $Message | Should -Not -Match "1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                        $Message | Should -Match "\[TELEGRAM_TOKEN\]"
                    }
                    
                    # Выполняем функцию
                    Write-PSFMessageSafe -Level Verbose -Message "Token: 1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn"
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
        }
        
        Context "Parameters passing" {
            It "Should pass ErrorRecord when specified" {
                InModuleScope AnalyzeTTBot {
                    # Создаем тестовый ErrorRecord
                    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Test exception"),
                        "TestErrorId",
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        $null
                    )
                    
                    # Мокаем Write-PSFMessage для проверки вызова с ErrorRecord
                    Mock Write-PSFMessage {}
                    
                    # Выполняем функцию
                    Write-PSFMessageSafe -Level Warning -Message "Test message" -ErrorRecord $errorRecord
                    
                    # Проверяем, что Write-PSFMessage был вызван с правильными параметрами
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly -ParameterFilter {
                        $null -ne $ErrorRecord
                    }
                }
            }
            
            It "Should use specified function name" {
                InModuleScope AnalyzeTTBot {
                    # Мокаем Write-PSFMessage для проверки вызова с правильной функцией
                    Mock Write-PSFMessage {
                        $FunctionName | Should -Be "CustomFunction"
                    }
                    
                    # Выполняем функцию
                    Write-PSFMessageSafe -Level Verbose -Message "Test message" -FunctionName "CustomFunction"
                    
                    # Проверяем, что Write-PSFMessage был вызван
                    Should -Invoke Write-PSFMessage -Times 1 -Exactly
                }
            }
        }
    }

    AfterAll {
        # Удаляем вспомогательные модули
        if (Get-Module -Name TestResponseHelper) {
            Remove-Module -Name TestResponseHelper -Force -ErrorAction SilentlyContinue
        }

        # Удаляем основной модуль после выполнения тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}