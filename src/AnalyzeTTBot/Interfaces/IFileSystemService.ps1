<#
.SYNOPSIS
    Интерфейс для работы с файловой системой.
.DESCRIPTION
    Определяет методы для работы с временными файлами и директориями.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>

class IFileSystemService {
    # Получает путь к временной папке
    # Возвращает: строку с путем к временной папке
    [string] GetTempFolderPath() { throw "Must be implemented" }
    
    # Создает новое имя временного файла с указанным расширением
    # Возвращает: строку с путем к новому временному файлу
    [string] NewTempFileName([string]$extension) { throw "Must be implemented" }
    
    # Удаляет временные файлы старше указанного количества дней
    # Возвращает: @{ Success = $true/false; Data = $removedCount; Error = $errorMessage }
    [hashtable] RemoveTempFiles([int]$olderThanDays) { throw "Must be implemented" }
    
    # Создает директорию, если она не существует
    # Возвращает: @{ Success = $true/false; Data = $path; Error = $errorMessage }
    [hashtable] EnsureFolderExists([string]$path) { throw "Must be implemented" }
}
