# SonarQube Server Scripts

This repository contains scripts that can be used on SonarQube Server.

## Scripts

### Get SonarQube Server Background tasks

[`Get-SqsBackgroundTasks.ps1`](src/Get-SqsBackgroundTasks.ps1)

Example execution:
```
Get-BackgroundTasks.ps1 -SonarHostUrl "https://sonarqube.example.com" -SonarToken "squ_xxxxxxxxxxxx" -OutputDirectory './bg-tasks-output'
```

Notes:
- ⚠️ **This script requires PowerShell 7.4 or newer!**
- The `-SonarHostUrl` parameter can be read from an environment variable: `SONAR_HOST_URL`
- The `-SonarToken` parameter can be read from an environment variable: `SONAR_TOKEN`
    - The token must belong to a user with the global **administer system** permission.
- The `-OutputDirectory` parameter is optional. The default output directory is `output`.
- Use the `-BasicAuthentication` parameter if running on SonarQube Server 9.9.
- The script gets the pages from the `api/ce/activity` in parallel (5 parallel tasks by default)