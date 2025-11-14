param(
    [string]$InputFilesDirectory = "output"
)

#
# FUNCTIONS
#
function Resolve-DirectoryPath {
    param(
        [string]$DirectoryPath
    )

    if ([System.IO.Path]::IsPathRooted($DirectoryPath)) {
        # Path is absolute, use it as is
        $resolvedDirectory = $DirectoryPath
    }
    else {
        # Path is relative, join it with current directory
        $resolvedDirectory = Join-Path -Path (Get-Location) -ChildPath $DirectoryPath
    }

    return $resolvedDirectory
}

function Load-AllBackgroundTasks {
    param(
        [string]$Directory
    )

    Write-Host "Reading background tasks from: $Directory" -ForegroundColor Cyan

    # Get all JSON files in the output directory
    $files = Get-ChildItem -Path $Directory -Filter "*.json"

    if ($files.Count -eq 0) {
        Write-Error "No JSON files found in $Directory"
        exit 1
    }

    Write-Host "Found $($files.Count) file(s)" -ForegroundColor Cyan
    Write-Host ""

    # Initialize array to hold all tasks
    $allTasks = @()

    # Read each file and collect tasks
    foreach ($file in $files) {
        # Write-Host "Reading $($file.Name)..." -NoNewline
    
        $content = Get-Content -Path $file.FullName -Raw
        $json = $content | ConvertFrom-Json
    
        $taskCount = $json.tasks.Count
        $allTasks += $json.tasks
    
        # Write-Host " OK ($taskCount tasks)" -ForegroundColor Green
    }

    # Write-Host ""
    Write-Host "Successfully loaded all background tasks!" -ForegroundColor Green
    Write-Host "Total tasks: $($allTasks.Count)" -ForegroundColor Green
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

    return $allTasks
}

# Start stopwatch
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Resolve the input directory path
$resolvedInputDirectory = Resolve-DirectoryPath -DirectoryPath $InputFilesDirectory

# Check the input directory exists
if (-not (Test-Path -Path $resolvedInputDirectory)) {
    Write-Error "Input directory does not exist: $resolvedInputDirectory"
    exit 1
}

# Load all background tasks from the input files.
$allTasks = Load-AllBackgroundTasks -Directory $resolvedInputDirectory

Write-Host "Total time: $($stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff'))" -ForegroundColor Green