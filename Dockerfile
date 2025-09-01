# base.Dockerfile - общий для основного и тестового образов
FROM mcr.microsoft.com/powershell:7.5-ubuntu-jammy AS env-bot

# Установка необходимых системных зависимостей, yt-dlp, модулей и создание директорий
RUN apt-get update && apt-get install -y \
    mediainfo \
    python3 \
    python3-pip \
    wget \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install yt-dlp==2025.8.22 \
    && pwsh -Command "Install-Module -Name PSFramework -Force -MinimumVersion 1.12.346 -Scope AllUsers -AllowClobber -SkipPublisherCheck -Repository PSGallery" \
    && mkdir -p /app/logs /app/temp /app/cookies \
    && chmod -R 777 /app/temp /app/logs /app/cookies

# Создание рабочей директории
WORKDIR /app

# Конфигурация переменных окружения
ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    POWERSHELL_UPDATECHECK=Off \
    LOG_LEVEL="Information"

# Установка переменных окружения
ENV TEMP="/app/temp"

# Образ для тестирования с Pester - подготовка среды
FROM env-bot AS env-bot-test

# Установка и настройка автоимпорта Pester - это делается ОДИН раз
RUN pwsh -Command "Install-Module Pester -Force -MinimumVersion 5.4.0 -SkipPublisherCheck" && \
    pwsh -Command "New-Item -Path /opt/microsoft/powershell/7/profile.ps1 -Force | Out-Null; Add-Content -Path /opt/microsoft/powershell/7/profile.ps1 -Value 'Import-Module Pester'"

# Оптимизированный Dockerfile для основного приложения
FROM env-bot AS bot

# Копируем структуру проекта (кроме тестов)
COPY ./scripts/ /app/scripts/
COPY ./src/ /app/src/

# Точка входа - запуск бота
# При запуске можно добавить параметры:
# -ValidateOnly: только проверить зависимости без запуска бота
# -Debug: запустить в режиме отладки
# -SkipCheckUpdates: пропустить проверку обновлений
ENTRYPOINT ["pwsh", "-File", "./scripts/Start-Bot.ps1"]

# Оптимизированный Dockerfile для тестирования
FROM env-bot-test AS bot-test

# Копируем структуру проекта и тесты
COPY ./scripts/ /app/scripts/
COPY ./src/ /app/src/
COPY ./tests/ /app/tests/

# Точка входа
ENTRYPOINT ["pwsh", "-Command"]
CMD ["Invoke-Pester -Path /app/tests/AnalyzeTTBot/Integration -Output Detailed"]