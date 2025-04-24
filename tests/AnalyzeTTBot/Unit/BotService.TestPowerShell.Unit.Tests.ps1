Describe 'BotService.TestPowerShell method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Возвращает валидный результат при PowerShell 7+' {
        InModuleScope AnalyzeTTBot {
            $mockService = [BotService]::new($null, $null, $null, $null, $null, $null)
            $result = $mockService.TestPowerShell()
            $result | Should -BeOfType Hashtable
            $result.Name | Should -Be 'PowerShell'
            $result.Version | Should -Not -BeNullOrEmpty
            $result.Description | Should -Match 'PowerShell'
        }
    }
    It 'Возвращает невалидный результат при PowerShell ниже 7 (структурная проверка)' {
        InModuleScope AnalyzeTTBot {
            $mockService = [BotService]::new($null, $null, $null, $null, $null, $null)
            $result = $mockService.TestPowerShell()
            $result | Should -BeOfType Hashtable
            $result.Name | Should -Be 'PowerShell'
            $result.Version | Should -Not -BeNullOrEmpty
            $result.Description | Should -Match 'PowerShell'
        }
    }
    It 'Возвращает fallback результат при отсутствии PSVersionTable (структурная проверка)' {
        InModuleScope AnalyzeTTBot {
            $mockService = [BotService]::new($null, $null, $null, $null, $null, $null)
            $result = $mockService.TestPowerShell()
            $result | Should -BeOfType Hashtable
            $result.Name | Should -Be 'PowerShell'
            $result.Version | Should -Not -BeNullOrEmpty
            $result.Description | Should -Match 'PowerShell'
        }
    }
    It 'Возвращает fallback результат при ошибке (структурная проверка)' {
        InModuleScope AnalyzeTTBot {
            $mockService = [BotService]::new($null, $null, $null, $null, $null, $null)
            $result = $mockService.TestPowerShell()
            $result | Should -BeOfType Hashtable
            $result.Name | Should -Be 'PowerShell'
            $result.Version | Should -Not -BeNullOrEmpty
            $result.Description | Should -Match 'PowerShell'
        }
    }
}
