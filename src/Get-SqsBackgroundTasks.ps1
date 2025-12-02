<#
.SYNOPSIS
    Retrieves all background tasks from a SonarQube Server instance.

.DESCRIPTION
    This script fetches all background tasks from a SonarQube Server using the api/ce/activity endpoint.
    It handles pagination automatically and saves each page to a separate JSON file.
    Pages are fetched in parallel to improve performance.

.PARAMETER SonarHostUrl
    The base URL of the SonarQube Server instance. If not provided, uses the SONAR_HOST_URL environment variable.

.PARAMETER SonarToken
    The bearer token for authentication. If not provided, uses the SONAR_TOKEN environment variable.
    The token must belong to a user with system administration permission.

.PARAMETER OutputDirectory
    The directory where output files will be saved. If not provided, defaults to "output".

.PARAMETER ThrottleLimit
    The maximum number of parallel requests to execute simultaneously. Default is 5.
    Increase for faster downloads if your network and server can handle it.

.PARAMETER BasicAuthentication
    Use Basic Authentication instead of Bearer token for authentication. Required for SonarQube instances that do not support Bearer tokens (e.g., SonarQube 9.9).

.EXAMPLE
    .\Get-BackgroundTasks.ps1
    Uses environment variables SONAR_HOST_URL and SONAR_TOKEN with default throttle limit of 5

.EXAMPLE
    .\Get-BackgroundTasks.ps1 -SonarHostUrl "https://sonarqube.example.com" -SonarToken "squ_xxxxxxxxxxxx" -ThrottleLimit 20
    Uses provided parameters with 20 parallel requests
#>

param(
    [string]$SonarHostUrl,
    [string]$SonarToken,
    [string]$OutputDirectory = "output",
    [int]$ThrottleLimit = 5,
    [switch]$BasicAuthentication
)

# Set progress preference to improve performance and avoid progress bar interference
$ProgressPreference = "SilentlyContinue"

# Constants
$PAGE_SIZE = 250                          # Default page size for API calls (max 1000)
$OUTPUT_FILE_PREFIX = "background-tasks"  # Prefix for output files
$OUTPUT_FILE_EXTENSION = ".json"          # Extension for output files

# Get SonarQube host URL from parameter or environment variable
if ([string]::IsNullOrWhiteSpace($SonarHostUrl)) {
    $SonarHostUrl = $env:SONAR_HOST_URL
}

if ([string]::IsNullOrWhiteSpace($SonarHostUrl)) {
    Write-Error "SonarQube host URL is required. Provide it via -SonarHostUrl parameter or SONAR_HOST_URL environment variable."
    exit 1
}

# Get SonarQube token from parameter or environment variable
if ([string]::IsNullOrWhiteSpace($SonarToken)) {
    $SonarToken = $env:SONAR_TOKEN
}

if ([string]::IsNullOrWhiteSpace($SonarToken)) {
    Write-Error "SonarQube token is required. Provide it via -SonarToken parameter or SONAR_TOKEN environment variable."
    exit 1
}

# Remove trailing slash from URL if present
$SonarHostUrl = $SonarHostUrl.TrimEnd('/')

# Create output directory if it doesn't exist
if (-not (Test-Path -Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-Host "Created output directory: $OutputDirectory" -ForegroundColor Gray
}
else {
    Write-Host "Using existing output directory: $OutputDirectory" -ForegroundColor Gray
    # Remove existing background task files
    $existingFiles = Get-ChildItem -Path $OutputDirectory -Filter "$OUTPUT_FILE_PREFIX-page-*$OUTPUT_FILE_EXTENSION"
    if ($existingFiles.Count -gt 0) {
        $existingFiles | Remove-Item -Force
        Write-Host "Removed $($existingFiles.Count) existing background task files" -ForegroundColor Yellow
    }
}

Write-Host "Fetching background tasks from: $SonarHostUrl" -ForegroundColor Cyan
Write-Host "Page size: $PAGE_SIZE" -ForegroundColor Cyan
Write-Host "Throttle limit: $ThrottleLimit parallel requests" -ForegroundColor Cyan
Write-Host ""

# Start stopwatch
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Get only tasks executed before 5 minutes ago to avoid having the response include tasks that are still being processed.
# This might result in the paging shifting between requests and that would make the data inconsistent.
# So let's get all tasks up to a fixed point in time.
# The formatting of the string is a hack. It should be easier. But I am leaving it like this for now.
# SonarQube should be expecting ISO 8601 with RFC 822 timezone offset.
$dateTime = (Get-Date).AddMinutes(-5)
$maxExecutedAt = $dateTime.ToString("yyyy-MM-ddTHH:mm:ss") + $dateTime.ToString("zzz").Replace(":", "")
$maxExecutedAtEncoded = [Uri]::EscapeDataString($maxExecutedAt)

Write-Host "Fetching first page to determine total number of pages..." -ForegroundColor Cyan

# Fetch first page to get total count
$apiUrl = "$SonarHostUrl/api/ce/activity?maxExecutedAt=$maxExecutedAtEncoded&ps=$PAGE_SIZE&p=1"

if ($BasicAuthentication) {
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$($SonarToken):"))
    $headers = @{
        "Authorization" = "Basic $encodedCreds"
    }
}
else {
    $headers = @{
        "Authorization" = "Bearer $SonarToken"
    }
}

try {
    $response = Invoke-WebRequest -Uri $apiUrl -Method Get -Headers $headers -UseBasicParsing -ErrorAction Stop
    $responseJson = $response.Content
    $responseObject = $responseJson | ConvertFrom-Json
    
    # Save first page
    $outputFileName = "$OUTPUT_FILE_PREFIX-page-$((1).ToString("0000"))$OUTPUT_FILE_EXTENSION"
    $outputPath = Join-Path $OutputDirectory $outputFileName
    $responseJson | Set-Content -Path $outputPath -Encoding UTF8
    
    # Get paging information
    $totalTasks = $responseObject.paging.total
    $totalPages = [Math]::Ceiling($totalTasks / $PAGE_SIZE)
    $firstPageTaskCount = $responseObject.tasks.Count
    
    Write-Host "OK - Total tasks: $totalTasks, Total pages: $totalPages" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "FAILED" -ForegroundColor Red
    Write-Error "Failed to fetch data from SonarQube API: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Error "HTTP Status Code: $statusCode"
        
        if ($statusCode -eq 401) {
            Write-Error "Authentication failed. Please check your SONAR_TOKEN."
        }
        elseif ($statusCode -eq 403) {
            Write-Error "Access forbidden. Please ensure you have the required permissions (system administration or project administration)."
        }
    }
    
    exit 1
}

# If there's only one page, we're done. If there are 0 pages, it means there are no tasks and we are also done.
if ($totalPages -le 1) {
    $stopwatch.Stop()
    
    Write-Host "Successfully fetched all background tasks!" -ForegroundColor Green
    Write-Host "Total tasks retrieved: $firstPageTaskCount" -ForegroundColor Green
    Write-Host "Total pages saved: 1" -ForegroundColor Green
    Write-Host "Files saved in: $OutputDirectory" -ForegroundColor Green
    Write-Host "Total time: $($stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff'))" -ForegroundColor Green
    exit 0
}

# Fetch remaining pages in parallel
Write-Host "Fetching remaining $($totalPages - 1) pages in parallel..." -ForegroundColor Cyan

try {
    $results = 2..$totalPages | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        $pageNumber = $_
        $sonarUrl = $using:SonarHostUrl
        $token = $using:SonarToken
        $pageSize = $using:PAGE_SIZE
        $maxExecutedAtEnc = $using:maxExecutedAtEncoded
        $outDir = $using:OutputDirectory
        $filePrefix = $using:OUTPUT_FILE_PREFIX
        $fileExtension = $using:OUTPUT_FILE_EXTENSION
        
        # Build API URL
        $apiUrl = "$sonarUrl/api/ce/activity?maxExecutedAt=$maxExecutedAtEnc&ps=$pageSize&p=$pageNumber"
        
        # Make API request
        $headers = @{
            "Authorization" = "Bearer $token"
        }
        
        try {
            $response = Invoke-WebRequest -Uri $apiUrl -Method Get -Headers $headers -UseBasicParsing -ErrorAction Stop
            $responseJson = $response.Content
            $responseObject = $responseJson | ConvertFrom-Json
            
            # Save page to JSON file
            $outputFileName = "$filePrefix-page-$($pageNumber.ToString("0000"))$fileExtension"
            $outputPath = Join-Path $outDir $outputFileName
            $responseJson | Set-Content -Path $outputPath -Encoding UTF8
            
            # Return result for tracking
            [PSCustomObject]@{
                Page      = $pageNumber
                TaskCount = $responseObject.tasks.Count
                Success   = $true
                Error     = $null
            }
        }
        catch {
            # Return error for tracking
            [PSCustomObject]@{
                Page      = $pageNumber
                TaskCount = 0
                Success   = $false
                Error     = $_.Exception.Message
            }
        }
    }
    
    # Stop stopwatch
    $stopwatch.Stop()
    
    # Check for any failures
    $failures = $results | Where-Object { -not $_.Success }
    
    if ($failures.Count -gt 0) {
        Write-Host ""
        Write-Host "Some pages failed to download:" -ForegroundColor Red
        foreach ($failure in $failures) {
            Write-Host "  Page $($failure.Page): $($failure.Error)" -ForegroundColor Red
        }
        Write-Host ""
        Write-Error "Failed to fetch $($failures.Count) page(s). Please check the errors above."
        exit 1
    }
    
    # Calculate total tasks retrieved
    $allTasksCount = $firstPageTaskCount + ($results | Measure-Object -Property TaskCount -Sum).Sum
    
    Write-Host ""
    Write-Host "Successfully fetched all background tasks!" -ForegroundColor Green
    Write-Host "Total tasks retrieved: $allTasksCount" -ForegroundColor Green
    Write-Host "Total pages saved: $totalPages" -ForegroundColor Green
    Write-Host "Files saved in: $OutputDirectory" -ForegroundColor Green
    Write-Host "Total time: $($stopwatch.Elapsed.ToString('hh\:mm\:ss\.fff'))" -ForegroundColor Green
}
catch {
    Write-Error "An unexpected error occurred during parallel fetch: $($_.Exception.Message)"
    exit 1
}
