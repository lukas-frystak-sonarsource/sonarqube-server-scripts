# Script parameters
param (
    [Parameter(Mandatory = $true)][string]$SonarQubeUrl,
    [Parameter(Mandatory = $true)][string]$SonarQubeToken,
    [string[]]$ProjectTags = $null,
    [switch]$OnlyValidateTemplates = $false,
    [switch]$DebugLog = $false,
    [switch]$PrintProjectAssignments = $false

)

# Dot-source other PowerShell files containing classes and helper functions
. ./HelperFunctions.ps1
. ./PermissionTemplatesHandler.ps1

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

$permissionTemplatesHandler = [PermissionTemplatesHandler]::new($SONARQUBE_URL, $httpRequestHeaders, $OnlyValidateTemplates, $DebugLog)

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