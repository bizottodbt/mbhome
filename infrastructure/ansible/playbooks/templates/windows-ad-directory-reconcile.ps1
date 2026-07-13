param(
  [Parameter(Mandatory = $true)]
  [string]$StatePath,

  [bool]$CheckMode = $false
)

$ErrorActionPreference = "Stop"

$State = Get-Content -Raw -Path $StatePath | ConvertFrom-Json
$Domain = Get-ADDomain
$Changed = $false

function ConvertTo-Array($Value) {
  if ($null -eq $Value) { return @() }
  if ($Value -is [System.Array]) { return $Value }
  return @($Value)
}

function Get-JsonProperty($Object, [string]$Name, $Default = $null) {
  if ($null -eq $Object) { return $Default }
  $Property = $Object.PSObject.Properties[$Name]
  if ($null -eq $Property) { return $Default }
  if ($null -eq $Property.Value) { return $Default }
  return $Property.Value
}

function Escape-LdapFilterValue([string]$Value) {
  $Escape = [string][char]92
  return $Value.
    Replace($Escape, ($Escape + '5c')).
    Replace('*', ($Escape + '2a')).
    Replace('(', ($Escape + '28')).
    Replace(')', ($Escape + '29')).
    Replace([string][char]0, ($Escape + '00'))
}

function Invoke-DirectoryChange([string]$Message, [scriptblock]$Action) {
  if ($CheckMode) {
    Write-Output "WOULD_CHANGE: $Message"
  } else {
    & $Action
    Write-Output "CHANGED: $Message"
  }
  $script:Changed = $true
}

function Get-ObjectPath($Object, [string]$DefaultPath) {
  $Path = Get-JsonProperty $Object "path" $DefaultPath
  if ([string]::IsNullOrWhiteSpace($Path)) {
    throw "Missing path for object $($Object | ConvertTo-Json -Compress)."
  }
  return $Path
}

function Get-ObjectDn($Object, [string]$RdnPrefix, [string]$Name, [string]$Path) {
  $ExplicitDn = Get-JsonProperty $Object "dn" $null
  if (-not [string]::IsNullOrWhiteSpace($ExplicitDn)) { return $ExplicitDn }
  return "$RdnPrefix=$Name,$Path"
}

function Get-PasswordCategoryCount([string]$Password) {
  $Count = 0
  if ($Password -cmatch '[A-Z]') { $Count += 1 }
  if ($Password -cmatch '[a-z]') { $Count += 1 }
  if ($Password -match '\d') { $Count += 1 }
  if ($Password -match '[^a-zA-Z0-9]') { $Count += 1 }
  return $Count
}

function Assert-NewUserPasswordPolicy($User, $Policy) {
  $Username = [string](Get-JsonProperty $User "username" "")
  $Password = [string](Get-JsonProperty $User "password" "")
  $DisplayName = [string](Get-JsonProperty $User "display_name" $Username)

  if ($Password.Length -lt [int]$Policy.MinPasswordLength) {
    throw "Password for user $Username is shorter than the domain minimum length of $($Policy.MinPasswordLength)."
  }

  if ([bool]$Policy.ComplexityEnabled) {
    $CategoryCount = Get-PasswordCategoryCount $Password
    if ($CategoryCount -lt 3) {
      throw "Password for user $Username does not meet domain complexity policy. Use at least three of uppercase, lowercase, digit, and symbol."
    }

    $NameParts = @($Username)
    $NameParts += ($DisplayName -split '[\s,._-]') | Where-Object { $_.Length -gt 2 }
    foreach ($Part in $NameParts) {
      if (-not [string]::IsNullOrWhiteSpace($Part) -and $Password.IndexOf($Part, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Password for user $Username contains the username or a display-name component, which the domain complexity policy rejects."
      }
    }
  }
}

Import-Module ActiveDirectory

if ($Domain.DNSRoot -ine [string]$State.domain) {
  throw "Connected to domain $($Domain.DNSRoot), but desired state targets $($State.domain)."
}

$DefaultOuProtection = [bool](Get-JsonProperty $State "protect_ous_from_accidental_deletion" $true)
$DomainPasswordPolicy = Get-ADDefaultDomainPasswordPolicy

$DesiredUsers = @()
$DesiredUsers += ConvertTo-Array $State.users

$DefaultServiceAccountPath = Get-JsonProperty $State "service_accounts_path" ("OU=Service Accounts," + [string]$State.base_dn)
foreach ($ServiceAccount in ConvertTo-Array $State.service_accounts) {
  if ($null -eq $ServiceAccount.PSObject.Properties["path"] -or [string]::IsNullOrWhiteSpace([string]$ServiceAccount.path)) {
    $ServiceAccount | Add-Member -NotePropertyName path -NotePropertyValue $DefaultServiceAccountPath -Force
  }
  if ($null -eq $ServiceAccount.PSObject.Properties["password_never_expires"]) {
    $ServiceAccount | Add-Member -NotePropertyName password_never_expires -NotePropertyValue $true -Force
  }
  if ($null -eq $ServiceAccount.PSObject.Properties["must_change_password"]) {
    $ServiceAccount | Add-Member -NotePropertyName must_change_password -NotePropertyValue $false -Force
  }
  $DesiredUsers += $ServiceAccount
}

foreach ($User in $DesiredUsers) {
  $Username = [string](Get-JsonProperty $User "username" "")
  if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "User entry is missing username."
  }

  $Enabled = [bool](Get-JsonProperty $User "enabled" $true)
  $EscapedUser = Escape-LdapFilterValue $Username
  $ExistingUser = Get-ADUser -LDAPFilter "(sAMAccountName=$EscapedUser)" -Properties Enabled -ErrorAction SilentlyContinue

  if ($Enabled -and ($null -eq $ExistingUser -or -not [bool]$ExistingUser.Enabled)) {
    $InitialPassword = [string](Get-JsonProperty $User "password" "")
    if ([string]::IsNullOrWhiteSpace($InitialPassword)) {
      throw "User $Username is enabled but no password is defined in infrastructure/ad/directory.local.yaml."
    }
    Assert-NewUserPasswordPolicy $User $DomainPasswordPolicy
  }
}

foreach ($Ou in ConvertTo-Array $State.ous) {
  $Name = [string](Get-JsonProperty $Ou "name" "")
  $Path = Get-ObjectPath $Ou ([string]$State.base_dn)
  $Dn = Get-ObjectDn $Ou "OU" $Name $Path
  $Description = Get-JsonProperty $Ou "description" $null
  $Protected = [bool](Get-JsonProperty $Ou "protected_from_accidental_deletion" $DefaultOuProtection)

  if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "OU entry is missing name."
  }

  $Existing = $null
  try {
    $Existing = Get-ADOrganizationalUnit -Identity $Dn -Properties Description,ProtectedFromAccidentalDeletion -ErrorAction Stop
  } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    $Existing = $null
  }

  if ($null -eq $Existing) {
    Invoke-DirectoryChange "Create OU $Dn" {
      New-ADOrganizationalUnit -Name $Name -Path $Path -Description $Description -ProtectedFromAccidentalDeletion $Protected
    }
    continue
  }

  if ($null -ne $Description -and $Existing.Description -ne $Description) {
    Invoke-DirectoryChange "Update OU description $Dn" {
      Set-ADOrganizationalUnit -Identity $Dn -Description $Description
    }
  }

  if ($Existing.ProtectedFromAccidentalDeletion -ne $Protected) {
    Invoke-DirectoryChange "Update OU accidental deletion protection $Dn" {
      Set-ADOrganizationalUnit -Identity $Dn -ProtectedFromAccidentalDeletion $Protected
    }
  }
}

foreach ($Group in ConvertTo-Array $State.groups) {
  $Name = [string](Get-JsonProperty $Group "name" "")
  $SamAccountName = [string](Get-JsonProperty $Group "sam_account_name" $Name)
  $Path = Get-ObjectPath $Group ([string]$State.base_dn)
  $Description = Get-JsonProperty $Group "description" $null
  $Scope = [string](Get-JsonProperty $Group "scope" "Global")
  $Category = [string](Get-JsonProperty $Group "category" "Security")

  if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "Group entry is missing name."
  }

  $EscapedSam = Escape-LdapFilterValue $SamAccountName
  $Existing = Get-ADGroup -LDAPFilter "(sAMAccountName=$EscapedSam)" -Properties Description,GroupScope,GroupCategory -ErrorAction SilentlyContinue
  if ($null -eq $Existing) {
    Invoke-DirectoryChange "Create group $Name" {
      New-ADGroup -Name $Name -SamAccountName $SamAccountName -Path $Path -GroupScope $Scope -GroupCategory $Category -Description $Description
    }
    continue
  }

  if ($null -ne $Description -and $Existing.Description -ne $Description) {
    Invoke-DirectoryChange "Update group description $Name" {
      Set-ADGroup -Identity $Existing.DistinguishedName -Description $Description
    }
  }
}

foreach ($User in $DesiredUsers) {
  $Username = [string](Get-JsonProperty $User "username" "")
  if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "User entry is missing username."
  }

  $InitialPassword = [string](Get-JsonProperty $User "password" "")
  $Enabled = [bool](Get-JsonProperty $User "enabled" $true)
  $Path = Get-ObjectPath $User ([string]$State.base_dn)
  $Upn = [string](Get-JsonProperty $User "upn" "$Username@$($State.domain)")
  $DisplayName = [string](Get-JsonProperty $User "display_name" $Username)
  $GivenName = Get-JsonProperty $User "given_name" $null
  $Surname = Get-JsonProperty $User "surname" $null
  $Email = Get-JsonProperty $User "email" $null
  $Description = Get-JsonProperty $User "description" $null
  $PasswordNeverExpires = [bool](Get-JsonProperty $User "password_never_expires" $false)
  $MustChangePassword = [bool](Get-JsonProperty $User "must_change_password" $false)

  $EscapedUser = Escape-LdapFilterValue $Username
  $Existing = Get-ADUser -LDAPFilter "(sAMAccountName=$EscapedUser)" -Properties GivenName,Surname,DisplayName,EmailAddress,Description,UserPrincipalName,Enabled,PasswordNeverExpires -ErrorAction SilentlyContinue

  if ($null -eq $Existing) {
    if ($Enabled -and [string]::IsNullOrWhiteSpace($InitialPassword)) {
      throw "User $Username is enabled but no password is defined in infrastructure/ad/directory.local.yaml."
    }

    Invoke-DirectoryChange "Create user $Username" {
      $NewUserParams = @{
        Name = $DisplayName
        SamAccountName = $Username
        UserPrincipalName = $Upn
        DisplayName = $DisplayName
        Path = $Path
        Enabled = $Enabled
        PasswordNeverExpires = $PasswordNeverExpires
      }
      if ($null -ne $GivenName) { $NewUserParams.GivenName = $GivenName }
      if ($null -ne $Surname) { $NewUserParams.Surname = $Surname }
      if ($null -ne $Email) { $NewUserParams.EmailAddress = $Email }
      if ($null -ne $Description) { $NewUserParams.Description = $Description }
      if (-not [string]::IsNullOrWhiteSpace($InitialPassword)) {
        $NewUserParams.AccountPassword = ConvertTo-SecureString $InitialPassword -AsPlainText -Force
      }
      New-ADUser @NewUserParams
      if ($MustChangePassword) {
        Set-ADUser -Identity $Username -ChangePasswordAtLogon $true
      }
    }

    if ($CheckMode) {
      foreach ($GroupName in ConvertTo-Array (Get-JsonProperty $User "groups" @())) {
        Invoke-DirectoryChange "Add user $Username to group $GroupName" {}
      }
      continue
    }
  } else {
    $SetParams = @{
      Identity = $Existing.DistinguishedName
    }
    if ($Existing.UserPrincipalName -ne $Upn) { $SetParams.UserPrincipalName = $Upn }
    if ($Existing.DisplayName -ne $DisplayName) { $SetParams.DisplayName = $DisplayName }
    if ($null -ne $GivenName -and $Existing.GivenName -ne $GivenName) { $SetParams.GivenName = $GivenName }
    if ($null -ne $Surname -and $Existing.Surname -ne $Surname) { $SetParams.Surname = $Surname }
    if ($null -ne $Email -and $Existing.EmailAddress -ne $Email) { $SetParams.EmailAddress = $Email }
    if ($null -ne $Description -and $Existing.Description -ne $Description) { $SetParams.Description = $Description }
    if ($Existing.PasswordNeverExpires -ne $PasswordNeverExpires) { $SetParams.PasswordNeverExpires = $PasswordNeverExpires }

    if ($SetParams.Keys.Count -gt 1) {
      Invoke-DirectoryChange "Update user attributes $Username" {
        Set-ADUser @SetParams
      }
    }

    if ([bool]$Existing.Enabled -ne $Enabled) {
      if ($Enabled) {
        Invoke-DirectoryChange "Enable user $Username" {
          if (-not [string]::IsNullOrWhiteSpace($InitialPassword)) {
            $SecurePassword = ConvertTo-SecureString $InitialPassword -AsPlainText -Force
            Set-ADAccountPassword -Identity $Existing.DistinguishedName -Reset -NewPassword $SecurePassword
          }
          Enable-ADAccount -Identity $Existing.DistinguishedName
        }
      } else {
        Invoke-DirectoryChange "Disable user $Username" {
          Disable-ADAccount -Identity $Existing.DistinguishedName
        }
      }
    }
  }

  foreach ($GroupName in ConvertTo-Array (Get-JsonProperty $User "groups" @())) {
    $MemberOf = Get-ADPrincipalGroupMembership -Identity $Username | Where-Object { $_.Name -eq $GroupName }
    if ($null -eq $MemberOf) {
      Invoke-DirectoryChange "Add user $Username to group $GroupName" {
        Add-ADGroupMember -Identity $GroupName -Members $Username
      }
    }
  }
}

foreach ($Group in ConvertTo-Array $State.groups) {
  $GroupName = [string](Get-JsonProperty $Group "name" "")
  $EscapedGroup = Escape-LdapFilterValue $GroupName
  $ExistingGroup = Get-ADGroup -LDAPFilter "(sAMAccountName=$EscapedGroup)" -ErrorAction SilentlyContinue
  foreach ($Member in ConvertTo-Array (Get-JsonProperty $Group "members" @())) {
    if ($null -eq $ExistingGroup -and $CheckMode) {
      Invoke-DirectoryChange "Add member $Member to group $GroupName" {}
      continue
    }
    $ExistingMember = Get-ADGroupMember -Identity $GroupName -Recursive:$false | Where-Object {
      $_.SamAccountName -eq $Member -or $_.Name -eq $Member
    }
    if ($null -eq $ExistingMember) {
      Invoke-DirectoryChange "Add member $Member to group $GroupName" {
        Add-ADGroupMember -Identity $GroupName -Members $Member
      }
    }
  }
}

Write-Output "CHANGED=$Changed"
