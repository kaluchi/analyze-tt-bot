# Guidelines for PowerShell Project (AnalyzeTTBot)

This document outlines the guidelines for developing, testing, and importing code in the AnalyzeTTBot PowerShell project, designed for TikTok video analysis and downloading. The project uses [PSFramework](https://psframework.org/) for configuration and logging, with a modular structure including AnalyzeTTBot
and other services.

## 1. Module Structure

Organize the project into modular, reusable PowerShell modules to ensure maintainability and scalability.

### 1.1. Directory Structure
```
analyze-tt-bot/
├── scripts/                   # Скрипты для запуска и управления
│   ├── Start-Bot.ps1         # Скрипт запуска бота
│   └── Get-TestCoverage.ps1   # Скрипт анализа покрытия кода
├── src/                      # Исходный код проекта
│   └── AnalyzeTTBot/         # Основной модуль
│       ├── AnalyzeTTBot.psm1   # Файл модуля
│       ├── AnalyzeTTBot.psd1   # Манифест модуля
│       ├── Config/             # Конфигурация
│       ├── Factories/          # Фабрики и контейнеры зависимостей
│       ├── Interfaces/         # Интерфейсы (IYtDlpService, и т.д.)
│       ├── Services/           # Сервисы (BotService, и т.д.)
│       └── Utilities/          # Вспомогательные функции
├── tests/                    # Тесты и отладка
│   └── AnalyzeTTBot/         # Тесты модуля
│       ├── Helpers/            # Вспомогательные функции для тестов
│       ├── Integration/        # Интеграционные тесты
│       ├── Mocks/              # Моки для тестирования
│       ├── TestData/           # Тестовые данные и примеры ответов API
│       └── Unit/               # Модульные тесты
│           ├── BotService.HandleCommand.Unit.Tests.ps1
│           ├── BotService.ProcessTikTokUrl.Unit.Tests.ps1
│           ├── BotService.Start.HandleEmptyMessage.Unit.Tests.ps1
│           ├── YtDlpService.ExecuteYtDlp.Unit.Tests.ps1
│           ├── ... (и так далее)
├── tools/                    # Инструменты разработки
├── docs/                     # Документация проекта
├── temp/                     # Временные файлы
├── GUIDELINES.md            # Руководство по разработке
└── README.md                # Основная документация
```
- **src/**: Содержит исходный код модулей.
- **tests/**: Файлы тестов Pester для каждого модуля и сервиса.
- **Именование модулей**: Используйте PascalCase без точек (например, AnalyzeTTBot). Избегайте точек, если они не требуются для уникальности в PowerShell Gallery.
- **Подкаталоги**:
  - Config/: Файлы конфигурации модуля.
  - Interfaces/: Интерфейсы для инверсии контроля (например, IYtDlpService.ps1).
  - Services/: Реализации сервисов (например, YtDlpService.ps1).

### 1.2. Module Manifests (*.psd1)
Each module must have a manifest for metadata and dependencies.

**Example: AnalyzeTTBot.psd1**
```powershell
@{
    ModuleVersion = '1.0.0'
    GUID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    Author = 'YourName'
    Description = 'Services for TikTok video analysis and download'
    RootModule = 'AnalyzeTTBot.psm1'
    RequiredModules = @('PSFramework')
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    Tags = @('TikTok', 'VideoDownloader', 'YtDlp')
}
```
- **RequiredModules**: Declare external dependencies (e.g., PSFramework, other project modules).
- **Tags**: Improve discoverability in PowerShell Gallery.
- **GUID**: Generate unique GUID ([guid]::NewGuid()).

### 1.3. Module Files (*.psm1)
- **RootModule (.psm1)**: Entry point for module logic. Import classes, functions, and external modules.
- **Example: AnalyzeTTBot.psm1**
  ```powershell
  # Import dependencies
  Import-Module -Name PSFramework -ErrorAction Stop
  Import-Module -Name AnalyzeTTBot -ErrorAction Stop
 
  # Import functions
  Get-ChildItem -Path ./Functions/*.ps1 | ForEach-Object { . $_.FullName }

  # Import classes
  Get-ChildItem -Path ./Interfaces/*.ps1 | ForEach-Object { . $_.FullName }
  ```
- **Dynamic Imports**: Use Get-ChildItem to load all *.ps1 files in Classes/ or Functions/.
- **Error Handling**: Use -ErrorAction Stop for external module imports to fail fast.
- **Load Order**: Load functions before classes to resolve dependencies.

## 2. Testing

Use Pester for unit and integration tests to ensure reliability, especially for AnalyzeTTBot with 8+ services.

### 2.1. Структура тестов

#### 2.1.1. Простые тесты

- Для небольших модулей используйте отдельный файл тестов в корне каталога tests (например, tests/AnalyzeTTBotShared.Unit.Tests.ps1).
- Именование: <ИмяМодуля>.Unit.Tests.ps1.
- В таких тестах не требуется сложная инициализация окружения или отдельные каталоги.
- Импорт тестируемого модуля (Import-Module) выполняется в блоке BeforeAll, чтобы обеспечить доступ к функциям и классам модуля во всех тестах.

#### 2.1.2. Сложные тесты

- Для крупных модулей используйте подкаталоги внутри tests/AnalyzeTTBot/:
  - Unit/ — модульные тесты для каждого сервиса (например, FileSystemService.Unit.Tests.ps1).
  - Integration/ — интеграционные тесты.
  - Mocks/ — моки сервисов.
  - Helpers/ — вспомогательные скрипты для инициализации окружения.
  - TestData/ — тестовые данные.
- В большинстве случаев, используйте следующую схему именования:
  - Именование: `<ИмяСервиса>.<МетодСервиса>.<ТипТеста>.Tests.ps1`.
  - Пример: `BotService.ProcessTikTokUrl.Unit.Tests.ps1`, `TelegramService.SendMessage.Unit.Tests.ps1`

- Для особых случаев, когда основной способ не вмещает в себя все варианты ветвлений:
  - Именование: `<ИмяСервиса>.<МетодСервиса>.<ГруппаТестов>.<ТипТеста>.Tests.ps1`.
  - Примеры: 
    - `BotService.Start.HandleEmptyMessage.Unit.Tests.ps1` - тесты обработки пустых сообщений
    - `BotService.Start.HandleServiceError.Unit.Tests.ps1` - тесты обработки ошибок сервиса
    - `YtDlpService.ExecuteYtDlp.NetworkErrors.Unit.Tests.ps1` - тесты сетевых ошибок
- В каждом тестовом файле обязательно используйте блок BeforeAll для загрузки тестируемого модуля через Import-Module (обычно по пути к .psd1). Это гарантирует, что InModuleScope будет работать корректно и все приватные функции/классы будут доступны.
- Пример загрузки:
  ```powershell
  BeforeAll {
      $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
      $manifestPath = Join-Path $projectRoot "src/AnalyzeTTBot/AnalyzeTTBot.psd1"
      Import-Module -Name $manifestPath -Force -ErrorAction Stop
  }
  ```

##### 2.1.2.1. Использование InModuleScope

- Для изолированного тестирования функций и классов используйте блоки InModuleScope { ... }.
- Это позволяет обращаться к приватным функциям и классам модуля.
- Важно: Имя модуля в InModuleScope должно совпадать с именем, под которым он был загружен через Import-Module.
- Пример:
  ```powershell
  InModuleScope AnalyzeTTBot {
      $service = [FileSystemService]::new("TestFolder")
      $result = $service.GetTempFolderPath()
      $result | Should -BeOfType 'string'
  }
  ```

##### 2.1.2.2. InModuleScope с передачей параметров тестового окружения

- Для сложных сценариев используйте InModuleScope с параметром -Parameters для передачи переменных окружения внутрь блока.
- Это позволяет использовать подготовленные в BeforeAll/BeforeEach переменные (например, пути, имена файлов, тестовые значения) внутри теста.
- Все переменные, переданные через -Parameters, становятся доступными внутри блока InModuleScope как обычные переменные.
- Пример:
  ```powershell
  BeforeAll {
      $script:TestDir = Join-Path $env:TEMP "FileSystemServiceTest_$(Get-Random)"
      New-Item -Path $script:TestDir -ItemType Directory -Force | Out-Null
      $script:tempFolderName = "TikTokAnalyzerTest"
  }
  It "Should create an instance with correct temp folder name" {
      InModuleScope AnalyzeTTBot -Parameters @{ tempFolderName = $script:tempFolderName } {
          $fileSystemService = [FileSystemService]::new($tempFolderName)
          $fileSystemService.TempFolderName | Should -Be $tempFolderName
      }
  }
  ```
- Важно: Перед использованием InModuleScope всегда убедитесь, что модуль загружен через Import-Module в BeforeAll. Если модуль не загружен, InModuleScope не сможет получить доступ к его внутренним функциям и классам.

##### 2.1.2.3. Правильное мокирование в модульных тестах

- **Мокирование интерфейсов напрямую в тесте**: Прямо в тесте создавайте экземпляр интерфейса и добавляйте необходимые методы:
  ```powershell
  # Создаем экземпляр интерфейса
  $mockTelegramService = [ITelegramService]::new()
  
  # Добавляем необходимые методы
  $mockTelegramService | Add-Member -MemberType ScriptMethod -Name SendMessage -Value {
      param($chatId, $text, $replyToMessageId, $parseMode)
      return @{ Success = $true; Data = @{ result = @{ message_id = 123 } } }
  } -Force
  ```

- **Добавление нужных свойств**: При необходимости добавляйте поля и свойства:
  ```powershell
  # Добавление свойства для хранения состояния
  $mockTelegramService | Add-Member -MemberType NoteProperty -Name SentMessages -Value ([System.Collections.ArrayList]@())
  ```

- **Инициализация переменной окружения для PSFramework**: Всегда добавляйте следующую строку в блок BeforeAll для предотвращения ошибок с PSFramework:
  ```powershell
  BeforeAll {
      $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
      # Далее следует импорт модуля
  }
  ```

- **Мокирование зависимостей, а не тестируемых объектов**: Всегда мокируйте только зависимости тестируемого метода, но не сам тестируемый метод:
  ```powershell
  # ПРАВИЛЬНО: Мокирование зависимости
  # В данном случае мы ТЕСТИРУЕМ метод SaveTikTokVideo, но МОКИРУЕМ его внутреннюю зависимость ExecuteYtDlp
  # Это позволяет проверить реальную логику SaveTikTokVideo, изолировав её от внешних зависимостей
  $service = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
  $service | Add-Member -MemberType ScriptMethod -Name "ExecuteYtDlp" -Value {
      param($url, $outputPath)
      return @{ Success = $true; Data = @{ RawOutput = @("Video downloaded successfully"); OutputPath = $outputPath } }
  } -Force
  
  # Тестируем реальный метод SaveTikTokVideo
  $result = $service.SaveTikTokVideo("https://tiktok.com/video/123", "C:\temp\output.mp4")
  $result.Success | Should -BeTrue
  
  # НЕПРАВИЛЬНО: Мокирование тестируемого метода
  # В этом случае мы пытаемся МОКИРОВАТЬ сам метод SaveTikTokVideo, который мы хотим ТЕСТИРОВАТЬ
  # Это не является модульным тестом, так как мы не тестируем реальную логику метода
  $service = [YtDlpService]::new("yt-dlp", $mockFileSystemService, 30, "best")
  $service | Add-Member -MemberType ScriptMethod -Name "SaveTikTokVideo" -Value {
      param($url, $outputPath)
      return @{ Success = $true; Data = @{ FilePath = $outputPath; AuthorUsername = "testuser" } }
  } -Force
  
  # Тест не имеет ценности, так как мы просто проверяем наш же мок
  $result = $service.SaveTikTokVideo("https://tiktok.com/video/123", "C:\temp\output.mp4")
  $result.Success | Should -BeTrue  # Это всегда будет true, так как мы сами это задали
  ```

- **Мокирование системных функций в контексте модуля**: Для мокирования системных функций внутри InModuleScope используйте Pester Mock с явным указанием ModuleName:
  ```powershell
  InModuleScope AnalyzeTTBot {
      # Мокирование Invoke-RestMethod для симуляции ответа API
      Mock -CommandName Invoke-RestMethod -ModuleName AnalyzeTTBot -MockWith { 
          return @{ ok = $true; result = @{ username = 'test_bot' } } 
      }
      
      # Тест с использованием замоканной функции
      $result = $service.TestToken($false)
      $result.Success | Should -BeTrue
      $result.Data.Valid | Should -BeTrue
  }
  ```

- **Стандартный паттерн для модульных тестов**:
  1. Подготовка окружения (создание мок-объектов зависимостей)
  2. Мокирование внутренних методов и системных функций
  3. Вызов тестируемого метода с проверяемыми параметрами
  4. Проверка результатов через Should assertions
  5. Проверка вызова замоканных методов через Should -Invoke (при необходимости)

### 2.2. Testing Guidelines
- **Isolation**: Import module in BeforeAll, remove in AfterAll to avoid state leaks.
- **Mocking**: Mock external dependencies (e.g., yt-dlp, APIs) and interfaces.
  ```powershell
  Mock Invoke-Process { @{ ExitCode = 0 } } -ModuleName AnalyzeTTBot
  ```
- **Running Tests**: Tests must be runnable with simple Invoke-Pester commands by automatically finding all *.Tests.ps1 files.
  ```powershell
  # Запуск всех тестов
  Invoke-Pester -Path "./tests"
  
  # Запуск определенных модульных тестов
  Invoke-Pester -Path "./tests/AnalyzeTTBot/Unit"
  
  # Запуск тестов конкретного сервиса
  Invoke-Pester -Path "./tests/AnalyzeTTBot/Unit/FileSystemService.Unit.Tests.ps1"
  
  # Запуск всех тестов с детальным выводом
  Invoke-Pester -Path "./tests" -Output Detailed
  
  # Анализ покрытия кода тестами с помощью специального скрипта
  ./scripts/Get-TestCoverage.ps1
  ```
- **PSFramework**: Use for test configuration and logging.
  ```powershell
  Set-PSFConfig -Module AnalyzeTTBot -Name YtDlp.Path -Value 'C:\mock\yt-dlp.exe'
  Write-PSFMessage -Level Verbose -Message 'Test setup' -Tag Test
  ```
- **Coverage**: Стремитесь к покрытию >80% для каждого сервиса. Используйте Get-TestCoverage.ps1 для анализа.
  ```powershell
  # Анализ покрытия всех сервисов
  ./scripts/Get-TestCoverage.ps1
  
  # Анализ покрытия с пользовательскими параметрами
  ./scripts/Get-TestCoverage.ps1 -TestPath "./tests/AnalyzeTTBot/Unit" -MinCoverage 90
  ```

- **CI/CD**: Run tests in GitHub Actions, including coverage.
  ```yaml
  name: CI for AnalyzeTTBot
  on:
    push:
      branches: [ main ]
    pull_request:
      branches: [ main ]
  jobs:
    test:
      runs-on: windows-latest
      steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        shell: pwsh
        run: |
          Install-Module -Name Pester, PSFramework -Force -Scope CurrentUser
      - name: Install yt-dlp
        shell: pwsh
        run: |
          choco install yt-dlp --yes
      - name: Run tests
        shell: pwsh
        run: |
          Invoke-Pester -Script ./tests -Output Detailed -CodeCoverage ./src/AnalyzeTTBot/Classes/*.ps1 -CodeCoverageOutputFile coverage.xml
  ```

## 3. Code Imports

Ensure robust and predictable module imports for development, testing, and deployment.

### 3.1. Import Guidelines
- **Explicit Imports**: Use Import-Module with -ErrorAction Stop in *.psm1 and scripts for external modules.
  ```powershell
  Import-Module -Name AnalyzeTTBotShared -ErrorAction Stop
  ```
- **Dependencies in Manifest**: Declare all external module dependencies in RequiredModules of *.psd1 to ensure automatic installation and discovery.
  ```powershell
  RequiredModules = @('PSFramework', 'AnalyzeTTBot', 'AnalyzeTTBotShared')
  ```
- **Duplication Note**: RequiredModules in *.psd1 and Import-Module in *.psm1 serve different purposes:
  - RequiredModules: Declares dependencies for PowerShell Gallery and automatic installation.
  - Import-Module: Ensures dependencies are loaded in the session with explicit error handling.
  - Keep both for reliability, compatibility, and clarity.
- **Version Control**: Specify minimum module versions in #Requires or RequiredModules.
  ```powershell
  #Requires -Modules @{ ModuleName = 'PSFramework'; ModuleVersion = '1.12.346' }
  ```

### 3.2. Intra-Module File References
- **Dot Sourcing**: Load all *.ps1 files (classes, functions) in *.psm1 using dot sourcing.
  ```powershell
  Get-ChildItem -Path ./Classes/*.ps1 | ForEach-Object { . $_.FullName }
  Get-ChildItem -Path ./Functions/*.ps1 | ForEach-Object { . $_.FullName }
  ```
- **Direct Access**: Reference classes and functions by name within the module (e.g., [YtDlpService]::new(), Invoke-Process).
- **Load Order**: Ensure dependencies are loaded first (e.g., functions before classes).
  ```powershell
  Get-ChildItem -Path ./Functions/*.ps1 | ForEach-Object { . $_.FullName }
  Get-ChildItem -Path ./Interfaces/*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
  Get-ChildItem -Path ./Classes/*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
  Get-ChildItem -Path ./Services/*.ps1 | Sort-Object Name | ForEach-Object { . $_.FullName }
  
  ```
- **Avoid Cyclic Dependencies**: Move shared logic to new module or use interfaces from AnalyzeTTBot.
- **No Import-Module for Internal Files**: Do not use Import-Module for *.ps1 files within the same module.
- **Testing**: Import the entire module in tests via Import-Module, not individual *.ps1 files.
  ```powershell
  Import-Module -Force -Path ./src/AnalyzeTTBot/AnalyzeTTBot.psd1 -ErrorAction Stop
  ```

### 3.3. Wrapper Script
Provide a user-friendly script for end-users to interact with modules.

**Example: Download-TikTok.ps1**
```powershell
#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'AnalyzeTTBot'; ModuleVersion = '1.0.0' }

param (
    [Parameter(Mandatory)][string]$Url,
    [Parameter(Mandatory)][string]$OutputPath
)

Import-Module -Name AnalyzeTTBot -ErrorAction Stop

class SimpleFileSystemService : IFileSystemService {
    [string] GetTempFolderPath() { return [System.IO.Path]::GetTempPath() }
}

try {
    $fileSystem = [SimpleFileSystemService]::new()
    $service = [YtDlpService]::new('yt-dlp', $fileSystem, 30, 'mp4')
    $result = $service.SaveTikTokVideo($Url, $OutputPath)
    if ($result.Success) {
        Write-PSFMessage -Level Host -Message "Video downloaded to $OutputPath" -Tag TikTok
    } else {
        throw $result.Error
    }
} catch {
    Write-PSFMessage -Level Error -Message "Error: $_" -ErrorRecord $_ -Tag TikTok
    throw
}
```

- **Purpose**: Simplifies module usage for non-developers.
- **Imports**: Explicitly import required modules.
- **Error Handling**: Use try-catch with PSFramework logging.

### 3.4. Publishing
- **PowerShell Gallery**: Publish modules for easy installation.
  ```powershell
  Publish-Module -Path ./src/AnalyzeTTBot -NuGetApiKey $ApiKey
  ```
- **Uniqueness**: Check name availability (Find-Module -Name AnalyzeTTBot*).
- **Dependencies**: Ensure RequiredModules includes all dependencies.

## 4. Additional Notes
- **PSFramework**: Use for configuration, logging, and error handling.
  ```powershell
  Write-PSFMessage -Level Host -Message 'Operation completed' -Tag TikTok
  Set-PSFConfig -Module AnalyzeTTBot -Name YtDlp.TimeoutSeconds -Value 30
  ```
- **Cross-Platform**: Support Windows and Linux/macOS with platform-agnostic paths.
  ```powershell
  $ytDlpPath = [System.IO.Path]::Combine($basePath, 'bin', 'yt-dlp')
  ```
- **Documentation**: Include README.md with installation and usage instructions.
  ```markdown
  ## Installation
  Install-Module -Name AnalyzeTTBot -Scope CurrentUser
  