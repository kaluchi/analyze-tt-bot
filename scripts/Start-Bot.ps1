<#
.SYNOPSIS
    Запускает TikTok бота для анализа видео с использованием модуля AnalyzeTTBot.
.DESCRIPTION
    Этот скрипт запускает бота для анализа TikTok видео с использованием
    модуля AnalyzeTTBot вместо прямого импорта файлов.
.PARAMETER ValidateOnly
    Только проверяет зависимости без запуска бота.
.PARAMETER Debug
    Запускает бота в режиме отладки.
.EXAMPLE
    .\Start-Bot.ps1 -ValidateOnly
    Проверяет зависимости без запуска бота.
.EXAMPLE
    .\Start-Bot.ps1
    Запускает бота в обычном режиме.
.NOTES
    Автор: TikTok Bot Team
    Версия: 2.1.0
#>

param (
    [switch]$ValidateOnly,
    [switch]$Debug,
    [switch]$SkipCheckUpdates
)

# Глобальные настройки для подавления лишних уведомлений
$global:ConfirmPreference = 'None'
$PSDefaultParameterValues = @{'*:Confirm'=$false}
$env:POWERSHELL_UPDATECHECK = 'Off'
$ErrorActionPreference = 'Stop'

# Если задан параметр -Debug, устанавливаем соответствующий режим отладки
if ($Debug) {
    $DebugPreference = "Continue"
}

# Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
# Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
# т.к. отсуствует одна из важных переменнтых, а именно не хаходится ProgramData
# В Linux-контейнере устанавливаем пути к ProgramData и TEMP, если они не заданы
if (-not $Env:ProgramData) {
    $Env:ProgramData = "/var/lib/powershell/programdata"
}

if (-not $Env:TEMP) {
    $Env:TEMP = "/tmp"
}

# Проверяем наличие модуля
if (-not (Get-Module -Name PSFramework -ListAvailable)) {
    Write-Warning "PSFramework не установлен. Попытка установки..."
    Install-Module -Name PSFramework -AllowClobber -Scope CurrentUser
}

# Импорт необходимых модулей
try {
    # Путь к модулю AnalyzeTTBot (исправлен для новой структуры каталогов)
    $modulePath = Join-Path -Path $PSScriptRoot -ChildPath "..\src\AnalyzeTTBot"
    $manifestPath = Join-Path -Path $modulePath -ChildPath "AnalyzeTTBot.psd1"
    Import-Module -Name $manifestPath -Force -ErrorAction Stop
}
catch {
    Write-Error "Ошибка при импорте модулей: $_"
    exit 1
}

# Параметры запуска бота
$botParams = @{}

if ($ValidateOnly) {
    $botParams.ValidateOnly = $true
    Write-PSFMessage -Level Host -Message "Режим валидации - проверка зависимостей" 
}

if ($Debug) {
    $botParams.DebugMode = $true
    Write-PSFMessage -Level Host -Message "Запуск в режиме отладки" 
}

if ($SkipCheckUpdates) {
    $botParams.SkipCheckUpdates = $true
    Write-PSFMessage -Level Host -Message "Пропуск проверки обновлений" 
}

# Запуск бота
try {
    Start-AnalyzeTTBot @botParams
}
catch {
    Write-PSFMessage -Level Critical -Message "Ошибка при запуске AnalyzeTTBot: $_"
    exit 1
}