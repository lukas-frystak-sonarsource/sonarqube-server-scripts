# Script parameters
param (
    [Parameter(Mandatory = $true)][string]$SonarQubeUrl,
    [Parameter(Mandatory = $true)][string]$SonarQubeToken,
    [string[]]$ProjectTags = $null,
    [switch]$OnlyValidateTemplates = $false,
    [switch]$DebugLog = $false,
    [switch]$PrintProjectAssignments = $false,
    [string]$Organization = $null
)

# Dot-source other PowerShell files containing classes and helper functions
. ./HelperFunctions.ps1
. ./PermissionTemplatesHandler.ps1

##################################################################################################################################
##################################################################################################################################
# Validate input
if ($SonarQubeUrl -like "*sonarcloud*" -and [string]::IsNullOrEmpty($Organization)) {
    Write-Error "Organization parameter is required for SonarQube Cloud."
    Exit 1
}

if ($SonarQubeUrl -notlike "*sonarcloud*" -and -not [string]::IsNullOrEmpty($Organization)) {
    Write-Error "Organization parameter is not required for SonarQube Server."
    Exit 1
}

##################################################################################################################################
##################################################################################################################################
# Required setup
$SONARQUBE_URL = $SonarQubeUrl.TrimEnd('/')

# Authorization token must be passed in a header. - Bearer
$httpRequestHeaders = @{
    "Authorization" = "Bearer $SonarQubeToken"
}

# Set progeress preference
$ProgressPreference = "SilentlyContinue"

##################################################################################################################################
##################################################################################################################################

$permissionTemplatesHandler = [PermissionTemplatesHandler]::new(
    $SONARQUBE_URL,
    $httpRequestHeaders,
    $OnlyValidateTemplates,
    $DebugLog,
    $Organization
)

$permissionTemplatesHandler.GetPermissionTemplates()
$permissionTemplatesHandler.GetSonarQubeProjects()
$permissionTemplatesHandler.FilterProjectsByTags($ProjectTags)
$permissionTemplatesHandler.DoAssignments()
$permissionTemplatesHandler.ValidateAssignments()

if ($PrintProjectAssignments) {
    $permissionTemplatesHandler.PrintAssignments()
}

$permissionTemplatesHandler.ApplyTemplates()

if ($OnlyValidateTemplates) {
    Write-Output "Validation completed. No changes were made."
}
else {
    Write-Output "Permission templates applied successfully!"
}