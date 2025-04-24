<#
.SYNOPSIS
    Тесты для ProcessHelper.
.DESCRIPTION
    Модульные тесты для проверки функциональности ProcessHelper, используемого для запуска и управления внешними процессами.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 05.04.2025
#>

Describe "ProcessHelper" {
    BeforeAll {
        # Эта строка необходима для корректной работы PSFramework
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        
        # Определяем пути к модулю
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..") 
        $modulePath = Join-Path -Path $projectRoot -ChildPath "src\AnalyzeTTBot"
        $manifestPath = Join-Path -Path $modulePath -ChildPath "AnalyzeTTBot.psd1"
        
        # Проверяем наличие модуля и импортируем его
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        
        # Проверяем успешность импорта модуля
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        
        # Проверяем наличие PSFramework
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
    }
    
    Context "Invoke-ExternalProcess Tests" {
        It "Should return a result object with correct structure" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок-объект процесса
                $mockProcess = New-Object -TypeName PSObject
                $mockProcess | Add-Member -MemberType NoteProperty -Name Id -Value 123
                $mockProcess | Add-Member -MemberType NoteProperty -Name HasExited -Value $true
                $mockProcess | Add-Member -MemberType NoteProperty -Name ExitCode -Value 0
                $mockProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($timeout) return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Start -Value { return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value { } -Force
                $mockProcess | Add-Member -MemberType NoteProperty -Name StartInfo -Value (New-Object System.Diagnostics.ProcessStartInfo)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardOutput -Value (New-Object -TypeName PSObject)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardError -Value (New-Object -TypeName PSObject)
                $mockProcess.StandardOutput | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "Test Output" } -Force
                $mockProcess.StandardError | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "" } -Force
                
                # Настраиваем мок для New-Object
                Mock New-Object {
                    if ($TypeName -eq "System.Diagnostics.Process") {
                        return $mockProcess
                    }
                    else {
                        return (New-Object -TypeName $TypeName)
                    }
                } -ParameterFilter { $TypeName -eq "System.Diagnostics.Process" }
                
                # Тестируем функцию
                $result = Invoke-ExternalProcess -ExecutablePath "cmd.exe" -ArgumentList @("/c", "echo", "test")
                
                # Проверяем результат
                $result | Should -BeOfType [hashtable]
                $result.Keys | Should -Contain "Success"
                $result.Keys | Should -Contain "ExitCode"
                $result.Keys | Should -Contain "Output" 
                $result.Keys | Should -Contain "Error"
                $result.Keys | Should -Contain "TimedOut"
                $result.Keys | Should -Contain "Command"
            }
        }
        
        It "Should handle successful process execution" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок-объект процесса с успешным завершением
                $mockProcess = New-Object -TypeName PSObject
                $mockProcess | Add-Member -MemberType NoteProperty -Name Id -Value 123
                $mockProcess | Add-Member -MemberType NoteProperty -Name HasExited -Value $true
                $mockProcess | Add-Member -MemberType NoteProperty -Name ExitCode -Value 0
                $mockProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($timeout) return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Start -Value { return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value { } -Force
                $mockProcess | Add-Member -MemberType NoteProperty -Name StartInfo -Value (New-Object System.Diagnostics.ProcessStartInfo)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardOutput -Value (New-Object -TypeName PSObject)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardError -Value (New-Object -TypeName PSObject)
                $mockProcess.StandardOutput | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "Test Output" } -Force
                $mockProcess.StandardError | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "" } -Force
                
                # Настраиваем мок для New-Object
                Mock New-Object {
                    if ($TypeName -eq "System.Diagnostics.Process") {
                        return $mockProcess
                    }
                    else {
                        return (New-Object -TypeName $TypeName)
                    }
                } -ParameterFilter { $TypeName -eq "System.Diagnostics.Process" }
                
                # Тестируем функцию
                $result = Invoke-ExternalProcess -ExecutablePath "cmd.exe" -ArgumentList @("/c", "echo", "test")
                
                # Проверяем результат успешного выполнения
                $result.Success | Should -BeTrue
                $result.ExitCode | Should -Be 0
                $result.Output | Should -Be "Test Output"
                $result.Error | Should -BeNullOrEmpty
                $result.TimedOut | Should -BeFalse
            }
        }
        
        It "Should handle process with non-zero exit code" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок-объект процесса с ошибкой
                $mockProcess = New-Object -TypeName PSObject
                $mockProcess | Add-Member -MemberType NoteProperty -Name Id -Value 123
                $mockProcess | Add-Member -MemberType NoteProperty -Name HasExited -Value $true
                $mockProcess | Add-Member -MemberType NoteProperty -Name ExitCode -Value 1
                $mockProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($timeout) return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Start -Value { return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value { } -Force
                $mockProcess | Add-Member -MemberType NoteProperty -Name StartInfo -Value (New-Object System.Diagnostics.ProcessStartInfo)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardOutput -Value (New-Object -TypeName PSObject)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardError -Value (New-Object -TypeName PSObject)
                $mockProcess.StandardOutput | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "" } -Force
                $mockProcess.StandardError | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "Error Message" } -Force
                
                # Настраиваем мок для New-Object
                Mock New-Object {
                    if ($TypeName -eq "System.Diagnostics.Process") {
                        return $mockProcess
                    }
                    else {
                        return (New-Object -TypeName $TypeName)
                    }
                } -ParameterFilter { $TypeName -eq "System.Diagnostics.Process" }
                
                # Тестируем функцию
                $result = Invoke-ExternalProcess -ExecutablePath "cmd.exe" -ArgumentList @("/c", "invalid-command")
                
                # Проверяем результат неуспешного выполнения
                $result.Success | Should -BeFalse
                $result.ExitCode | Should -Be 1
                $result.Error | Should -Be "Error Message"
            }
        }
        
        It "Should handle timeout correctly" {
            InModuleScope AnalyzeTTBot {
                # Создаем мок-объект процесса, который не завершается вовремя
                $mockProcess = New-Object -TypeName PSObject
                $mockProcess | Add-Member -MemberType NoteProperty -Name Id -Value 123
                $mockProcess | Add-Member -MemberType NoteProperty -Name HasExited -Value $false
                $mockProcess | Add-Member -MemberType NoteProperty -Name ExitCode -Value $null
                # Метод WaitForExit возвращает false, что означает таймаут
                $mockProcess | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value { param($timeout) return $false } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Start -Value { return $true } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value { } -Force
                $mockProcess | Add-Member -MemberType ScriptMethod -Name Kill -Value { } -Force
                $mockProcess | Add-Member -MemberType NoteProperty -Name StartInfo -Value (New-Object System.Diagnostics.ProcessStartInfo)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardOutput -Value (New-Object -TypeName PSObject)
                $mockProcess | Add-Member -MemberType NoteProperty -Name StandardError -Value (New-Object -TypeName PSObject)
                $mockProcess.StandardOutput | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "Partial Output" } -Force
                $mockProcess.StandardError | Add-Member -MemberType ScriptMethod -Name ReadToEnd -Value { return "" } -Force
                
                # Настраиваем мок для New-Object
                Mock New-Object {
                    if ($TypeName -eq "System.Diagnostics.Process") {
                        return $mockProcess
                    }
                    else {
                        return (New-Object -TypeName $TypeName)
                    }
                } -ParameterFilter { $TypeName -eq "System.Diagnostics.Process" }
                
                # Тестируем функцию с таймаутом
                $result = Invoke-ExternalProcess -ExecutablePath "cmd.exe" -ArgumentList @("/c", "timeout", "30") -TimeoutSeconds 1
                
                # Проверяем результат при таймауте
                $result.Success | Should -BeFalse
                $result.TimedOut | Should -BeTrue
                $result.Output | Should -Be "Partial Output"
                $result.Error | Should -Match "timed out"
            }
        }
        
        It "Should handle exceptions when starting process" {
            InModuleScope AnalyzeTTBot {
                # Настраиваем мок для New-Object, который выбрасывает исключение
                Mock New-Object { 
                    if ($TypeName -eq "System.Diagnostics.Process") {
                        $mockProcess = New-Object -TypeName PSObject
                        $mockProcess | Add-Member -MemberType NoteProperty -Name StartInfo -Value (New-Object System.Diagnostics.ProcessStartInfo)
                        $mockProcess | Add-Member -MemberType ScriptMethod -Name Start -Value { throw "Process not found" } -Force
                        $mockProcess | Add-Member -MemberType ScriptMethod -Name Dispose -Value { } -Force
                        return $mockProcess
                    }
                    else {
                        return (New-Object -TypeName $TypeName)
                    }
                } -ParameterFilter { $TypeName -eq "System.Diagnostics.Process" }
                
                # Тестируем функцию с исключением
                $result = Invoke-ExternalProcess -ExecutablePath "non-existent.exe" -ArgumentList @()
                
                # Проверяем результат при исключении
                $result.Success | Should -BeFalse
                $result.ExitCode | Should -Be -1
                $result.Error | Should -Match "Process not found"
                $result.Exception | Should -Not -BeNullOrEmpty
            }
        }
    }
    
    Context "Test-CommandExists Tests" {
        It "Should always return true (stubbed function)" {
            InModuleScope AnalyzeTTBot {
                # Проверяем заглушку для Test-CommandExists
                $result = Test-CommandExists -Command "any-command"
                $result | Should -BeTrue
                
                $result = Test-CommandExists -Command "non-existent-command"
                $result | Should -BeTrue
                
                $result = Test-CommandExists -Command "cmd.exe" -TestRun
                $result | Should -BeTrue
            }
        }
    }
    
    AfterAll {
        # Очистка после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}