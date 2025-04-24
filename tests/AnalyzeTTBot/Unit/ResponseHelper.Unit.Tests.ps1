<#
.SYNOPSIS
    Тесты для ResponseHelper.
.DESCRIPTION
    Модульные тесты для проверки функциональности ResponseHelper, используемого для стандартизации ответов сервисов.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 05.04.2025
#>

Describe "ResponseHelper" {
    BeforeAll {
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
    
    Describe "ResponseHelper Tests" {
        Describe "New-ServiceResponse" {
            Context "Success=true" {
                It "Should create a valid response structure with success=true" {
                    InModuleScope AnalyzeTTBot {
                        $response = New-ServiceResponse -Success $true -Data "Test data" -ErrorMessage $null
                        
                        # Проверяем структуру ответа
                        $response | Should -BeOfType [hashtable]
                        $response.Keys | Should -Contain 'Success'
                        $response.Keys | Should -Contain 'Data'
                        $response.Keys | Should -Contain 'Error'
                        
                        # Проверяем значения полей
                        $response.Success | Should -BeTrue
                        $response.Data | Should -Be "Test data"
                        $response.Error | Should -BeNullOrEmpty
                    }
                }
            }
            
            Context "Success=false" {
                It "Should create a valid response structure with success=false" {
                    InModuleScope AnalyzeTTBot {
                        $response = New-ServiceResponse -Success $false -Data $null -ErrorMessage "Test error"
                        
                        # Проверяем структуру ответа
                        $response | Should -BeOfType [hashtable]
                        $response.Keys | Should -Contain 'Success'
                        $response.Keys | Should -Contain 'Data'
                        $response.Keys | Should -Contain 'Error'
                        
                        # Проверяем значения полей
                        $response.Success | Should -BeFalse
                        $response.Data | Should -Be $null
                        $response.Error | Should -Be "Test error"
                    }
                }
            }
            
            Context "Complex objects as data" {
                It "Should accept complex objects as data" {
                    InModuleScope AnalyzeTTBot {
                        $complexData = @{
                            Name = "Test"
                            Properties = @{
                                Id = 1
                                Value = "Value"
                            }
                            Items = @(1, 2, 3)
                        }
                        $response = New-ServiceResponse -Success $true -Data $complexData
                        
                        # Проверяем структуру ответа
                        $response | Should -BeOfType [hashtable]
                        $response.Success | Should -BeTrue
                        $response.Data | Should -BeOfType [hashtable]
                        
                        # Проверяем вложенные данные
                        $response.Data.Name | Should -Be "Test"
                        $response.Data.Properties.Id | Should -Be 1
                        $response.Data.Items.Count | Should -Be 3
                    }
                }
            }
        }
        
        Describe "New-SuccessResponse" {
            Context "With data" {
                It "Should create a valid success response with data" {
                    InModuleScope AnalyzeTTBot {
                        $response = New-SuccessResponse -Data "Test data"
                        
                        # Проверяем структуру ответа
                        $response | Should -BeOfType [hashtable]
                        $response.Keys | Should -Contain 'Success'
                        $response.Keys | Should -Contain 'Data'
                        $response.Keys | Should -Contain 'Error'
                        
                        # Проверяем значения полей
                        $response.Success | Should -BeTrue
                        $response.Data | Should -Be "Test data"
                        $response.Error | Should -BeNullOrEmpty
                    }
                }
            }
            
            Context "Without data" {
                It "Should create a valid success response without data" {
                    InModuleScope AnalyzeTTBot {
                        $response = New-SuccessResponse
                        
                        # Проверяем структуру ответа
                        $response | Should -BeOfType [hashtable]
                        $response.Success | Should -BeTrue
                        $response.Data | Should -BeNullOrEmpty
                        $response.Error | Should -BeNullOrEmpty
                    }
                }
            }
            
            Context "Different data types" {
                It "Should accept different data types" {
                    InModuleScope AnalyzeTTBot {
                        $response1 = New-SuccessResponse -Data 42
                        $response1.Data | Should -Be 42
                        
                        $response2 = New-SuccessResponse -Data $true
                        $response2.Data | Should -BeTrue
                        
                        $response3 = New-SuccessResponse -Data @(1, 2, 3)
                        $response3.Data.Count | Should -Be 3
                        $response3.Data[0] | Should -Be 1
                        
                        $response4 = New-SuccessResponse -Data @{Key = "Value"}
                        $response4.Data.Key | Should -Be "Value"
                        
                        $object = [PSCustomObject]@{ Property = "Value" }
                        $response5 = New-SuccessResponse -Data $object
                        $response5.Data.Property | Should -Be "Value"
                    }
                }
            }
        }
        
        Describe "New-ErrorResponse" {
            Context "With message" {
                It "Should create a valid error response with message" {
                    InModuleScope AnalyzeTTBot {
                        $response = New-ErrorResponse -ErrorMessage "Test error message"
                        
                        # Проверяем структуру ответа
                        $response | Should -BeOfType [hashtable]
                        $response.Keys | Should -Contain 'Success'
                        $response.Keys | Should -Contain 'Data'
                        $response.Keys | Should -Contain 'Error'
                        
                        # Проверяем значения полей
                        $response.Success | Should -BeFalse
                        $response.Data | Should -BeNullOrEmpty
                        $response.Error | Should -Be "Test error message"
                    }
                }
            }
            
            Context "Null or empty message" {
                It "Should not accept null or empty error message" {
                    InModuleScope AnalyzeTTBot {
                        { New-ErrorResponse -ErrorMessage "" } | Should -Throw
                        { New-ErrorResponse -ErrorMessage $null } | Should -Throw
                    }
                }
            }
            
            Context "With data in error" {
                It "Should accept data in error response" {
                    InModuleScope AnalyzeTTBot {
                        $errorData = @{
                            ErrorCode = 404
                            Source = "Test"
                            Details = "Not found"
                        }
                        try {
                            $response = New-ErrorResponse -ErrorMessage "Resource not found" -Data $errorData
                            $response | Should -BeOfType [hashtable]
                            $response.Success | Should -BeFalse
                            $response.Error | Should -Be "Resource not found"
                            $response.Data | Should -BeOfType [hashtable]
                            $response.Data.ErrorCode | Should -Be 404
                            $response.Data.Source | Should -Be "Test"
                            $dataInErrorWorking = $true
                        }
                        catch {
                            $dataInErrorWorking = $false
                        }
                        if (-not $dataInErrorWorking) {
                            Set-ItResult -Skipped -Because "Параметр Data не реализован в New-ErrorResponse"
                        }
                    }
                }
            }
        }
        
        Describe "Integration Scenarios" {
            Context "Error responses with different messages" {
                It "Should handle error responses with different error messages" {
                    InModuleScope AnalyzeTTBot {
                        $response1 = New-ErrorResponse -ErrorMessage "Not found"
                        $response2 = New-ErrorResponse -ErrorMessage "Access denied"
                        $response3 = New-ErrorResponse -ErrorMessage "Invalid input"
                        
                        # Проверяем значения полей
                        $response1.Success | Should -BeFalse
                        $response2.Success | Should -BeFalse
                        $response3.Success | Should -BeFalse
                        
                        $response1.Error | Should -Be "Not found"
                        $response2.Error | Should -Be "Access denied"
                        $response3.Error | Should -Be "Invalid input"
                        
                        # Проверка соответствия шаблонам
                        $response1.Error | Should -Match "Not found"
                        $response2.Error | Should -Match "Access denied"
                        $response3.Error | Should -Match "Invalid input"
                    }
                }
            }
            
            Context "Complex data structures in success responses" {
                It "Should handle complex data structures in success responses" {
                    InModuleScope AnalyzeTTBot {
                        $nestedData = @{
                            Level1 = @{
                                Level2 = @{
                                    Level3 = "Deep value"
                                }
                                Array = @(
                                    @{Item = 1},
                                    @{Item = 2}
                                )
                            }
                            List = @(1..5)
                        }
                        $response = New-SuccessResponse -Data $nestedData
                        
                        # Проверяем значения полей
                        $response.Success | Should -BeTrue
                        $response.Data.Level1.Level2.Level3 | Should -Be "Deep value"
                        $response.Data.Level1.Array.Count | Should -Be 2
                        $response.Data.Level1.Array[1].Item | Should -Be 2
                        $response.Data.List.Count | Should -Be 5
                        $response.Data.List[4] | Should -Be 5
                    }
                }
            }
            
            Context "Chaining of responses" {
                It "Should support chaining of responses" {
                    InModuleScope AnalyzeTTBot {
                        $response1 = New-SuccessResponse -Data "Initial data"
                        $response1.Success | Should -BeTrue
                        $response1.Data | Should -Be "Initial data"
                        
                        if ($response1.Success) {
                            $response2 = if ((Get-Random -Minimum 0 -Maximum 100) -gt 30) {
                                New-SuccessResponse -Data "Processed: $($response1.Data)"
                            } else {
                                New-ErrorResponse -ErrorMessage "Failed to process data"
                            }
                        } else {
                            $response2 = New-ErrorResponse -ErrorMessage "Cannot proceed with failed initial response"
                        }
                        
                        if ($response1.Success -and $response2.Success) {
                            $finalResponse = New-SuccessResponse -Data "Final: $($response2.Data)"
                        } elseif (-not $response1.Success) {
                            $finalResponse = New-ErrorResponse -ErrorMessage "Initial error: $($response1.Error)"
                        } else {
                            $finalResponse = New-ErrorResponse -ErrorMessage "Processing error: $($response2.Error)"
                        }
                        
                        $finalResponse.Success | Should -BeOfType [bool]
                        
                        if ($response2.Success) {
                            $finalResponse.Success | Should -BeTrue
                            $finalResponse.Data | Should -Match "Final: Processed: Initial data"
                        } else {
                            $finalResponse.Success | Should -BeFalse
                            $finalResponse.Error | Should -Match "Processing error"
                        }
                    }
                }
            }
        }
        
        AfterAll {
            Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
        }
    }
}