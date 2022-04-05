  <#
.Synopsis
  Get the MFA status for all users or a single user.

.DESCRIPTION
  This script will get the Azure MFA Status for your users. You can query all the users, admins only or a single user.
   
	It will return the MFA Status, MFA type (

.NOTES
  Name: Get-MFAStatus
  Author: R. Mens - LazyAdmin.nl
  Version: 1.2
  DateCreated: jan 2021
  Purpose/Change: Fixed getting all Admins
	Thanks to: Anthony Bartolo

.LINK
  https://lazyadmin.nl

.EXAMPLE
  Get-MFAStatus

  Get the MFA Status of all enabled and licensed users and check if there are an admin or not

.EXAMPLE
  Get-MFAStatus -UserPrincipalName 'johndoe@contoso.com','janedoe@contoso.com'

  Get the MFA Status for the users John Doe and Jane Doe

.EXAMPLE
  Get-MFAStatus -withOutMFAOnly

  Get only the licensed and enabled users that don't have MFA enabled

.EXAMPLE
  Get-MFAStatus -adminsOnly

  Get the MFA Status of the admins only

.EXAMPLE
  Get-MsolUser -Country "NL" | ForEach-Object { Get-MFAStatus -UserPrincipalName $_.UserPrincipalName }

  Get the MFA status for all users in the Country The Netherlands. You can use a similar approach to run this
  for a department only.

.EXAMPLE
  Get-MFAStatus -withOutMFAOnly | Export-CSV c:\temp\userwithoutmfa.csv -noTypeInformation

  Get all users without MFA and export them to a CSV file
#>
[CmdletBinding(DefaultParameterSetName="Default")]
param(
  [Parameter(
    Mandatory = $false,
    ParameterSetName  = "UserPrincipalName",
    HelpMessage = "Enter a single UserPrincipalName or a comma separted list of UserPrincipalNames",
    Position = 0
    )]
  [string[]]$UserPrincipalName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "AdminsOnly"
  )]
  # Get only the users that are an admin
  [switch]$adminsOnly = $false,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "AllUsers"
  )]
  # Set the Max results to return
  [int]$MaxResults = 100000,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "Licenend"
  )]
  # Check only the MFA status of users that have license
  [switch]$IsLicensed = $true,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName  = "withOutMFAOnly"
  )]
  # Get only the users that don't have MFA enabled
  [switch]$withOutMFAOnly = $false,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false
  )]
  # Check if a user is an admin. Set to $false to skip the check
  [switch]$listAdmins = $true
)



# Connect to Msol
if ((Get-Module -ListAvailable -Name MSOnline) -eq $null)
{
  Write-Host "MSOnline Module is required, do you want to install it?" -ForegroundColor Yellow
      
  $install = Read-Host Do you want to install module? [Y] Yes [N] No 
  if($install -match "[yY]") 
  { 
    Write-Host "Installing MSOnline module" -ForegroundColor Cyan
    Install-Module MSOnline -Repository PSGallery -AllowClobber -Force
  } 
  else
  {
	  Write-Error "Please install MSOnline module."
  }
}

if ((Get-Module -ListAvailable -Name MSOnline) -ne $null) 
{
	Connect-MsolService
}
else{
  Write-Error "Please install Msol module."
}
  
# Get all licensed admins
$admins = $null

if (($listAdmins) -or ($adminsOnly)) {
  $admins = Get-MsolRole | %{$role = $_.name; Get-MsolRoleMember -RoleObjectId $_.objectid} | Where-Object {$_.isLicensed -eq $true} | select @{Name="Role"; Expression = {$role}}, DisplayName, EmailAddress | Sort-Object -Property EmailAddress -Unique
}

# Check if a UserPrincipalName is given
# Get the MFA status for the given user(s) if they exist
if ($PSBoundParameters.ContainsKey('UserPrincipalName')) {
  foreach ($user in $UserPrincipalName) {
		try {
      $MsolUser = Get-MsolUser -UserPrincipalName $user -ErrorAction Stop

      $Method = ""
      $MFAMethod = $MsolUser.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq $true} | Select-Object -ExpandProperty MethodType

      If (($MsolUser.StrongAuthenticationRequirements) -or ($MsolUser.StrongAuthenticationMethods)) {
        Switch ($MFAMethod) {
            "OneWaySMS" { $Method = "SMS token" }
            "TwoWayVoiceMobile" { $Method = "Phone call verification" }
            "PhoneAppOTP" { $Method = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $Method = "Authenticator app" }
        }
      }

      $AlternateEmailAddresses = ""
      ForEach ($AlternateEmailAddress in $MsolUser.AlternateEmailAddresses){
      $AlternateEmailAddresses = "$($AlternateEmailAddresses),$($AlternateEmailAddress)"}

      $AlternateMobilePhones = ""
      ForEach ($AlternateMobilePhone in $MsolUser.AlternateMobilePhones){
      $AlternateMobilePhones = "$($AlternateMobilePhones),$($AlternateMobilePhone)"}

      $AlternativeSecurityIds = ""
      ForEach ($AlternativeSecurityId in $MsolUser.AlternativeSecurityIds){
      $AlternativeSecurityIds = "$($AlternativeSecurityIds),$($AlternativeSecurityId)"}

      $DirSyncProvisioningErrors = ""
      ForEach ($DirSyncProvisioningError in $MsolUser.DirSyncProvisioningError){
      $DirSyncProvisioningErrors = "$($DirSyncProvisioningErrors),$($DirSyncProvisioningError)"}

      $IndirectLicenseErrors = ""
      ForEach ($IndirectLicenseError in $MsolUser.IndirectLicenseErrors){
      $IndirectLicenseErrors = "$($IndirectLicenseErrors),$($IndirectLicenseError)"}

      $licenseArray = $MsolUser.Licenses | foreach-Object {$_.AccountSkuId}
      $Licenses = ""
      ForEach ($License in $licenseArray){
      $Licenses = "$($Licenses),$($License)"}

      $ProxyAddresses = ""
      ForEach ($ProxyAddress in $MsolUser.ProxyAddresses){
      $ProxyAddresses = "$($ProxyAddresses),$($ProxyAddress)"}

      [PSCustomObject]@{
        DisplayName       = $MsolUser.DisplayName
        UserPrincipalName = $MsolUser.UserPrincipalName
        isAdmin           = if ($listAdmins -and $admins.EmailAddress -match $MsolUser.UserPrincipalName) {$true} else {"-"}
        MFAEnabled        = if ($MsolUser.StrongAuthenticationMethods) {$true} else {$false}
        MFAType           = $Method
		MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
        AlternateEmailAddresses = $AlternateEmailAddresses
        AlternateMobilePhones = $AlternateMobilePhones
        AlternativeSecurityIds = $AlternativeSecurityIds
        BlockCredential = $MsolUser.BlockCredential
        City = $MsolUser.City
        CloudExchangeRecipientDisplayType= $MsolUser.CloudExchangeRecipientDisplayType
        Country = $MsolUser.Country
        Department = $MsolUser.Department
        DirSyncProvisioningErrors = $DirSyncProvisioningErrors
        Errors = $MsolUser.Errors
        Fax = $MsolUser.Fax
        FirstName = $MsolUser.FirstName
        ImutableId = $MsolUser.ImutableId
        IndirectLicenseErrors = $IndirectLicenseErrors
        IsLicensed = $MsolUser.IsLicensed
        LastDirSyncTime = $MsolUser.LastDirSyncTime
        LastName = $MsolUser.LastName
        LastPasswordChangeTimestamp = $MsolUser.LastPasswordChangeTimestamp
        LicenseReconciliationNeeded = $MsolUser.LicenseReconciliationNeeded
        Licenses = $Licenses
        LiveId = $MsolUser.LiveId
        MSExchRecipientTypeDetails = $MsolUser.MSExchRecipientTypeDetails
        MSRtcSipDeploymentLocator = $MsolUser.MSRtcSipDeploymentLocator
        MSRtcSipPrimaryUserAddress = $MsolUser.MSRtcSipPrimaryUserAddress
        MobilePhone = $MsolUser.MobilePhone
        ObjectId =  $MsolUser.ObjectId
        Office = $MsolUser.Office
        OverallProvisioningStatus = $MsolUser.OverallProvisioningStatus
        PasswordNeverExpires = $MsolUser.PasswordNeverExpires
        PasswordResetNotRequiredDuringActivate = $MsolUser.PasswordResetNotRequiredDuringActivate
        PhoneNumber = $MsolUser.PhoneNumber
        PortalSettings= $MsolUser.PortalSettings
        PostalCode = $MsolUser.PostalCode
        PreferredDataLocation = $MsolUser.PreferredDataLocation
        PreferredLanguage = $MsolUser.PreferredLanguage
        ProxyAddresses = $ProxyAddresses
        ReleaseTrack = $MsolUser.ReleaseTrack
        SignInName = $MsolUser.SignInName
        SoftDeletionTimestamp = $MsolUser.SoftDeletionTimestamp 
        State = $MsolUser.State
        StreetAddress = $MsolUser.StreetAddress
        StrongPasswordRequired = $MsolUser.StrongPasswordRequired
        StsRefreshTokensValidFrom = $MsolUser.StsRefreshTokensValidFrom
        Title = $MsolUser.Title
        UsageLocation = $MsolUser.UsageLocation
        UserLandingPageIdentifierForO365Shell = $MsolUser.UserLandingPageIdentifierForO365Shell
        UserThemeIdentifierForO365Shell = $MsolUser.UserThemeIdentifierForO365Shell 
        UserType = $MsolUser.UserType
        ValidationStatus = $MsolUser.ValidationStatus
        WhenCreated = $MsolUser.WhenCreated

      }
    }
		catch {
			[PSCustomObject]@{
				DisplayName       = " - Not found"
				UserPrincipalName = $User
				isAdmin           = $null
				MFAEnabled        = $null
			}
		}
  }
}
# Get only the admins and check their MFA Status
elseif ($adminsOnly) {
  foreach ($admin in $admins) {
    $MsolUser = Get-MsolUser -ObjectId $admin.ObjectId | Sort-Object UserPrincipalName -ErrorAction Stop

    $MFAMethod = $MsolUser.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq $true} | Select-Object -ExpandProperty MethodType
    $Method = ""

    If (($MsolUser.StrongAuthenticationRequirements) -or ($MsolUser.StrongAuthenticationMethods)) {
        Switch ($MFAMethod) {
            "OneWaySMS" { $Method = "SMS token" }
            "TwoWayVoiceMobile" { $Method = "Phone call verification" }
            "PhoneAppOTP" { $Method = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $Method = "Authenticator app" }
        }
      }

    $AlternateEmailAddresses = ""
      ForEach ($AlternateEmailAddress in $MsolUser.AlternateEmailAddresses){
      $AlternateEmailAddresses = "$($AlternateEmailAddresses),$($AlternateEmailAddress)"}

      $AlternateMobilePhones = ""
      ForEach ($AlternateMobilePhone in $MsolUser.AlternateMobilePhones){
      $AlternateMobilePhones = "$($AlternateMobilePhones),$($AlternateMobilePhone)"}

      $AlternativeSecurityIds = ""
      ForEach ($AlternativeSecurityId in $MsolUser.AlternativeSecurityIds){
      $AlternativeSecurityIds = "$($AlternativeSecurityIds),$($AlternativeSecurityId)"}

      $DirSyncProvisioningErrors = ""
      ForEach ($DirSyncProvisioningError in $MsolUser.DirSyncProvisioningError){
      $DirSyncProvisioningErrors = "$($DirSyncProvisioningErrors),$($DirSyncProvisioningError)"}

      $IndirectLicenseErrors = ""
      ForEach ($IndirectLicenseError in $MsolUser.IndirectLicenseErrors){
      $IndirectLicenseErrors = "$($IndirectLicenseErrors),$($IndirectLicenseError)"}

      $licenseArray = $MsolUser.Licenses | foreach-Object {$_.AccountSkuId}
      $Licenses = ""
      ForEach ($License in $licenseArray){
      $Licenses = "$($Licenses),$($License)"}

      $ProxyAddresses = ""
      ForEach ($ProxyAddress in $MsolUser.ProxyAddresses){
      $ProxyAddresses = "$($ProxyAddresses),$($ProxyAddress)"}

    [PSCustomObject]@{
      DisplayName       = $MsolUser.DisplayName
      UserPrincipalName = $MsolUser.UserPrincipalName
      isAdmin           = $true
      MFAEnabled        = if ($MsolUser.StrongAuthenticationMethods) {$true} else {$false}
      MFAType           = $Method
			MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
AlternateEmailAddresses = $AlternateEmailAddresses
        AlternateMobilePhones = $AlternateMobilePhones
        AlternativeSecurityIds = $AlternativeSecurityIds
        BlockCredential = $MsolUser.BlockCredential
        City = $MsolUser.City
        CloudExchangeRecipientDisplayType= $MsolUser.CloudExchangeRecipientDisplayType
        Country = $MsolUser.Country
        Department = $MsolUser.Department
        DirSyncProvisioningErrors = $DirSyncProvisioningErrors
        Errors = $MsolUser.Errors
        Fax = $MsolUser.Fax
        FirstName = $MsolUser.FirstName
        ImutableId = $MsolUser.ImutableId
        IndirectLicenseErrors = $IndirectLicenseErrors
        IsLicensed = $MsolUser.IsLicensed
        LastDirSyncTime = $MsolUser.LastDirSyncTime
        LastName = $MsolUser.LastName
        LastPasswordChangeTimestamp = $MsolUser.LastPasswordChangeTimestamp
        LicenseReconciliationNeeded = $MsolUser.LicenseReconciliationNeeded
        Licenses = $Licenses
        LiveId = $MsolUser.LiveId
        MSExchRecipientTypeDetails = $MsolUser.MSExchRecipientTypeDetails
        MSRtcSipDeploymentLocator = $MsolUser.MSRtcSipDeploymentLocator
        MSRtcSipPrimaryUserAddress = $MsolUser.MSRtcSipPrimaryUserAddress
        MobilePhone = $MsolUser.MobilePhone
        ObjectId =  $MsolUser.ObjectId
        Office = $MsolUser.Office
        OverallProvisioningStatus = $MsolUser.OverallProvisioningStatus
        PasswordNeverExpires = $MsolUser.PasswordNeverExpires
        PasswordResetNotRequiredDuringActivate = $MsolUser.PasswordResetNotRequiredDuringActivate
        PhoneNumber = $MsolUser.PhoneNumber
        PortalSettings= $MsolUser.PortalSettings
        PostalCode = $MsolUser.PostalCode
        PreferredDataLocation = $MsolUser.PreferredDataLocation
        PreferredLanguage = $MsolUser.PreferredLanguage
        ProxyAddresses = $ProxyAddresses
        ReleaseTrack = $MsolUser.ReleaseTrack
        SignInName = $MsolUser.SignInName
        SoftDeletionTimestamp = $MsolUser.SoftDeletionTimestamp 
        State = $MsolUser.State
        StreetAddress = $MsolUser.StreetAddress
        StrongPasswordRequired = $MsolUser.StrongPasswordRequired
        StsRefreshTokensValidFrom = $MsolUser.StsRefreshTokensValidFrom
        Title = $MsolUser.Title
        UsageLocation = $MsolUser.UsageLocation
        UserLandingPageIdentifierForO365Shell = $MsolUser.UserLandingPageIdentifierForO365Shell
        UserThemeIdentifierForO365Shell = $MsolUser.UserThemeIdentifierForO365Shell 
        UserType = $MsolUser.UserType
        ValidationStatus = $MsolUser.ValidationStatus
        WhenCreated = $MsolUser.WhenCreated
    }
  }
}
# Get the MFA status from all the users
else {
  #$MsolUsers = Get-MsolUser -EnabledFilter EnabledOnly -MaxResults $MaxResults | Where-Object {$_.IsLicensed -eq $isLicensed} | Sort-Object UserPrincipalName
  $MsolUsers = Get-MsolUser -EnabledFilter EnabledOnly -MaxResults $MaxResults | Sort-Object UserPrincipalName
    foreach ($MsolUser in $MsolUsers) {

      $MFAMethod = $MsolUser.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq $true} | Select-Object -ExpandProperty MethodType
      $Method = ""

      If (($MsolUser.StrongAuthenticationRequirements) -or ($MsolUser.StrongAuthenticationMethods)) {
        Switch ($MFAMethod) {
            "OneWaySMS" { $Method = "SMS token" }
            "TwoWayVoiceMobile" { $Method = "Phone call verification" }
            "PhoneAppOTP" { $Method = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $Method = "Authenticator app" }
        }
      }

      if ($withOutMFAOnly) {
        # List only the user that don't have MFA enabled
        if (-not($MsolUser.StrongAuthenticationMethods)) {

        $AlternateEmailAddresses = ""
      ForEach ($AlternateEmailAddress in $MsolUser.AlternateEmailAddresses){
      $AlternateEmailAddresses = "$($AlternateEmailAddresses),$($AlternateEmailAddress)"}

      $AlternateMobilePhones = ""
      ForEach ($AlternateMobilePhone in $MsolUser.AlternateMobilePhones){
      $AlternateMobilePhones = "$($AlternateMobilePhones),$($AlternateMobilePhone)"}

      $AlternativeSecurityIds = ""
      ForEach ($AlternativeSecurityId in $MsolUser.AlternativeSecurityIds){
      $AlternativeSecurityIds = "$($AlternativeSecurityIds),$($AlternativeSecurityId)"}

      $DirSyncProvisioningErrors = ""
      ForEach ($DirSyncProvisioningError in $MsolUser.DirSyncProvisioningError){
      $DirSyncProvisioningErrors = "$($DirSyncProvisioningErrors),$($DirSyncProvisioningError)"}

      $IndirectLicenseErrors = ""
      ForEach ($IndirectLicenseError in $MsolUser.IndirectLicenseErrors){
      $IndirectLicenseErrors = "$($IndirectLicenseErrors),$($IndirectLicenseError)"}

      $licenseArray = $MsolUser.Licenses | foreach-Object {$_.AccountSkuId}
      $Licenses = ""
      ForEach ($License in $licenseArray){
      $Licenses = "$($Licenses),$($License)"}

      $ProxyAddresses = ""
      ForEach ($ProxyAddress in $MsolUser.ProxyAddresses){
      $ProxyAddresses = "$($ProxyAddresses),$($ProxyAddress)"}

          [PSCustomObject]@{
            DisplayName       = $MsolUser.DisplayName
            UserPrincipalName = $MsolUser.UserPrincipalName
            isAdmin           = if ($listAdmins -and ($admins.EmailAddress -match $MsolUser.UserPrincipalName)) {$true} else {"-"}
            MFAEnabled        = $false
            MFAType           = "-"
						MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
AlternateEmailAddresses = $AlternateEmailAddresses
        AlternateMobilePhones = $AlternateMobilePhones
        AlternativeSecurityIds = $AlternativeSecurityIds
        BlockCredential = $MsolUser.BlockCredential
        City = $MsolUser.City
        CloudExchangeRecipientDisplayType= $MsolUser.CloudExchangeRecipientDisplayType
        Country = $MsolUser.Country
        Department = $MsolUser.Department
        DirSyncProvisioningErrors = $DirSyncProvisioningErrors
        Errors = $MsolUser.Errors
        Fax = $MsolUser.Fax
        FirstName = $MsolUser.FirstName
        ImutableId = $MsolUser.ImutableId
        IndirectLicenseErrors = $IndirectLicenseErrors
        IsLicensed = $MsolUser.IsLicensed
        LastDirSyncTime = $MsolUser.LastDirSyncTime
        LastName = $MsolUser.LastName
        LastPasswordChangeTimestamp = $MsolUser.LastPasswordChangeTimestamp
        LicenseReconciliationNeeded = $MsolUser.LicenseReconciliationNeeded
        Licenses = $Licenses
        LiveId = $MsolUser.LiveId
        MSExchRecipientTypeDetails = $MsolUser.MSExchRecipientTypeDetails
        MSRtcSipDeploymentLocator = $MsolUser.MSRtcSipDeploymentLocator
        MSRtcSipPrimaryUserAddress = $MsolUser.MSRtcSipPrimaryUserAddress
        MobilePhone = $MsolUser.MobilePhone
        ObjectId =  $MsolUser.ObjectId
        Office = $MsolUser.Office
        OverallProvisioningStatus = $MsolUser.OverallProvisioningStatus
        PasswordNeverExpires = $MsolUser.PasswordNeverExpires
        PasswordResetNotRequiredDuringActivate = $MsolUser.PasswordResetNotRequiredDuringActivate
        PhoneNumber = $MsolUser.PhoneNumber
        PortalSettings= $MsolUser.PortalSettings
        PostalCode = $MsolUser.PostalCode
        PreferredDataLocation = $MsolUser.PreferredDataLocation
        PreferredLanguage = $MsolUser.PreferredLanguage
        ProxyAddresses = $ProxyAddresses
        ReleaseTrack = $MsolUser.ReleaseTrack
        SignInName = $MsolUser.SignInName
        SoftDeletionTimestamp = $MsolUser.SoftDeletionTimestamp 
        State = $MsolUser.State
        StreetAddress = $MsolUser.StreetAddress
        StrongPasswordRequired = $MsolUser.StrongPasswordRequired
        StsRefreshTokensValidFrom = $MsolUser.StsRefreshTokensValidFrom
        Title = $MsolUser.Title
        UsageLocation = $MsolUser.UsageLocation
        UserLandingPageIdentifierForO365Shell = $MsolUser.UserLandingPageIdentifierForO365Shell
        UserThemeIdentifierForO365Shell = $MsolUser.UserThemeIdentifierForO365Shell 
        UserType = $MsolUser.UserType
        ValidationStatus = $MsolUser.ValidationStatus
        WhenCreated = $MsolUser.WhenCreated
          }
        }
      }else{

      $AlternateEmailAddresses = ""
      ForEach ($AlternateEmailAddress in $MsolUser.AlternateEmailAddresses){
      $AlternateEmailAddresses = "$($AlternateEmailAddresses),$($AlternateEmailAddress)"}

      $AlternateMobilePhones = ""
      ForEach ($AlternateMobilePhone in $MsolUser.AlternateMobilePhones){
      $AlternateMobilePhones = "$($AlternateMobilePhones),$($AlternateMobilePhone)"}

      $AlternativeSecurityIds = ""
      ForEach ($AlternativeSecurityId in $MsolUser.AlternativeSecurityIds){
      $AlternativeSecurityIds = "$($AlternativeSecurityIds),$($AlternativeSecurityId)"}

      $DirSyncProvisioningErrors = ""
      ForEach ($DirSyncProvisioningError in $MsolUser.DirSyncProvisioningError){
      $DirSyncProvisioningErrors = "$($DirSyncProvisioningErrors),$($DirSyncProvisioningError)"}

      $IndirectLicenseErrors = ""
      ForEach ($IndirectLicenseError in $MsolUser.IndirectLicenseErrors){
      $IndirectLicenseErrors = "$($IndirectLicenseErrors),$($IndirectLicenseError)"}

      $licenseArray = $MsolUser.Licenses | foreach-Object {$_.AccountSkuId}
      $Licenses = ""
      ForEach ($License in $licenseArray){
      $Licenses = "$($Licenses),$($License)"}

      $ProxyAddresses = ""
      ForEach ($ProxyAddress in $MsolUser.ProxyAddresses){
      $ProxyAddresses = "$($ProxyAddresses),$($ProxyAddress)"}
        [PSCustomObject]@{
          DisplayName       = $MsolUser.DisplayName
          UserPrincipalName = $MsolUser.UserPrincipalName
          isAdmin           = if ($listAdmins -and ($admins.EmailAddress -match $MsolUser.UserPrincipalName)) {$true} else {"-"}
          MFAEnabled        = if ($MsolUser.StrongAuthenticationMethods) {$true} else {$false}
          MFAType           = $Method
					MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
AlternateEmailAddresses = $AlternateEmailAddresses
        AlternateMobilePhones = $AlternateMobilePhones
        AlternativeSecurityIds = $AlternativeSecurityIds
        BlockCredential = $MsolUser.BlockCredential
        City = $MsolUser.City
        CloudExchangeRecipientDisplayType= $MsolUser.CloudExchangeRecipientDisplayType
        Country = $MsolUser.Country
        Department = $MsolUser.Department
        DirSyncProvisioningErrors = $DirSyncProvisioningErrors
        Errors = $MsolUser.Errors
        Fax = $MsolUser.Fax
        FirstName = $MsolUser.FirstName
        ImutableId = $MsolUser.ImutableId
        IndirectLicenseErrors = $IndirectLicenseErrors
        IsLicensed = $MsolUser.IsLicensed
        LastDirSyncTime = $MsolUser.LastDirSyncTime
        LastName = $MsolUser.LastName
        LastPasswordChangeTimestamp = $MsolUser.LastPasswordChangeTimestamp
        LicenseReconciliationNeeded = $MsolUser.LicenseReconciliationNeeded
        Licenses = $Licenses
        LiveId = $MsolUser.LiveId
        MSExchRecipientTypeDetails = $MsolUser.MSExchRecipientTypeDetails
        MSRtcSipDeploymentLocator = $MsolUser.MSRtcSipDeploymentLocator
        MSRtcSipPrimaryUserAddress = $MsolUser.MSRtcSipPrimaryUserAddress
        MobilePhone = $MsolUser.MobilePhone
        ObjectId =  $MsolUser.ObjectId
        Office = $MsolUser.Office
        OverallProvisioningStatus = $MsolUser.OverallProvisioningStatus
        PasswordNeverExpires = $MsolUser.PasswordNeverExpires
        PasswordResetNotRequiredDuringActivate = $MsolUser.PasswordResetNotRequiredDuringActivate
        PhoneNumber = $MsolUser.PhoneNumber
        PortalSettings= $MsolUser.PortalSettings
        PostalCode = $MsolUser.PostalCode
        PreferredDataLocation = $MsolUser.PreferredDataLocation
        PreferredLanguage = $MsolUser.PreferredLanguage
        ProxyAddresses = $ProxyAddresses
        ReleaseTrack = $MsolUser.ReleaseTrack
        SignInName = $MsolUser.SignInName
        SoftDeletionTimestamp = $MsolUser.SoftDeletionTimestamp 
        State = $MsolUser.State
        StreetAddress = $MsolUser.StreetAddress
        StrongPasswordRequired = $MsolUser.StrongPasswordRequired
        StsRefreshTokensValidFrom = $MsolUser.StsRefreshTokensValidFrom
        Title = $MsolUser.Title
        UsageLocation = $MsolUser.UsageLocation
        UserLandingPageIdentifierForO365Shell = $MsolUser.UserLandingPageIdentifierForO365Shell
        UserThemeIdentifierForO365Shell = $MsolUser.UserThemeIdentifierForO365Shell 
        UserType = $MsolUser.UserType
        ValidationStatus = $MsolUser.ValidationStatus
        WhenCreated = $MsolUser.WhenCreated
        }
      }
    }
  }