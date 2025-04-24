<#
.SYNOPSIS
    Вспомогательные функции для работы с JSON.
.DESCRIPTION
    Предоставляет функции для чтения, записи и обработки JSON-данных
    с унифицированной обработкой ошибок.
.NOTES
    Автор: TikTok Bot Team
    Версия: 1.1.0
    Обновлено: 02.04.2025 - Улучшена структура функций, устранены "fall back" сценарии
#>

function Read-JsonFile {
    <#
    .SYNOPSIS
        Читает и парсит JSON-файл.
    .DESCRIPTION
        Безопасно читает JSON-файл с обработкой ошибок и возвращает результат парсинга.
    .PARAMETER Path
        Путь к JSON-файлу.
    .PARAMETER Depth
        Глубина вложенности JSON-объектов для парсинга. По умолчанию: 20.
    .PARAMETER SuppressErrors
        Подавляет вывод ошибок в лог при неудачном парсинге.
    .EXAMPLE
        $data = Read-JsonFile -Path "metadata.json"
        Читает и парсит JSON-файл metadata.json.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [int]$Depth = 20,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressErrors
    )
    
    Write-PSFMessage -Level Verbose -FunctionName "Read-JsonFile" -Message "Reading JSON file: $Path"
    
    # Проверяем существование файла
    if (-not (Test-Path -Path $Path -PathType Leaf)) {
        Write-PSFMessage -Level Warning -FunctionName "Read-JsonFile" -Message "JSON file not found: $Path"
        return $null
    }
    
    try {
        # Читаем содержимое файла
        $jsonContent = Get-Content -Path $Path -Raw -ErrorAction Stop
        
        # Проверяем на пустое содержимое
        if ([string]::IsNullOrWhiteSpace($jsonContent)) {
            Write-PSFMessage -Level Warning -FunctionName "Read-JsonFile" -Message "JSON file is empty: $Path"
            return $null
        }
        
        # Парсим JSON
        $result = $jsonContent | ConvertFrom-Json -Depth $Depth -ErrorAction Stop
        Write-PSFMessage -Level Verbose -FunctionName "Read-JsonFile" -Message "Successfully parsed JSON file: $Path"
        return $result
    }
    catch {
        if (-not $SuppressErrors) {
            Write-PSFMessage -Level Warning -FunctionName "Read-JsonFile" -Message "Failed to parse JSON file '$Path': $_"
        }
        return $null
    }
}

function Write-JsonFile {
    <#
    .SYNOPSIS
        Записывает объект в JSON-файл.
    .DESCRIPTION
        Преобразует объект в JSON и записывает его в файл с обработкой ошибок.
    .PARAMETER Path
        Путь к JSON-файлу для записи.
    .PARAMETER InputObject
        Объект для сериализации в JSON.
    .PARAMETER Depth
        Глубина вложенности JSON-объектов при сериализации. По умолчанию: 20.
    .PARAMETER Force
        Перезаписывает файл, если он уже существует.
    .PARAMETER Encoding
        Кодировка для записи файла. По умолчанию: UTF8.
    .EXAMPLE
        Write-JsonFile -Path "metadata.json" -InputObject $metadata
        Записывает объект $metadata в JSON-файл metadata.json.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,
        
        [Parameter(Mandatory = $false)]
        [int]$Depth = 20,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [string]$Encoding = "UTF8"
    )
    
    Write-PSFMessage -Level Verbose -FunctionName "Write-JsonFile" -Message "Writing JSON file: $Path"
    
    # Проверяем, существует ли файл и нужно ли его перезаписывать
    if ((Test-Path -Path $Path) -and -not $Force) {
        Write-PSFMessage -Level Warning -FunctionName "Write-JsonFile" -Message "File already exists and -Force not specified: $Path"
        return $false
    }
    
    # Создаем директорию, если она не существует
    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -Path $directory)) {
        try {
            New-Item -Path $directory -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-PSFMessage -Level Verbose -FunctionName "Write-JsonFile" -Message "Created directory: $directory"
        }
        catch {
            Write-PSFMessage -Level Error -FunctionName "Write-JsonFile" -Message "Failed to create directory '$directory': $_"
            return $false
        }
    }
    
    try {
        # Преобразуем объект в JSON
        $jsonContent = $InputObject | ConvertTo-Json -Depth $Depth -ErrorAction Stop
        
        # Записываем JSON в файл
        $jsonContent | Out-File -FilePath $Path -Encoding $Encoding -Force -ErrorAction Stop
        
        Write-PSFMessage -Level Verbose -FunctionName "Write-JsonFile" -Message "Successfully wrote JSON file: $Path"
        return $true
    }
    catch {
        Write-PSFMessage -Level Error -FunctionName "Write-JsonFile" -Message "Failed to write JSON file '$Path': $_"
        return $false
    }
}

function ConvertFrom-JsonSafe {
    <#
    .SYNOPSIS
        Безопасно преобразует строку JSON в объект.
    .DESCRIPTION
        Преобразует строку JSON в объект с обработкой ошибок и возвращает результат парсинга.
    .PARAMETER Json
        Строка JSON для парсинга.
    .PARAMETER Depth
        Глубина вложенности JSON-объектов для парсинга. По умолчанию: 20.
    .PARAMETER DefaultValue
        Значение по умолчанию, возвращаемое при ошибке парсинга.
    .PARAMETER SuppressErrors
        Подавляет вывод ошибок в лог при неудачном парсинге.
    .EXAMPLE
        $data = ConvertFrom-JsonSafe -Json '{"name":"John","age":30}'
        Парсит JSON-строку в объект.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Json,
        
        [Parameter(Mandatory = $false)]
        [int]$Depth = 20,
        
        [Parameter(Mandatory = $false)]
        [object]$DefaultValue = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$SuppressErrors
    )
    
    if ([string]::IsNullOrWhiteSpace($Json)) {
        if (-not $SuppressErrors) {
            Write-PSFMessage -Level Warning -FunctionName "ConvertFrom-JsonSafe" -Message "Empty JSON string provided"
        }
        return $DefaultValue
    }
    
    try {
        $result = $Json | ConvertFrom-Json -Depth $Depth -ErrorAction Stop
        return $result
    }
    catch {
        if (-not $SuppressErrors) {
            Write-PSFMessage -Level Warning -FunctionName "ConvertFrom-JsonSafe" -Message "Failed to parse JSON string: $_"
        }
        return $DefaultValue
    }
}

function New-JsonObject {
    <#
    .SYNOPSIS
        Создает новый JSON-объект.
    .DESCRIPTION
        Создает новый объект с указанными свойствами для последующей сериализации в JSON.
    .PARAMETER Properties
        Хэш-таблица свойств объекта.
    .EXAMPLE
        $jsonObj = New-JsonObject -Properties @{name = "John"; age = 30}
        Создает объект с свойствами name и age.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Properties
    )
    
    $object = New-Object PSObject
    
    foreach ($key in $Properties.Keys) {
        Add-Member -InputObject $object -MemberType NoteProperty -Name $key -Value $Properties[$key]
    }
    
    return $object
}

function Add-JsonProperty {
    <#
    .SYNOPSIS
        Добавляет свойство к существующему JSON-объекту.
    .DESCRIPTION
        Добавляет новое свойство к уже существующему объекту.
    .PARAMETER InputObject
        Объект, к которому добавляется свойство.
    .PARAMETER Name
        Имя добавляемого свойства.
    .PARAMETER Value
        Значение добавляемого свойства.
    .EXAMPLE
        $jsonObj = Add-JsonProperty -InputObject $jsonObj -Name "country" -Value "USA"
        Добавляет свойство country к объекту $jsonObj.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    
    Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value -Force
    return $InputObject
}

function Update-JsonFileProperty {
    <#
    .SYNOPSIS
        Обновляет свойство в JSON-файле.
    .DESCRIPTION
        Читает JSON-файл, обновляет указанное свойство и записывает обновленный JSON обратно в файл.
    .PARAMETER Path
        Путь к JSON-файлу.
    .PARAMETER Property
        Имя свойства для обновления.
    .PARAMETER Value
        Новое значение свойства.
    .PARAMETER Force
        Создает файл, если он не существует.
    .EXAMPLE
        Update-JsonFileProperty -Path "config.json" -Property "apiKey" -Value "new-api-key"
        Обновляет свойство apiKey в файле config.json.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [Parameter(Mandatory = $true)]
        [object]$Value,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    Write-PSFMessage -Level Verbose -FunctionName "Update-JsonFileProperty" -Message "Updating property '$Property' in JSON file: $Path"
    
    # Проверяем, существует ли файл
    if (-not (Test-Path -Path $Path)) {
        if (-not $Force) {
            Write-PSFMessage -Level Warning -FunctionName "Update-JsonFileProperty" -Message "File not found and -Force not specified: $Path"
            return $false
        }
        
        # Создаем новый JSON-объект вместо fallback логики
        $newObject = New-JsonObject -Properties @{$Property = $Value}
        return Write-JsonFile -Path $Path -InputObject $newObject -Force
    }
    
    # Читаем существующий JSON
    $json = Read-JsonFile -Path $Path
    if ($null -eq $json) {
        Write-PSFMessage -Level Warning -FunctionName "Update-JsonFileProperty" -Message "Failed to read JSON file: $Path"
        return $false
    }
    
    # Обновляем свойство
    try {
        if ($json -is [PSCustomObject]) {
            # Обновляем свойство PSCustomObject
            return Update-JsonPsCustomObjectProperty -Object $json -Path $Path -Property $Property -Value $Value
        }
        elseif ($json -is [System.Collections.IDictionary]) {
            # Обновляем свойство хэш-таблицы
            return Update-JsonDictionaryProperty -Dictionary $json -Path $Path -Property $Property -Value $Value
        }
        else {
            Write-PSFMessage -Level Warning -FunctionName "Update-JsonFileProperty" -Message "JSON object is not a PSCustomObject or IDictionary"
            return $false
        }
    }
    catch {
        Write-PSFMessage -Level Error -FunctionName "Update-JsonFileProperty" -Message "Failed to update property '$Property': $_"
        return $false
    }
}

function Update-JsonPsCustomObjectProperty {
    <#
    .SYNOPSIS
        Обновляет свойство объекта PSCustomObject и записывает его в файл.
    .DESCRIPTION
        Вспомогательная функция для Update-JsonFileProperty, обновляет свойство объекта PSCustomObject
        и записывает обновленный объект в JSON-файл.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Object,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    
    if ($Object.PSObject.Properties.Name -contains $Property) {
        $Object.$Property = $Value
    }
    else {
        Add-Member -InputObject $Object -MemberType NoteProperty -Name $Property -Value $Value
    }
    
    # Записываем обновленный JSON обратно в файл
    return Write-JsonFile -Path $Path -InputObject $Object -Force
}

function Update-JsonDictionaryProperty {
    <#
    .SYNOPSIS
        Обновляет свойство хэш-таблицы и записывает его в файл.
    .DESCRIPTION
        Вспомогательная функция для Update-JsonFileProperty, обновляет свойство хэш-таблицы
        и записывает обновленную хэш-таблицу в JSON-файл.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Dictionary,
        
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [Parameter(Mandatory = $true)]
        [object]$Value
    )
    
    $Dictionary[$Property] = $Value
    
    # Записываем обновленный JSON обратно в файл
    return Write-JsonFile -Path $Path -InputObject $Dictionary -Force
}
