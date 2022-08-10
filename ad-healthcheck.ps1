
Write-Output ""
Write-Output "Checking domain trusts from current domain"
Get-ADTrust -Filter * | select Name, Target,distinguishedName,Direction

Write-Output ""
$Domains =$(Get-ADForest).Domains
Write-Output "Domains in current Forest are:"
$Domains | sort { $_.length }

ForEach($Domain in $Domains | sort { $_.length }){
    Write-Output ""
    Write-Output "---Checking domain $($Domain)---"
    Write-Output ""

    $usersCount = (get-aduser -Filter * -server $Domain).count
    $computersCount = (get-adcomputer -Filter * -server $Domain).count

    Write-Output ""
    Write-Output "Found $($usersCount) user objects"
    Write-Output "Found $($computersCount) computer objects"
    Write-Output ""

    Write-Output "Enabled Active Directory user accounts which have not authenticated in 60 days"
    Write-Output "(query uses 70 instead of 60 as LastLogonDate has an error of margin of 9-14 days)"
    Write-Output ""
    Get-ADUser -Filter * -Properties LastLogonDate, WhenCreated -server $Domain | Where-Object {($_.Enabled -eq $true) -and ($_.LastLogonDate -lt (Get-Date).AddDays(-70)) -and ($_.LastLogonDate -ne $null)} | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "Enabled Active Directory user accounts older than 30 days that have never authenticated"
    Write-Output ""
    Get-ADUser -Filter * -Properties LastLogonDate, WhenCreated -server $Domain | Where-Object {($_.Enabled -eq $true) -and ($_.LastLogonDate -eq $null) -and ($_.whenCreated -lt (Get-Date).AddDays(-30))} | select name, distinguishedName, whenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "Enabled and Disabled Active Directory user accounts that have not authenticated in 90 days (and probably should have been deleted)"
    Write-Output ""
    Get-ADUser -Filter * -Properties LastLogonDate, WhenCreated -server $Domain | Where-Object {($_.LastLogonDate -lt (Get-Date).AddDays(-100)) } | select name, distinguishedName, LastLogonDate, WhenCreated|Format-Table -AutoSize

    Write-Output ""
    Write-Output "Members of the domain Builtin\Administrators group (including Domain Admins)"
    Write-Output ""
    $count = (get-adgroupmember Administrators -Recursive -Server $Domain).count
    Write-Output "$($Domain) has $($count) Administrators:"
    get-adgroupmember Administrators -Recursive -Server $Domain | select name, distinguishedName, objectClass, SamAccountName|Format-Table -AutoSize

    Write-Output ""
    Write-Output "Users with ReversibleEncryptionPasswordArray"
    Write-Output ""
    Get-ADUser -Filter * -Properties * -Server $Domain | Where { $_.UserAccountControl -band 0x0080 } | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "User accounts that can use DES to authenticate (weak encryption)"
    Write-Output ""
    Get-ADUser -Filter {UserAccountControl -band 0x200000} -server $Domain | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "User ccounts that do not require Kerberos pre-authentication (which enables authentication without a password)"
    Write-Output ""
    Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -server $Domain | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "Computers with unconstrained Kerberos delegation (an attacker controlled computer with this enabled can impersonate other computers)"
    Write-Output ""
    Get-ADComputer -Filter { (TrustedForDelegation -eq $True) -AND (PrimaryGroupID -ne '516') -AND (PrimaryGroupID -ne '521') } -server $Domain | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "Testing that krbtgt password has been changed in the last 180 days"
    Write-Output ""
    $DomainKRBTGTAccount= Get-ADUser 'krbtgt' -Server $Domain -Properties 'msds-keyversionnumber',Created,PasswordLastSet
    If($DomainKRBTGTAccount.PasswordLastSet -le (Get-Date).AddDays(-180)) { 
        Write-Output "Failed the test, last change was $($DomainKRBTGTAccount.PasswordLastSet)"
    }else{
        Write-Output "Passed the test - krbtgt has been changed in the last 180 days"
    }

    Write-Output ""
    Write-Output "Accounts that haven't changed passwords in the last 60 days"
    Write-Output ""
    Get-ADUser -Filter * -Properties * -server $Domain  | Where { ($_.LastLogonDate -le $LastLoggedOnDate) -AND ($_.PasswordLastSet -le (Get-Date).AddDays(-60)) } | select name, distinguishedName, LastLogonDate, PasswordLastSet, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "User accounts that with passwords that never expire"
    Write-Output ""
    get-aduser -filter * -server $Domain -properties Name, PasswordNeverExpires | where {$_.passwordNeverExpires -eq "true" } |  select name, distinguishedName, LastLogonDate, WhenCreated|Format-Table -AutoSize

    Write-Output ""
    Write-Output "User accounts that do not require a password (even though they may have one)"
    Write-Output ""
    get-ADUser -server $Domain -Filter {PasswordNotRequired -eq $true} | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize

    Write-Output ""
    Write-Output "Enabled computer accounts that haven't authenticated in the last 60 days (allowing for 9-14 day LastLogonDate variance) "
    Write-Output ""
    Get-ADComputer -server $Domain -Filter * -Properties LastLogonDate, WhenCreated | Where-Object {($_.enabled -eq $true ) -and ($_.lastLogonDate -ne $null) -and ($_.LastLogonDate -lt (Get-Date).AddDays(-70)) } | select name, distinguishedName, LastLogonDate, WhenCreated |Format-Table -AutoSize
    
    Write-Output ""
    Write-Output "Enabled computer accounts older than 30 days which have never authenticated "
    Write-Output ""
    Get-ADComputer -Filter * -Properties LastLogonDate, WhenCreated -server $Domain | Where-Object {($_.Enabled -eq $true) -and ($_.LastLogonDate -eq $null) -and ($_.whenCreated -lt (Get-Date).AddDays(-30))} | select name, distinguishedName |Format-Table -AutoSize

    Write-Output ""
    Write-Output "Enabled and Disabled Active Directory computer accounts that have not authenticated in 90 days (and probably should have been deleted)"
    Write-Output ""
    Get-ADComputer -Filter * -Properties LastLogonDate, WhenCreated -server $Domain | Where-Object {($_.LastLogonDate -lt (Get-Date).AddDays(-100)) } | select name, distinguishedName, LastLogonDate, WhenCreated|Format-Table -AutoSize

}
