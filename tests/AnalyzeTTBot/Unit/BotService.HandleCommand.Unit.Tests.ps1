Describe 'BotService.HandleCommand method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Отправляет welcomeMessage при /start' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Get-PSFConfigValue { 'Добро пожаловать!' } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $true }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService, $null, $null, $null, $null, $null
            )
            $botService.HandleCommand('/start', 1, 2)
        }
    }
    It 'Отправляет helpMessage при /help' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot
            Mock Get-PSFConfigValue { 'Помощь!' } -ModuleName AnalyzeTTBot
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $true }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService, $null, $null, $null, $null, $null
            )
            $botService.HandleCommand('/help', 1, 2)
        }
    }
    It 'Логирует предупреждение при неизвестной команде' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { 
                $script:lastPSFMessage = @{ Level = $Level; Message = $Message }
            } -ModuleName AnalyzeTTBot -Verifiable
            $script:lastPSFMessage = $null
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $true }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService, $null, $null, $null, $null, $null
            )
            $botService.HandleCommand('/unknown', 1, 2)
            $script:lastPSFMessage.Level | Should -Match 'Warn'
            $script:lastPSFMessage.Message | Should -Match '/unknown'
        }
    }
    It 'Логирует ошибку при неудачной отправке сообщения' {
        InModuleScope AnalyzeTTBot {
            Mock Write-PSFMessage { 
                $script:lastPSFMessage = @{ Level = $Level; Message = $Message }
            } -ModuleName AnalyzeTTBot -Verifiable
            Mock Get-PSFConfigValue { 'Добро пожаловать!' } -ModuleName AnalyzeTTBot
            $script:lastPSFMessage = $null
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
                param($chatId, $text, $replyToMessageId, $parseMode)
                return @{ Success = $false; Error = 'Ошибка отправки' }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService, $null, $null, $null, $null, $null
            )
            $botService.HandleCommand('/start', 1, 2)
            $script:lastPSFMessage.Level | Should -Match 'Warn'
            $script:lastPSFMessage.Message | Should -Match 'Ошибка отправки'
        }
    }
}
