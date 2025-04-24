<#
.SYNOPSIS
    Тесты для конструктора и инициализации MediaInfoExtractorService.
.DESCRIPTION
    Модульные тесты для проверки корректности создания экземпляра MediaInfoExtractorService и его инициализации.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.0.0
    Дата: 21.04.2025
#>

Describe "MediaInfoExtractorService.Constructor Tests" {
    BeforeAll {
        # Без этой строчки скрипт вываливался при инициаилизации модуля PSFramework
        # Связано с тем что в импорте модуля, зависящего от PSFramework, при работе в минимальном окружении возникает ошибка "Cannot bind argument to parameter 'Path' because it is null."
        # т.к. отсутствует одна из важных переменных, а именно не находится ProgramData
        # Строчка ниже устраняет эту ошибку
        $Env:ProgramData = $Env:ProgramData -or [Environment]::GetFolderPath("CommonApplicationData")
        
        # Импортируем основной модуль
        $projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
        $manifestPath = Join-Path $projectRoot "src\AnalyzeTTBot\AnalyzeTTBot.psd1"
        if (-not (Test-Path $manifestPath)) {
            throw "Модуль AnalyzeTTBot.psd1 не найден по пути: $manifestPath"
        }
        
        Import-Module -Name $manifestPath -Force -ErrorAction Stop
        
        if (-not (Get-Module -Name AnalyzeTTBot)) {
            throw "Модуль AnalyzeTTBot не загружен после импорта"
        }
        if (-not (Get-Module -ListAvailable -Name PSFramework)) {
            throw "Модуль PSFramework не установлен. Установите с помощью: Install-Module -Name PSFramework -Scope CurrentUser"
        }
    }
    
    Context "Constructor and initialization" {
        It "Should create an instance with file system service" {
            InModuleScope -ModuleName AnalyzeTTBot {
                # Создаем экземпляр IFileSystemService внутри модуля
                $fileSystemServiceMock = New-Object -TypeName IFileSystemService
                
                # Инициализируем сервис
                $mediaInfoExtractorService = New-Object -TypeName MediaInfoExtractorService -ArgumentList @($fileSystemServiceMock)
                
                # Проверяем, что свойство FileSystemService установлено корректно
                $mediaInfoExtractorService.FileSystemService | Should -Be $fileSystemServiceMock
            }
        }
    }
    
    AfterAll {
        # Выгружаем модуль после тестов
        Remove-Module -Name AnalyzeTTBot -Force -ErrorAction SilentlyContinue
    }
}