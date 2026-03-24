# SonarQube Server Scripts

This repository contains scripts that can be used on SonarQube Server.

## Scripts

### Get SonarQube Server Background tasks

[`Get-SqsBackgroundTasks.ps1`](src/Get-SqsBackgroundTasks.ps1)

Example execution:
```
Get-SqsBackgroundTasks.ps1 -SonarHostUrl "https://sonarqube.example.com" -SonarToken "squ_xxxxxxxxxxxx" -OutputDirectory './bg-tasks-output'
```

Notes:
- ⚠️ **This script requires PowerShell 7.4 or newer!**
- The `-SonarHostUrl` parameter can be read from an environment variable: `SONAR_HOST_URL`
- The `-SonarToken` parameter can be read from an environment variable: `SONAR_TOKEN`
    - The token must belong to a user with the global **administer system** permission.
- The `-OutputDirectory` parameter is optional. The default output directory is `output`.
- Use the `-BasicAuthentication` parameter if running on SonarQube Server 9.9.
- The script gets the pages from the `api/ce/activity` in parallel (5 parallel tasks by default)

### Apply permission templates to matching projects

The `ApplyPermissionTemplates` automatically applies permission templates to the projects that match based on the defined *project key pattern*.

The script performs the following:
- Get all permission templates and their configuration from the specified SonarQube Server instance.
- Get all project keys from the specified SonarQube Server instance.
- Find all project keys that match a permission template.
- Validate that all matching keys correspond to one template only.
- Apply the permission templates to all matching projects.

The steps to run these scripts are as follow:
1. Clone this repository (if not already done):
   ```
   git clone https://github.com/lukas-frystak-sonarsource/sonarqube-server-scripts.git
   ```
1. Run the script:\
   Notes:
   - The script must be executed with the global administer permission.
   - The `OnlyValidateTemplates` is optional and tells the script to not apply any templates. Only validation is executed to make sure the permission template configuration is correct. The validation is executed even if this parameter is not set. *Do not set this option once the templates should be applied templates.*
   - The `PrintProjectAssignments` is optional and results in all projects being listed in the output under their corresponding permissoin template.
   - Use the `DebugLog` (optional) option to log additional debug messages.
   ```
   ApplyPermissionTemplates.ps1 `
      -SonarQubeUrl <SONARQUBE_URL> `
      -SonarQubeToken <SONARQUBE_TOKEN> `
      -OnlyValidateTemplates `
      -PrintProjectAssignments `
      -DebugLog
   ```

#### Filter projects for applying templates by project tags

By default, all available templates are matched and applied to all SonarQube Server projects. However, in some cases, it may be desirable to only apply permission templtates to a subset of SonarQube Server projects. In such cases, it is possible to filter the projects to which templates are applied by their SonarQube Sever tags. The script accepts an array of tags. For Example:
```
./ApplyPermissionTemplates.ps1 `
   -SonarQubeUrl <SONARQUBE_URL> `
   -SonarQubeToken <SONARQUBE_TOKEN> `
   -OnlyValidateTemplates `
   -PrintProjectAssignments `
   -DebugLog `
   -ProjectTags @("department-1", "project-group-A")
```

The above command will only apply to templates to projects that have either of the specified tags: `department-1` or `project-group-A`. 
