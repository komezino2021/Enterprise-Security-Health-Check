# Enterprise-Security-Health-Check

This is a collection of powershell scripts that can be used to quickly assess the security posture of an Enterprise AD/AzureAD environment. I'll be updating this over time as more checks and reports are added. 

## How to use

Clone the git repository to your device then run each of the modules individually as described. 

### AD-Healthcheck

*Description:*
Runs lots of different checks against all domains in a the current Active Directory forest. (ForEach domain in forest). If you have more than one forest or are using domain trusts you'll need to run in all other forests/trusted domains to ensure you get full coverage.

*Privileges required:* Domain User

This runs as a standard user and checks all domains in the current forest. 
Although this script is read-only and safe, don't just run scripts off the internet on your domain - make sure you read and understand what is happening before running.

.\ad-healthcheck.ps1 > '.\output\ad-healthcheck-output.txt'

The above command will discover all domains in the current forest and then take measurements based on certain KPIs, outputing all of the information into a text file for analysis.

### get-MFAStatus

*Description:*
This exports the MFA registration status and all other properties for all users in Azure Active Directory. Use it to see which accounts haven't yet registered a form of multi-factor authentication and who they belong to.

*Privileges required:* Security Reader / Global Reader (If security reader doesn't work, elevate to global reader instead)

This is an update of the script originally released https://lazyadmin.nl/powershell/list-office365-mfa-status-powershell/ via https://github.com/ruudmens/LazyAdmin/blob/master/Office365/MFAStatus.ps1. 

This version does exactly the same thing but returns all Microsoft Online object properties instead of just a few. This allows you to view the license types assigned to users with/without each MFA method configured.

.\get-MFAStatus.ps1 | Export-CSV -path '.\output\mfastatus-output.csv'

The above command will run get-MFAStatus and export the results to a CSV file for analysis

### azure-ad-healthcheck.ps1

*Description:*
This exports all of your Azure AD Conditional Access policies to json files, reports stale azure-ad devices (not authenticated for 180 days), and creates a csv with all Azure AD admin accounts and groups and their assigned roles.

*Privileges required:* Security Reader / Global Reader (If security reader doesn't work, elevate to global reader instead)

.\azure-ad-healthcheck.ps1

THe above command will create csv and json files prefixed with the current date in the .\output\ folder. 
(I'll probably update the other scripts to do this at some point in the future.)

