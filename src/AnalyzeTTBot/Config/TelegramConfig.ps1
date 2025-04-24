<#
.SYNOPSIS
    Конфигурация параметров Telegram для AnalyzeTTBot с использованием PSFramework.
.DESCRIPTION
    Определяет настройки Telegram для AnalyzeTTBot с использованием современных методов PSFramework.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 02.04.2025
#>

# Регистрируем настройки для Telegram бота
# Проверяем наличие переменной окружения TELEGRAM_BOT_TOKEN
Write-PSFMessage -Level Verbose -Message "Проверка наличия переменной окружения TELEGRAM_BOT_TOKEN"

# Используем переменную окружения, если она задана
$telegramToken = if ($env:TELEGRAM_BOT_TOKEN) {
    $env:TELEGRAM_BOT_TOKEN  # Используем переменную окружения
} else {
    "PLACE_YOUR_REAL_TOKEN_HERE"  # Значение по умолчанию
}

# Проверяем, была ли задана переменная окружения
if ($env:TELEGRAM_BOT_TOKEN) {
    Write-PSFMessage -Level Verbose -Message "Переменная окружения TELEGRAM_BOT_TOKEN найдена и будет использована"
}

$telegramConfigModule = @{
    Module          = "AnalyzeTTBot"  # Имя модуля для группировки настроек
    Name            = "Telegram.Token" # Имя параметра
    Value           = $telegramToken # Значение, которое может быть из переменной окружения
    Description     = "Токен для API Telegram бота, получаемый от @BotFather"
    Validation      = "string" # Тип проверки
    Initialize      = $true # Инициализировать, если значение не установлено
    ModuleExport    = $false # Не экспортировать параметр за пределы модуля
    PassThru        = $true # Передать объект конфигурации для дальнейшего использования
}
Set-PSFConfig @telegramConfigModule | Register-PSFConfig



# Регистрируем максимальный размер файла для отправки в Telegram
$telegramFileSizeConfig = @{
    Module          = "AnalyzeTTBot"
    Name            = "MaxFileSize"
    Value           = 50
    Description     = "Максимальный размер файла для отправки через Telegram (в МБ)"
    Validation      = "integer"
    Initialize      = $true
    ModuleExport    = $false
    PassThru        = $true
}
Set-PSFConfig @telegramFileSizeConfig | Register-PSFConfig

# Регистрируем настройки сообщений для взаимодействия с пользователем
$messageSets = @(
    @{
        Name = "Messages.Welcome"
        Value = "👋 Привет! Я бот для анализа TikTok. Отправь мне ссылку на видео из TikTok, и я проанализирую его."
        Description = "Приветственное сообщение бота"
    },
    @{
        Name = "Messages.Help"
        Value = "📝 Как использовать бота:`n1. Скопируйте ссылку на видео из TikTok`n2. Отправьте её мне`n3. Получите анализ видео и оригинальный видеофайл"
        Description = "Справочное сообщение бота"
    },
    @{
        Name = "Messages.Processing"
        Value = "⚙️ Обрабатываю ссылку TikTok..."
        Description = "Сообщение о начале обработки ссылки"
    },
    @{
        Name = "Messages.Downloading"
        Value = "⚙️ Обрабатываю ссылку TikTok...`n📥 Скачиваю видео..."
        Description = "Сообщение о скачивании видео"
    },
    @{
        Name = "Messages.Analyzing"
        Value = "⚙️ Обрабатываю ссылку TikTok...`n📥 Скачиваю видео... Готово!`n🔍 Анализирую видео..."
        Description = "Сообщение об анализе видео"
    },
    @{
        Name = "Messages.InvalidLink"
        Value = "❌ Пожалуйста, отправьте корректную ссылку на видео из TikTok. Введите /help для получения справки."
        Description = "Сообщение об ошибке при неверной ссылке"
    },
    @{
        Name = "Messages.FileTooLarge"
        Value = "⚠️ Файл слишком большой для отправки через Telegram ({0} МБ)."
        Description = "Сообщение о превышении размера файла"
    }
)

# Регистрируем все сообщения единообразно
foreach ($msg in $messageSets) {
    $messageConfig = @{
        Module          = "AnalyzeTTBot"
        Name            = $msg.Name
        Value           = $msg.Value
        Description     = $msg.Description
        Validation      = "string"
        Initialize      = $true
        ModuleExport    = $false
        PassThru        = $true
    }
    Set-PSFConfig @messageConfig | Register-PSFConfig
}

Write-PSFMessage -Level Verbose -Message "Telegram-конфигурация инициализирована"
