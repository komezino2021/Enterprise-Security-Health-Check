# Connect to Azure AD
if ((Get-Module -ListAvailable -Name azureadpreview) -eq $null)
{
  Write-Host "azureadpreview Module is required, do you want to install it?" -ForegroundColor Yellow
      
  $install = Read-Host Do you want to install module? [Y] Yes [N] No 
  if($install -match "[yY]") 
  { 
    Write-Host "Installing azureadpreview module" -ForegroundColor Cyan
    Install-Module azureadpreview -AllowClobber -Force
  } 
  else
  {
	  Write-Error "Please install azureadpreview module."
  }
}

if ((Get-Module -ListAvailable -Name azureadpreview) -ne $null) 
{
	Connect-AzureAD
}
else{
  Write-Error "Please install azureadpreview module."
}

$OutputPath = '.\output'
$now = Get-Date -Format "yyyy-MM-dd-HH-mm"

Write-Output ""
Write-Output "Get all Azure AD devices which haven't authenticated in 180 days"
Write-Output ""
Get-AzureADDevice -All:$true | Where {$_.ApproximateLastLogonTimeStamp -le (Get-Date).AddDays(-180)} | where {$_.ApproximateLastLogonTimeStamp -ne $null } | select * |Export-csv -Path "$($OutputPath)\$($now)-Stale-Azure-Devices.csv" -NoTypeInformation


$AllPolicies = Get-AzureADMSConditionalAccessPolicy
foreach ($Policy in $AllPolicies)
{
	Write-host "Exporting $($Policy.DisplayName)"


    $arr = @()
    ForEach($App in $Policy.Conditions.Applications.IncludeApplications){
        If($App -ne 'All'){
            $AppName=Get-AzureADApplication -Filter "AppId eq '$App'"
            $arr += "$($App)[$($AppName.DisplayName)]"
        }else{
            $arr += "$($App)"
        }
    }
    $Policy.Conditions.Applications.IncludeApplications = $arr


    $arr = @()
    ForEach($App in $Policy.Conditions.Applications.ExcludeApplications){
        If($App -ne 'All'){
            $AppName=Get-AzureADApplication -Filter "AppId eq '$App'"
            $arr += "$($App)[$($AppName.DisplayName)]"

        }else{
            $arr += "$($App)"
        }
    }
    $Policy.Conditions.Applications.ExcludeApplications = $arr

    $arr = @()
    ForEach($User in $Policy.Conditions.Users.IncludeUsers){
        If($User -ne 'All' -and $User -ne 'GuestsOrExternalUsers'){
            $UserName=Get-AzureADUser -Filter "ObjectId eq '$User'"
            $arr += "$($User)[$($UserName.DisplayName)]"
        }else{
            $arr += "$($User)"
        }
    }
    $Policy.Conditions.Users.IncludeUsers = $arr

    $arr = @()
    ForEach($User in $Policy.Conditions.Users.ExcludeUsers){
        If($User -ne 'All' -and $User -ne 'GuestsOrExternalUsers'){
            $UserName=Get-AzureADUser -Filter "ObjectId eq '$User'"
            $arr += "$($User)[$($UserName.DisplayName)]"
            
        }else{
            $arr += "$($User)"
        }
        
    }
    $Policy.Conditions.Users.ExcludeUsers = $arr

    $arr = @()
    ForEach($Group in $Policy.Conditions.Users.IncludeGroups){
        If($Group -ne 'All'){
            $GroupName=Get-AzureADGroup -Filter "ObjectId eq '$Group'"
            $arr += "$($Group)[$($GroupName.DisplayName)]"
            
        }else{
            $arr += "$($Group)"
        }

    }
    $Policy.Conditions.Users.IncludeGroups = $arr

    $arr = @()
    ForEach($Group in $Policy.Conditions.Users.ExcludeGroups){
        If($Group -ne 'All'){
            $GroupName=Get-AzureADGroup -Filter "ObjectId eq '$Group'"
            $arr += "$($Group)[$($GroupName.DisplayName)]"
        }else{
            $arr += "$($Group)"
        }
    }
    $Policy.Conditions.Users.ExcludeGroups

    $arr = @()
    ForEach($Role in $Policy.Conditions.Users.IncludeRoles){
        If($Role -ne 'All'){
            $RoleName=Get-AzureADMSRoleDefinition -Id $Role
            $arr += "$($Role)[$($RoleName.DisplayName)]"
        }else{
            $arr += "$($Role)"
        }
    }
    $Policy.Conditions.Users.IncludeRoles = $arr

    $arr = @()
    ForEach($Role in $Policy.Conditions.Users.ExcludeRoles){
        If($Role -ne 'All'){
            $RoleName=Get-AzureADMSRoleDefinition -Id $Role
            $arr += "$($Role)[$($RoleName.DisplayName)]"
        }else{
            $arr += "$($Role)"
        }
    }
    $Policy.Conditions.Users.ExcludeRoles= $arr

    $Policy | ConvertTo-Json | Out-File "$($OutputPath)\$($now)-Conditional-Access-Policy-$($Policy.Id).json"


}

$Tenant = Get-AzTenant
$TenantId = $Tenant.Id



if ((Get-Module -ListAvailable -Name AzureADIncidentResponse) -eq $null)
{
  Write-Host "AzureADIncidentResponse Module is required, do you want to install it?" -ForegroundColor Yellow
      
  $install = Read-Host Do you want to install module? [Y] Yes [N] No 
  if($install -match "[yY]") 
  { 
    Write-Host "Installing AzureADIncidentResponse module" -ForegroundColor Cyan
    Install-Module AzureADIncidentResponse -AllowClobber -Force
  } 
  else
  {
	  Write-Error "Please install azureadpreview module."
  }
}

Import-Module AzureADIncidentResponse

Connect-AzureADIR $TenantId

Write-Output ""
Write-Output "Get permanent Azure AD Privileged Role Assignments "
Write-Output ""

Get-AzureADIRPrivilegedRoleAssignment $TenantId | Export-Csv -Path "$($OutputPath)\$($now)-Permanent-Azure-AD-Privileged-Role-Assignments.csv" -NoTypeInformation