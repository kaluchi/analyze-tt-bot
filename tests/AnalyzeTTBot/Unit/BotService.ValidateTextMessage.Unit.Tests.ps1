#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

<#+
.SYNOPSIS
    Тесты для метода ValidateTextMessage в BotService.
.DESCRIPTION
    Модульные тесты для проверки функциональности метода ValidateTextMessage сервиса BotService.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 22.04.2025
#>

Describe 'BotService.ValidateTextMessage method' {
    BeforeAll {
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
    }
    AfterAll {
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }

    It 'Корректно распознает URL в простом тексте' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Тестовый URL
            $messageText = "https://www.tiktok.com/@username/video/1234567890"
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Url | Should -Be $messageText
        }
    }

    It 'Корректно распознает URL в формате отчета с иконкой ссылки' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Тестовый URL в формате отчета
            $messageText = "Анализ видео TikTok:
            🔗 Link: https://www.tiktok.com/@username/video/1234567890
            📊 Характеристики: Разрешение 1080x1920"
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Url | Should -Be "https://www.tiktok.com/@username/video/1234567890"

            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Verbose' -and $FunctionName -eq 'BotService.ValidateTextMessage' -and
                $Message -match "Extracted TikTok URL from report format:"
            }
        }
    }

    It 'Корректно распознает URL в HTML формате ссылки' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Тестовый URL в HTML формате
            $messageText = "Посмотрите это видео: <a href='https://www.example.com/redirect'>https://www.tiktok.com/@username/video/1234567890</a>"
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Url | Should -Be "https://www.tiktok.com/@username/video/1234567890"

            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Verbose' -and $FunctionName -eq 'BotService.ValidateTextMessage' -and
                $Message -match "Extracted TikTok URL from HTML format:"
            }
        }
    }

    It 'Принимает сокращенный URL (vm.tiktok.com)' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Тестовый сокращенный URL
            $messageText = "https://vm.tiktok.com/ABC123/"
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Url | Should -Be $messageText
        }
    }

    It 'Возвращает ошибку при отсутствии ссылки TikTok в тексте' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Текст без URL TikTok
            $messageText = "Это обычное сообщение без ссылки на TikTok https://example.com/video"
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Be "No TikTok URL found in message"

            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Verbose' -and $FunctionName -eq 'BotService.ValidateTextMessage' -and
                $Message -match "No TikTok URL found in message"
            }
        }
    }

    It 'Возвращает ошибку при обнаружении пустого URL' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Используем сложный формат с пустым URL
            $messageText = "🔗 Link: "
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeFalse
            $result.Error | Should -Be "No TikTok URL found in message"

            # Проверяем вызов логирования - в данном случае может быть вызван другой вид логирования
            # или не вызван вовсе, поэтому проверяем только результат
        }
    }

    It 'Использует весь текст сообщения как URL, если не удалось извлечь ссылку TikTok стандартным путем' {
        InModuleScope AnalyzeTTBot {
            # Mock для логирования
            Mock Write-PSFMessage { } -ModuleName AnalyzeTTBot

            # Создаем экземпляр BotService с минимальными зависимостями
            $botService = New-Object -TypeName BotService -ArgumentList @(
                $null, $null, $null, $null, $null, $null
            )
            
            # Текст с нестандартным форматом URL TikTok
            $messageText = "tiktok.com/something/unusual/format"
            
            # Вызываем тестируемый метод
            $result = $botService.ValidateTextMessage($messageText)
            
            # Проверяем результат
            $result.Success | Should -BeTrue
            $result.Data.Url | Should -Be $messageText

            # Проверяем вызов логирования
            Should -Invoke -CommandName Write-PSFMessage -ModuleName AnalyzeTTBot -ParameterFilter {
                $Level -eq 'Warning' -and $FunctionName -eq 'BotService.ValidateTextMessage' -and
                $Message -match "Could not extract TikTok URL, using full message"
            }
        }
    }
}