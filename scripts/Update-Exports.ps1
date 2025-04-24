# Update-Exports.ps1
$modulePath = ".\..\src\AnalyzeTTBot\AnalyzeTTBot.psd1"
$publicFunctions = Get-ChildItem -Path @(".\..\src\AnalyzeTTBot") -Recurse -Include *.ps1,*.psm1 |
                   ForEach-Object {
                       $content = Get-Content $_.FullName
                       $content | Select-String "function\s+([A-Z][a-z]+-[A-Z][a-z]+)" |
                       ForEach-Object { $_.Matches.Groups[1].Value }
                   } | Sort-Object -Unique

if (-not $publicFunctions) {
    Write-Warning "Не найдено публичных функций с синтаксисом Verb-Noun."
    $publicFunctions = @()
}

Update-ModuleManifest -Path $modulePath -FunctionsToExport $publicFunctions
Write-Host "Обновлен FunctionsToExport в $modulePath с функциями: $publicFunctions" -ForegroundColor Green