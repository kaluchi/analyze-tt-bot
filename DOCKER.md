# Docker инструкции для TikTok Analyzer Bot

Этот документ содержит инструкции по запуску TikTok Analyzer Bot с использованием Docker.


## Требования

- Docker
- Docker Compose (если вы используете Docker Compose)

## Конфигурация

Перед запуском бота необходимо настроить следующие параметры:

1. **Токен Telegram бота** - Получите токен от [@BotFather](https://t.me/BotFather) в Telegram и установите его в переменную окружения `TELEGRAM_BOT_TOKEN` из она автоматически будет подхвачена при при запуске контейнера через `docker-compose.yml`.

## Сборка образов

### Вариант 1: используя Docker Compose

```bash
docker-compose build
```
### Вариант 2: используя Docker Build

```powershell
# способ 1
docker build -f Dockerfile .
```

### Вариант 3: используя скрипт
```powershell
./build.ps
```

## Запуск бота

### Вариант 1: Используя Docker Compose
```bash
docker-compose up bot -d
```

### Вариант 2: Используя Docker
Запуск бота:

```bash
docker run --rm -t analyze-tt-bot
```
Запуск только для проверки зависимостей:

```bash
docker run --rm -t analyze-tt-bot -ValidateOnly
```

## Переменные окружения

- `TELEGRAM_BOT_TOKEN` - Токен Telegram бота (обязательно)
  - Получите токен у [@BotFather](https://t.me/BotFather) в Telegram
  - Задайте его в переменной окружения при запуске контейнера
  - Пример: `-e TELEGRAM_BOT_TOKEN=1234567890:AABBCCDDeeffGGhhIIjjKKllMMnnOOppQQ`

- `LOG_LEVEL` - Уровень логирования (опционально, по умолчанию "Information")
  - Доступные значения: `Verbose`, `Information`, `Warning`, `Error`
  - Пример: `-e LOG_LEVEL=Verbose`

При запуске из Docker Compose, эти переменные автоматически подватываются в файле `docker-compose.yml`:

```yaml
environment:
  # Обязательно укажите ваш реальный токен, полученный от @BotFather
  - TELEGRAM_BOT_TOKEN=your_telegram_bot_token_here
  # Уровень логирования: Verbose, Information, Warning, Error
  - LOG_LEVEL=Information
```

## Тестирование

Для запуска интеграционных тестов в контейнеризированной среде.

```bash
 docker run --rm analyze-tt-bot-test
```