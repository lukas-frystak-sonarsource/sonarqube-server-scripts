###
### This script is a simple example of how to onboard a GitLab project to SonarQube using the SonarQube Server API.
### The script doesn't contain all possible error handling or edge case handling, but it provides a basic structure
### for how to interact with the SonarQube API to create a project linked to a GitLab repository.
###

$Global:SonarQubeUrl = $($Env:SONAR_HOST_URL).TrimEnd('/')
$Global:ApiAuth = "Authorization: Bearer $($Env:SONAR_TOKEN)"
$Global:CurlOptions = "-s"

# Step 1: Get the list of configured DevOps platforms
#         Types: github, gitlab, azure, bitbucket, bitbucketcloud
$dopSettings = $(curl -H $Global:ApiAuth $Global:CurlOptions "$($Global:SonarQubeUrl)/api/v2/dop-translation/dop-settings" | ConvertFrom-Json).dopSettings

# Choose the relevant DevOps platform settings for GitLab.
# In this example, only one GitLab configuration is expected, but this can be extended to support multiple.
$devOpsIntegrationId = $($dopSettings | Where-Object { $_.type -eq "gitlab" }).id
$devOpsIntegrationKey = $($dopSettings | Where-Object { $_.type -eq "gitlab" }).key

# Step 2 (Optional): List the repositories available in the GitLab integration to confirm the repository identifier.
# This step is optional but can be useful for debugging or confirming the repository identifier.
# This example doesn't handle pagination. If there are more than 100 repositories, additional API calls would be needed to retrieve all repositories.
$availableGitLabRepos = $(curl -H $Global:ApiAuth $Global:CurlOptions "$($Global:SonarQubeUrl)/api/alm_integrations/search_gitlab_repos?almSetting=$devOpsIntegrationKey&p=1&ps=100" | ConvertFrom-Json).repositories
# $availableGitLabRepos

# Step 3: Create the SonarQube project with the GitLab integration.
# 
# IMPORTANT NOTES:
# In case of GitLab projects, the repository identifier is typically the GitLab project ID (e.g., "55305514").
# This identifier is crucial for linking the SonarQube project to the correct GitLab repository.
#
$repositoryIdentifier = "45305840"                  # Replace with the actual GitLab project ID for your repository.
$projectKey = "gitlab-group:$repositoryIdentifier"  # Unique key for the SonarQube project (e.g., "my-gitlab-project")
$projectName = "My GitLab Project"                  # Name for the SonarQube project (e.g., "My GitLab Project")

$projectCreationBody = @"
{
  "projectKey": "$projectKey",
  "projectName": "$projectName",
  "devOpsPlatformSettingId": "$devOpsIntegrationId",
  "repositoryIdentifier": "$repositoryIdentifier",
  "monorepo": false
}
"@

# Create the SonarQube project. This API endpoint ensures that the project is created with the correct DevOps integration settings, linking it to the GitLab repository.
curl -H $Global:ApiAuth $Global:CurlOptions "$($Global:SonarQubeUrl)/api/v2/dop-translation/bound-projects" -XPOST -d $projectCreationBody -H "Content-Type: application/json"

$urlEncodedProjectKey = [System.Web.HttpUtility]::UrlEncode($projectKey)
$projectUrl = "$($Global:SonarQubeUrl)/dashboard?id=$urlEncodedProjectKey"
Write-Output ""
Write-Output "You can access the newly created SonarQube project at: $projectUrl"