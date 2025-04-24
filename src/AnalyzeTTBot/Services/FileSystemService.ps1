<#
.SYNOPSIS
    Сервис для работы с файловой системой.
.DESCRIPTION
    Предоставляет функциональность для работы с временными файлами и директориями.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.2.0
    Обновлено: 05.04.2025 - Стандартизация формата ответов
#>
class FileSystemService : IFileSystemService {
    [string]$TempFolderName
    
    FileSystemService([string]$tempFolderName) {
        $this.TempFolderName = $tempFolderName
        $this.EnsureFolderExists($this.GetTempFolderPath())
        
        Write-OperationSucceeded -Operation "FileSystemService initialization" -Details "Temp folder: $tempFolderName" -FunctionName "FileSystemService.Constructor"
    }
    
    [string] GetTempFolderPath() {
        # Используем утилиту Get-EnsuredTempPath для получения пути к временной папке
        return Get-EnsuredTempPath -SubPath $this.TempFolderName
    }
    
    [string] NewTempFileName([string]$extension) {
        # Используем утилиту New-TemporaryFilePath для генерации имени временного файла
        $filePath = New-TemporaryFilePath -Extension $extension -Prefix "tiktok_" -Directory $this.GetTempFolderPath()
        
        Write-OperationSucceeded -Operation "Generate temporary file name" -Details "Path: $filePath" -FunctionName "NewTempFileName"
        return $filePath
    }
    
    [hashtable] RemoveTempFiles([int]$olderThanDays) {
        $tempFolder = $this.GetTempFolderPath()
        
        Write-OperationStart -Operation "Remove old temporary files" -Target $tempFolder -FunctionName "RemoveTempFiles"
        
        try {
            # Используем утилиту Remove-OldFiles для удаления старых файлов
            $count = Remove-OldFiles -Path $tempFolder -OlderThanDays $olderThanDays
            
            Write-OperationSucceeded -Operation "Remove old temporary files" -Details "Removed $count files" -FunctionName "RemoveTempFiles"
            return New-SuccessResponse -Data $count
        } catch {
            $errorMessage = "Failed to remove temporary files: $_"
            Write-OperationFailed -Operation "Remove old temporary files" -ErrorMessage $errorMessage -FunctionName "RemoveTempFiles"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
    
    [hashtable] EnsureFolderExists([string]$path) {
        # Используем утилиту Test-DirectoryExists для проверки и создания директории
        Write-OperationStart -Operation "Ensure folder exists" -Target $path -FunctionName "EnsureFolderExists"
        
        $result = Test-DirectoryExists -Path $path -Create
        
        if ($result) {
            Write-OperationSucceeded -Operation "Ensure folder exists" -Details "Path: $path" -FunctionName "EnsureFolderExists"
            return New-SuccessResponse -Data $path
        } else {
            $errorMessage = "Failed to create directory: $path"
            Write-OperationFailed -Operation "Ensure folder exists" -ErrorMessage $errorMessage -FunctionName "EnsureFolderExists"
            return New-ErrorResponse -ErrorMessage $errorMessage
        }
    }
}
