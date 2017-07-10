﻿#Requires -Modules ActiveDirectory

<#
    .SYNOPSIS
         Adds users to Active Directory groups
    
    .DESCRIPTION
          
    .Parameter UserNames
        Comma separated display name, SAMAccountName, DistinguishedName or user principal name of the users added to the groups

    .Parameter GroupNames
        Comma separated names of the groups to which the users added
       
    .Parameter DomainAccount
        Active Directory Credential for remote execution without CredSSP

    .Parameter DomainName
        Name of Active Directory Domain
    
    .Parameter AuthType
        Specifies the authentication method to use
#>

param(
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string[]]$UserNames,
    [Parameter(Mandatory = $true,ParameterSetName = "Local or Remote DC")]
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [string[]]$GroupNames,
    [Parameter(Mandatory = $true,ParameterSetName = "Remote Jumphost")]
    [PSCredential]$DomainAccount,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [string]$DomainName,
    [Parameter(ParameterSetName = "Local or Remote DC")]
    [Parameter(ParameterSetName = "Remote Jumphost")]
    [ValidateSet('Basic', 'Negotiate')]
    [string]$AuthType="Negotiate"
)

Import-Module ActiveDirectory

#Clear
$ErrorActionPreference='Stop'

$Script:Domain
if($PSCmdlet.ParameterSetName  -eq "Remote Jumphost"){
    if([System.String]::IsNullOrWhiteSpace($DomainName)){
        $Script:Domain = Get-ADDomain -Current LocalComputer -AuthType $AuthType -Credential $DomainAccount
    }
    else{
        $Script:Domain = Get-ADDomain -Identity $DomainName -AuthType $AuthType -Credential $DomainAccount
    }
}
else{
    if([System.String]::IsNullOrWhiteSpace($DomainName)){
        $Script:Domain = Get-ADDomain -Current LocalComputer -AuthType $AuthType 
    }
    else{
        $Script:Domain = Get-ADDomain -Identity $DomainName -AuthType $AuthType 
    }
}

$res = @()
if($UserNames){    
    $UserSAMAccountNames = @()
    foreach($name in $UserNames){
        if($PSCmdlet.ParameterSetName  -eq "Remote Jumphost"){
            $usr= Get-ADUser -Credential $DomainAccount -Server $Script:Domain.PDCEmulator -AuthType $AuthType `
                -Filter {(SamAccountName -eq $name) -or (DisplayName -eq $name) -or (DistinguishedName -eq $name) -or (UserPrincipalName -eq $name)} | Select-Object SAMAccountName
        }
        else {
            $usr= Get-ADUser -Server $Script:Domain.PDCEmulator -AuthType $AuthType `
                -Filter {(SamAccountName -eq $name) -or (DisplayName -eq $name) -or (DistinguishedName -eq $name) -or (UserPrincipalName -eq $name)} | Select-Object SAMAccountName
            
        }
        if($null -ne $usr){
            $UserSAMAccountNames += $usr.SAMAccountName
        }
        else {
            $res = $res + "User $($name) not found"
        }
    }
}
foreach($usr in $UserSAMAccountNames){
    $founded = @()
    foreach($itm in $GroupNames){
        if($PSCmdlet.ParameterSetName  -eq "Remote Jumphost"){
            $grp= Get-ADGroup -Credential $DomainAccount -Server $Script:Domain.PDCEmulator -AuthType $AuthType `
                -Filter {(SamAccountName -eq $itm) -or (DistinguishedName -eq $itm)}
        }
        else {
            $grp= Get-ADGroup -Server $Script:Domain.PDCEmulator -AuthType $AuthType `
                -Filter {(SamAccountName -eq $itm) -or (DistinguishedName -eq $itm)}
        }
        if($null -ne $grp){
            $founded += $itm
            try {
                if($PSCmdlet.ParameterSetName  -eq "Remote Jumphost"){
                    Add-ADGroupMember -Credential $DomainAccount -Server $Script:Domain.PDCEmulator -AuthType $AuthType -Identity $grp -Members $usr
                }
                else {
                    Add-ADGroupMember -Server $Script:Domain.PDCEmulator -AuthType $AuthType -Identity $grp -Members $usr 
                }
                $res = $res + "User $($usr) added to Group $($itm)"
            }
            catch {
                $res = $res + "Error: Add user $($usr) to Group $($itm) $($_.Exception.Message)"
            }
        }
        else {
            $res = $res + "Group $($itm) not found"
        }        
    }
    $GroupNames=$founded
}
if($SRXEnv) {
    $SRXEnv.ResultMessage = $res
}
else{
    Write-Output $res
}