<#
.SYNOPSIS
    Analyze all background tasks from a SonarQube Server instance that were already fetched using Get-SqsBackgroundTasks.ps1.

.DESCRIPTION
    This script analyzes all background tasks from a SonarQube Server instance that were already fetched using Get-SqsBackgroundTasks.ps1.
    It processes the JSON files saved in the input files directory and provides various summaries and insights about the tasks.

.PARAMETER InputFilesDirectory
    The directory where input files are located. If not provided, defaults to "output".

.EXAMPLE
    AnalyzeSqsBackgroundTasks.ps1
    
.EXAMPLE
    AnalyzeSqsBackgroundTasks.ps1 -InputFilesDirectory "./bg-tasks-output"
    Processes files from the specified directory.
#>

param(
    [string]$InputFilesDirectory = "output"
)

# Set progress preference to improve performance and avoid progress bar interference
$ProgressPreference = "SilentlyContinue"

# Constants
# --- No Constants ---
$Global:highConcurrencyThreshold = 4

#
# TYPES
#
enum TaskEventType {
    Submit
    Start
    End
}

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

function GetBgTasksDateRange {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    $oldestTask = ($Tasks | Sort-Object -Property submittedAt | Select-Object -First 1)
    $newestTask = ($Tasks | Sort-Object -Property submittedAt -Descending | Select-Object -First 1)

    Write-Host ""
    Write-Host "Date Range:" -ForegroundColor Cyan
    Write-Host "  Oldest task submitted at: $(Get-Date $oldestTask.submittedAt -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor Gray
    Write-Host "  Newest task submitted at: $(Get-Date $newestTask.submittedAt -Format 'dd.MM.yyyy HH:mm:ss')" -ForegroundColor Gray
    Write-Host "  This covers:              $((Get-Date $newestTask.submittedAt).Subtract($(Get-Date $oldestTask.submittedAt)).TotalDays.ToString("0.0")) days" -ForegroundColor Gray

    #return [PSCustomObject]@{
    #    Oldest = $oldestTask.submittedAt
    #    Newest = $newestTask.submittedAt
    #}
}

function GetBgTasksTypeSummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    Write-Host ""
    Write-Host "Task Type Summary:" -ForegroundColor Cyan
    $Tasks | Group-Object -Property type | Select-Object -Property Name, Count | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Gray
    }
}

function GetBgTasksStatusSummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }
    
    Write-Host ""
    Write-Host "Task Status Summary:" -ForegroundColor Cyan
    $Tasks | Group-Object -Property status | Select-Object -Property Name, Count | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Gray
    }
}

function GetBgTasksSubmitterSummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    Write-Host ""
    Write-Host "Task Submitter Summary:" -ForegroundColor Cyan
    $Tasks | Group-Object -Property submitterLogin | Select-Object -Property Name, Count | Sort-Object Count -Descending | ForEach-Object {
        $submitter = if ([string]::IsNullOrWhiteSpace($_.Name)) { "system" } else { $_.Name }
        Write-Host "  $($submitter): $($_.Count)" -ForegroundColor Gray
    }
}

function GetBgTasksBranchTypeSummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    Write-Host ""
    Write-Host "Task Branch Type Summary:" -ForegroundColor Cyan
    $Tasks | Group-Object -Property branchType | Select-Object -Property Name, Count | Sort-Object Count -Descending | ForEach-Object {
        $branchType = if ([string]::IsNullOrWhiteSpace($_.Name)) { "system" } else { $_.Name }
        Write-Host "  $($branchType): $($_.Count)" -ForegroundColor Gray
    }
}

function GetBgTasksWarningsSummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    Write-Host ""
    Write-Host "Task Warning Count Summary (sorted by number of tasks with that warning count):" -ForegroundColor Cyan
    # The sorting here could be changed. Maybe we want to count by warningCount value, not by number of tasks with that warningCount
    $Tasks | Group-Object -Property warningCount | Select-Object -Property Name, Count | Sort-Object Count -Descending | ForEach-Object {
        Write-Host "  $($_.Name) warnings: $($_.Count) tasks" -ForegroundColor Gray
    }
}

function GetBgTasksReportFrequencySummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    Write-Host ""
    Write-Host "Top 10 Projects by REPORT Task Frequency:" -ForegroundColor Cyan
    $Tasks | Where-Object { $_.type -eq "REPORT" } | Group-Object -Property componentKey | Select-Object -Property Name, Count | Sort-Object Count -Descending | Select-Object -First 10 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Gray
    }
}

function GetBgTasksConcurrencySummary {
    param(
        [array]$Tasks
    )

    if ($Tasks.Count -eq 0) {
        Write-Error "No tasks provided for date range analysis."
        return $null
    }

    Write-Host ""
    Write-Host "Concurrent Task Analysis:" -ForegroundColor Cyan

    # Create events for task start and end times
    $events = @()

    foreach ($task in $Tasks) {
        # There is a mistake here - the properties used for start and end times are wrong
        $submittedTime = [datetime]$task.submittedAt
        $startTime = [datetime]$task.startedAt
        # The API returns timestamps rounded to a second. Use executionTimeMs to calculate end time to get more precise end time.
        $endTime = [datetime]$task.startedAt.AddMilliseconds($task.executionTimeMs)

        # Add submitted event (+1 concurrent task)
        #$events += [PSCustomObject]@{
        #    Time   = $submittedTime
        #    Type   = [TaskEventType]::Submit
        #    TaskId = $task.id
        #}

        # Add start event (+1 concurrent task)
        $events += [PSCustomObject]@{
            Time   = $startTime
            Type   = [TaskEventType]::Start
            TaskId = $task.id
        }
    
        # Add end event (-1 concurrent task)
        $events += [PSCustomObject]@{
            Time   = $endTime
            Type   = [TaskEventType]::End
            TaskId = $task.id
        }
    }

    # Sort and group events by time.
    # Because the time stamps are rounded to a second, quite a few events happen at the exact same time.
    # So the processing needs to be done for each time point, not for each event individually.
    $groupedEventsByTime = $($events | Sort-Object Time | Group-Object Time)
    $totalEvents = $events.Count
    # $groupedEventsByTime
    
    # Calculate concurrent tasks at each point in time
    $currentConcurrent = 0
    $maxConcurrent = 0
    $maxConcurrentTime = $null
    $concurrencyLevels = @{}
    $highConcurrencyPeriods = @()
    $highConcurrencyStart = $null
    
    foreach ($timeStamp in $groupedEventsByTime) {
        foreach ($taskEvent in $timeStamp.Group) {
            if ($taskEvent.Type -eq [TaskEventType]::Start) {
                $currentConcurrent++
                #Write-Host "Start Task $($taskEvent.TaskId) at $($taskEvent.Time.ToString('dd.MM.yyyy HH:mm:ss.fff')): $currentConcurrent concurrent tasks" -ForegroundColor DarkGray
            }
            elseif ($taskEvent.Type -eq [TaskEventType]::End) {
                $currentConcurrent--
                #Write-Host "End   Task $($taskEvent.TaskId) at $($taskEvent.Time.ToString('dd.MM.yyyy HH:mm:ss.fff')): $currentConcurrent concurrent tasks" -ForegroundColor DarkGray
            }
        }

        if ($currentConcurrent -gt $maxConcurrent) {
            $maxConcurrent = $currentConcurrent
            $maxConcurrentTime = $taskEvent.Time
        }

        # Print current concurrency at this time point
        # "$($timeStamp.Group[0].Time), $currentConcurrent" >> concurrency-points.csv

        # Track how often each concurrency level occurs
        if (-not $concurrencyLevels.ContainsKey($currentConcurrent)) {
            $concurrencyLevels[$currentConcurrent] = 0
        }
        $concurrencyLevels[$currentConcurrent]++

        # Track high concurrency periods
        # When we cross to or above the threshold, record the start time.
        # When we drop below the threshold and we are currently tracking a high concurrency period, record the period.
        if (($currentConcurrent -ge $Global:highConcurrencyThreshold) -and ($null -eq $highConcurrencyStart)) {
            $highConcurrencyStart = $timeStamp.Group[0].Time
        }
        elseif (($currentConcurrent -lt $Global:highConcurrencyThreshold) -and ($null -ne $highConcurrencyStart)) {
            $highConcurrencyPeriods += [PSCustomObject]@{
                Start    = $highConcurrencyStart
                End      = $timeStamp.Group[0].Time
                Duration = $timeStamp.Group[0].Time.Subtract($highConcurrencyStart).TotalMilliseconds
            }

            $highConcurrencyStart = $null
        }
    }

    Write-Host ""
    Write-Host "  Maximum concurrent tasks: $maxConcurrent" -ForegroundColor Yellow
    Write-Host "  Occurred at: $(Get-Date $maxConcurrentTime -Format 'dd.MM.yyyy HH:mm:ss.fff')" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Concurrency Level Distribution:" -ForegroundColor Cyan
    $concurrencyLevels.GetEnumerator() | Sort-Object Key | ForEach-Object {
        $percentage = [math]::Round(($_.Value / $totalEvents) * 100, 2)
        Write-Host "    $($_.Key) tasks running: $($_.Value) occurrences ($percentage%)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "  High Concurrency Periods (>= $($Global:highConcurrencyThreshold) tasks):" -ForegroundColor Cyan

    if ($highConcurrencyPeriods.Count -gt 0) {
        #$highConcurrencyPeriods | Sort-Object Start -Descending | Select-Object -First 10 | ForEach-Object {
        $highConcurrencyPeriods | Sort-Object Start -Descending | ForEach-Object {
            $durationStr = "$([math]::Round($_.Duration, 2)) milliseconds"
            $color = if ($_.Duration -gt 1000) { "Gray" } else { "DarkGray" }
            Write-Host "    $(Get-Date $_.Start -Format 'dd.MM.yyyy HH:mm:ss') - $(Get-Date $_.End -Format 'dd.MM.yyyy HH:mm:ss') ($durationStr)" -ForegroundColor $color
        }
    }
    else {
        Write-Host "    No periods found with >= $($Global:highConcurrencyThreshold) concurrent tasks" -ForegroundColor Gray
    }
}

#
# SCRIPT
#

# Resolve the input directory path
$resolvedInputDirectory = Resolve-DirectoryPath -DirectoryPath $InputFilesDirectory

# Check the input directory exists
if (-not (Test-Path -Path $resolvedInputDirectory)) {
    Write-Error "Input directory does not exist: $resolvedInputDirectory"
    exit 1
}

# Load all background tasks from the input files.
$allTasks = Load-AllBackgroundTasks -Directory $resolvedInputDirectory

# Display various summaries and analyses
GetBgTasksDateRange -Tasks $allTasks
GetBgTasksTypeSummary -Tasks $allTasks
GetBgTasksStatusSummary -Tasks $allTasks
GetBgTasksSubmitterSummary -Tasks $allTasks
GetBgTasksBranchTypeSummary -Tasks $allTasks
GetBgTasksWarningsSummary -Tasks $allTasks
GetBgTasksReportFrequencySummary -Tasks $allTasks
GetBgTasksConcurrencySummary -Tasks $allTasks
