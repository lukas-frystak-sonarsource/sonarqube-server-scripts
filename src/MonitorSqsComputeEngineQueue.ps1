param(
    [string]$SonarHostUrl,
    [string]$SonarToken
)

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

# Make API request
$headers = @{
    "Authorization" = "Bearer $SonarToken"
}

$apiUrl = "$SonarHostUrl/api/ce/activity_status"

while ($true) {
    $response = Invoke-WebRequest -Uri $apiUrl -Method Get -Headers $headers -UseBasicParsing -ErrorAction Stop
    $responseJson = $response.Content
    $responseObject = $responseJson | ConvertFrom-Json
    $responseObject
    Start-Sleep -Seconds 1
}
