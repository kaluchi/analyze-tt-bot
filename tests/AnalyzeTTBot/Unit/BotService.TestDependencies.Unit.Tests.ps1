Describe 'BotService.TestDependencies method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
    It 'Возвращает успешный результат при валидных зависимостях' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $true; Version = '1.0'; Description = 'OK' } } } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                return New-SuccessResponse -Data @{ Name = "yt-dlp"; Valid = $true; Version = "2025.03.26"; Description = "yt-dlp найден" }
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                return New-SuccessResponse -Data @{ Name = "MediaInfo"; Valid = $true; Version = "21.04.2025"; Description = "MediaInfo найден" }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $null, $null, $null
            )
            $result = $botService.TestDependencies($true, $false)
            $result.Success | Should -BeTrue
            $result.Data.AllValid | Should -BeTrue
            $result.Data.Dependencies.Count | Should -BeGreaterThan 0
        }
    }
    It 'Обнаруживает невалидные зависимости' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $false; Version = 'Н/Д'; Description = 'Токен не валиден' } } } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                return New-SuccessResponse -Data @{ Name = "yt-dlp"; Valid = $false; Version = "Не найден"; Description = "yt-dlp не найден в системе" }
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                return New-SuccessResponse -Data @{ Name = "MediaInfo"; Valid = $false; Version = "Не найден"; Description = "MediaInfo не найден в системе" }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $null, $null, $null
            )
            $result = $botService.TestDependencies($true, $false)
            $result.Success | Should -BeTrue
            $result.Data.AllValid | Should -BeFalse
            $result.Data.Dependencies.Count | Should -BeGreaterThan 0
        }
    }
    It 'Обнаруживает частично валидные зависимости' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $true; Version = '1.0'; Description = 'OK' } } } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                return New-SuccessResponse -Data @{ Name = "yt-dlp"; Valid = $true; Version = "2025.03.26"; Description = "yt-dlp найден" }
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                return New-SuccessResponse -Data @{ Name = "MediaInfo"; Valid = $false; Version = "Не найден"; Description = "MediaInfo не найден в системе" }
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $null, $null, $null
            )
            $result = $botService.TestDependencies($true, $false)
            $result.Success | Should -BeTrue
            $result.Data.AllValid | Should -BeFalse
            $result.Data.Dependencies.Count | Should -BeGreaterThan 0
            ($result.Data.Dependencies | Where-Object { -not $_.Valid }).Count | Should -Be 4
        }
    }
    It 'Обрабатывает пустой список зависимостей' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $true; Version = '1.0'; Description = 'OK' } } } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                return New-SuccessResponse -Data $null
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                return New-SuccessResponse -Data $null
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $null, $null, $null
            )
            $result = $botService.TestDependencies($true, $false)
            $result.Success | Should -BeTrue
            $result.Data.Dependencies.Count | Should -Be 5 # PowerShell, PSFramework и дополнительные зависимости
        }
    }
    It 'Обрабатывает неожиданный тип ошибки' {
        InModuleScope AnalyzeTTBot {
            $mockTelegramService = [ITelegramService]::new()
            $mockTelegramService | Add-Member -MemberType ScriptMethod -Name TestToken -Value { param($skip) @{ Success = $true; Data = @{ Name = 'Telegram Bot'; Valid = $true; Version = '1.0'; Description = 'OK' } } } -Force
            $mockYtDlpService = [IYtDlpService]::new()
            $mockYtDlpService | Add-Member -MemberType ScriptMethod -Name TestYtDlpInstallation -Value {
                throw 'Неожиданная ошибка'
            } -Force
            $mockMediaInfoExtractorService = [IMediaInfoExtractorService]::new()
            $mockMediaInfoExtractorService | Add-Member -MemberType ScriptMethod -Name TestMediaInfoDependency -Value {
                throw 'Неожиданная ошибка'
            } -Force
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $mockTelegramService,
                $mockYtDlpService,
                $mockMediaInfoExtractorService,
                $null, $null, $null
            )
            try {
                $result = $botService.TestDependencies($true, $false)
                $result.Success | Should -BeTrue
                $result.Data.AllValid | Should -BeFalse
            } catch {
                $_.Exception.Message | Should -Match 'Неожиданная ошибка'
            }
        }
    }
}
