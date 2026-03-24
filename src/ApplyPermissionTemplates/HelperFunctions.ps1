# This script contains helper functions for handling exceptions in PowerShell scripts.

# HandleException helps to manage errors that occur during HTTP requests, particularly when interacting with a SonarQube API.
function HandleException {
    param (
        [System.Management.Automation.ErrorRecord]$errRecord
    )
    
    # Write an empty line for better readability in the output
    Write-Host ""

    # Get HTTP response/status code from the error record
    $statusCode = $errRecord.Exception.Response.StatusCode.value__
        
    # Handle the different cases based on the status code
    if ($null -eq $statusCode) {
        Write-Error -Message "Error with no status code returned when running the HTTP request!" -Exception $errRecord.Exception
    }
    elseif (($statusCode -eq 401) -or ($statusCode -eq 403)) {
        Write-Error -Message "Unauthorized to execute request: $($errRecord.TargetObject.RequestUri)." -Exception $errRecord.Exception
    }
    else {
        Write-Error -Message "Unexpected status code - investigate! (Status code: $statusCode)" -Exception $errRecord.Exception
    }    

    # Print error details to the console
    Write-Host ""
    Write-Host "Error details:"
    Write-Host "-> ErrorID:    $($errRecord.Exception.ErrorId)"
    Write-Host "-> Message:    $($errRecord.Exception.Message)"
    Write-Host "-> Source:     $($errRecord.Exception.Source)"
    Write-Host ""
    Write-Host "-> InnerEx:"
    Write-Host "$($errRecord.Exception.InnerException)"
    Write-Host ""
    Write-Host "-> StackTrace:"
    Write-Host "$($errRecord.Exception.StackTrace)"
    Write-Host ""
    Write-Host "-> Printing raw error record:"
    Write-Host $errRecord
    Write-Host ""
    Exit 1
}