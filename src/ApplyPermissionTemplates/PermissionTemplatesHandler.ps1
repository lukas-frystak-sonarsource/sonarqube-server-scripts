class PermissionTemplateInfo {
    # Properties
    [string]$Name
    [string]$Id
    [string]$ProjectKeyPattern
    [string[]]$MatchingProjectKeys = $null

    # Constructor
    PermissionTemplateInfo([string]$name, [string]$id, [string]$projectKeyPattern) {
        $this.Name = $name
        $this.Id = $id
        $this.ProjectKeyPattern = $projectKeyPattern
    }
}

class PermissionTemplatesHandler {
    # Properties
    [string]$SonarQubeUrl
    [hashtable]$HttpRequestHeaders
    [bool]$OnlyValidateTemplates
    [bool]$DebugLog
    # The hashtable is in the format: name, project key pattern
    [PermissionTemplateInfo[]]$Templates = $null
    [string[]]$ProjectKeys = $null

    # Constructors
    PermissionTemplatesHandler([string]$sonarQubeUrl, [hashtable]$httpRequestHeaders, [bool]$onlyValidateTemplates, [bool]$debugLog) {
        $this.SonarQubeUrl = $sonarQubeUrl
        $this.HttpRequestHeaders = $httpRequestHeaders
        $this.OnlyValidateTemplates = $onlyValidateTemplates
        $this.DebugLog = $debugLog
    }

    [void] GetPermissionTemplates() {
        Write-Host "Getting SonarQube permission templates..."
        $response = $null

        try {
            $response = Invoke-WebRequest -Headers $this.httpRequestHeaders `
                -Method GET `
                -Uri "$($this.SonarQubeUrl)/api/permissions/search_templates"
        }
        catch {
            HandleException $_
        }
        
        if ($null -ne $response) {
            $content = $response.Content | ConvertFrom-Json
            
            # Select only permission templates that can be assigned to prjects, i.e., those that have a project key pattern defined. We only need the name and the project key pattern.
            $permissionTemplateInfo = $content.permissionTemplates | Where-Object { -not [string]::IsNullOrEmpty($_.projectKeyPattern) } | ForEach-Object { $_ | Select-Object -Property Name, id, projectKeyPattern }
            if ($null -ne $permissionTemplateInfo) {
                foreach ($template in $permissionTemplateInfo) {
                    $this.Templates += [PermissionTemplateInfo]::new($template.name, $template.id, $template.projectKeyPattern)
                }
            }
        }
        
        if ($null -eq $this.Templates) {
            Write-Error "Permission templates info is invalid! Investigation needed..."
            Exit 1
        }

        Write-Host "  Got $($this.Templates.Count) permission templates."
    }
    
    [void] GetSonarQubeProjects() {
        Write-Host "Getting SonarQube projects..."
        $currentPage = 0
        $pageIndex, $pageSize, $totalItems = 0, 0, 0

        do {
            $response = $null
            $currentPage++

            try {
                $response = Invoke-WebRequest -Headers $this.httpRequestHeaders `
                    -Method GET `
                    -Uri "$($this.SonarQubeUrl)/api/projects/search?p=$currentPage&ps=500"
            }
            catch {
                HandleException $_
            }
    
            if ($null -eq $response) {
                Write-Error "Error getting projects (current page: $currentPage)! No response."
                Exit 1
            }

            $content = $response.Content | ConvertFrom-Json

            # Get paging information
            $pageIndex = $content.paging.pageIndex
            $pageSize = $content.paging.pageSize
            $totalItems = $content.paging.total

            # Get project data
            $components = $content.components
            $this.ProjectKeys += $components.key

            Write-Host "  Got projects - page $currentPage/$([Math]::Ceiling($totalItems / $pageSize))"

        } while (($pageIndex * $pageSize) -lt $totalItems)

        Write-Host "  Got $($this.ProjectKeys.Count) projects."	
    }
    
    [void] FilterProjectsByTags([string[]] $tags) {
        if ($null -ne $tags) {
            # Assume success and change it to false if any error occurs. Exit at the end of the method.
            $success = $true
            [string[]]$filteredProjectKeys = $null

            # Iterate over all projects
            foreach ($project in $this.ProjectKeys) {
                $response = $null

                try {
                    $response = Invoke-WebRequest -Headers $this.httpRequestHeaders `
                        -Method GET `
                        -Uri "$($this.SonarQubeUrl)/api/components/show?component=$project"
                }
                catch {
                    $success = $false
                    $statusCode = $_.Exception.Response.StatusCode.value__
                    if ($statusCode -eq 403) {
                        Write-Error "The SQ User running the script can't read project tags on project: $project. The user is most likely missing the 'Browse' permission on the project. Please check the permissions and try again."
                    }
                    else {
                        Write-Error "Error getting project tags for project '$project'! Status code: $statusCode"
                    }
                }
            
                if ($null -ne $response.Content) {
                    $projectTags = $($response.Content | ConvertFrom-Json).Component.Tags

                    if ($null -ne $projectTags) {
                        # Check that the project matches the tags
                        foreach ($tag in $tags) {
                            if ($projectTags -contains $tag) {
                                $filteredProjectKeys += $project
                            }
                        }
                    }
                }
            }

            if ($success) {
                $this.ProjectKeys = $filteredProjectKeys
                Write-Host "Filtered projects by tags: $($tags -join ', ') - $($this.ProjectKeys.Count) projects remaining."
            }
            else {
                Write-Error "Error filtering projects by tags! Investigation needed..."
                Exit 1
            }
        }
        else {
            Write-Host "  No tags to filter projects by."
        }
    }

    [void] DoAssignments() {
        foreach ($template in $this.Templates) {
            <# Notes:
                - This is the method that is called in SQ in Java:
                      public boolean matches(String regex) {
                        return Pattern.matches(regex, this);
                      }
                - In PowerShell, the matching behaves differently than in Java. PowerShell operators
                  check if the regular expression matches any part of the string, not necessarily the
                  entire string. To ensure the entire string matches the regex, we need to anchor the
                  regex with ^ (start of the string) and $ (end of the string).
            #>
            $match = $this.ProjectKeys | Select-String -Pattern $("^" + $template.projectKeyPattern + "$") -CaseSensitive
            $template.MatchingProjectKeys = $match
        }
    }
    
    [void] ValidateAssignments() {
        Write-Host "Validating project assignments to templates..."
        $assignmentsValid = $true

        # Create a hashtable to track project assignments
        $projectAssignments = @{}
        # Validate project uniqueness across permission templates
        foreach ($template in $this.Templates) {
            foreach ($project in $template.MatchingProjectKeys) {
                if ($projectAssignments.ContainsKey($project)) {
                    $assignmentsValid = $false
                    Write-Host "  Validation Failed: Project '$project' is assigned to multiple templates ('$($projectAssignments[$project])' and '$($template.Name)')."
                }
                else {
                    $projectAssignments[$project] = $template.Name
                }
            }
        }

        if ( $assignmentsValid) {
            Write-Host "  Validation Passed: All projects are uniquely assigned to one template."
        } 
        else {
            Write-Error "Validation Failed: Some projects match multiple templates."
            Exit 1
        }
    }

    [void] PrintAssignments() {
        Write-Host "Printing project assignments to templates..."
        foreach ($template in $this.Templates) {
            if ($null -eq $template.MatchingProjectKeys) {
                Write-Host "  No projects to apply template to! Template: $($template.Name)"
                continue
            }
            
            Write-Host "  Template: $($template.Name) (Project key pattern: $($template.ProjectKeyPattern)) matches $($template.MatchingProjectKeys.Count) projects"
            foreach ($projectKey in $template.MatchingProjectKeys) {
                Write-Host "    $projectKey"
            }
        }
    }
    
    [void] ApplyTemplates() {
        if ($this.OnlyValidateTemplates) {
            Write-Host "Only validating templates. No changes will be made."
            return
        }

        Write-Host "Applying SonarQube permission templates to their corresponding projects..."

        foreach ($template in $this.Templates) {
            if ($null -eq $template.MatchingProjectKeys) {
                Write-Host "  No projects to apply template to! Template: $($template.Name)"
                continue
            }
            
            if ($template.MatchingProjectKeys.Count -gt 1000) {
                Write-Error "    Too many projects to apply template to! Maximum is 1000. Template: $($template.Name)"
                continue
            }

            Write-Host "  Applying template: $($template.Name) to $($template.MatchingProjectKeys.Count) projects."

            $body = @{
                templateId = $template.Id
                qualifiers = "TRK"
                projects   = [string]::Join(',', $template.MatchingProjectKeys)
            }
        
            try {
                Invoke-WebRequest -Uri "$($this.SonarQubeUrl)/api/permissions/bulk_apply_template" `
                    -Method Post `
                    -Headers $this.HttpRequestHeaders `
                    -Body $body
            }
            catch {
                HandleException $_
            }
        }
    }
}