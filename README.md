# Enterprise-Security-Health-Check

## How to use
This is a collection of powershell scripts that can be used to quickly assess the security posture of an Enterprise AD/AzureAD environment. 

### AD-Healthcheck

Privileges required: Domain User

This runs as a standard user and checks all domains in the current forest. 
Although this script is read-only and safe, don't just run scripts off the internet on your domain - make sure you read and understand what is happening before running.

.\ad-healthcheck.ps1 > 'ad-healthcheck-output.txt'

The above command will discover all domains in the current forest and then take measurements based on certain KPIs, outputing all of the information into a text file for analysis.

### get-MFAStatus


Privileges required: Security Reader / Global Reader (If security reader doesn't work, elevate to global reader instead)

This is an update of the script originally released https://lazyadmin.nl/powershell/list-office365-mfa-status-powershell/ via https://github.com/ruudmens/LazyAdmin/blob/master/Office365/MFAStatus.ps1. 

This version does exactly the same thing but returns all Microsoft Online object properties instead of just a few. This allows you to view the license types assigned to users with/without each MFA method configured.

.\get-MFAStatus.ps1 | Export-CSV -path '.\mfastatus-output.csv'

The above command will run get-MFAStatus and export the results to a CSV file for analysis

