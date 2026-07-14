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

function Test-JsonProperty($Object, [string]$Name) {
  if ($null -eq $Object) { return $false }
  $Property = $Object.PSObject.Properties[$Name]
  return ($null -ne $Property -and $null -ne $Property.Value)
}

function Get-DesiredUidNumber($User) {
  if (-not (Test-JsonProperty $User "uid")) {
    return $null
  }

  $Username = [string](Get-JsonProperty $User "username" "")
  $RawUid = [string](Get-JsonProperty $User "uid" "")
  if ([string]::IsNullOrWhiteSpace($RawUid)) {
    return $null
  }

  $UidNumber = 0
  if (-not [int]::TryParse($RawUid, [ref]$UidNumber) -or $UidNumber -le 0) {
    throw "User $Username has invalid uid '$RawUid'. Use a positive integer Linux UID."
  }

  return $UidNumber
}

function Get-Range($Parent, [string]$Name, [int]$DefaultStart, [int]$DefaultEnd) {
  $Range = Get-JsonProperty $Parent $Name $null
  $Start = [int](Get-JsonProperty $Range "start" $DefaultStart)
  $End = [int](Get-JsonProperty $Range "end" $DefaultEnd)

  if ($Start -le 0 -or $End -lt $Start) {
    throw "Invalid POSIX range $Name. Use positive start/end values with end >= start."
  }

  return [pscustomobject]@{
    Start = $Start
    End = $End
  }
}

function Add-UsedId([hashtable]$UsedIds, $Value) {
  if ($null -eq $Value) { return }
  $RawValue = [string]$Value
  if ([string]::IsNullOrWhiteSpace($RawValue)) { return }

  $Id = 0
  if ([int]::TryParse($RawValue, [ref]$Id) -and $Id -gt 0) {
    $UsedIds[[string]$Id] = $true
  }
}

function Get-NextAvailableId([hashtable]$UsedIds, $Range, [string]$Purpose) {
  for ($Id = [int]$Range.Start; $Id -le [int]$Range.End; $Id++) {
    $Key = [string]$Id
    if (-not $UsedIds.ContainsKey($Key)) {
      $UsedIds[$Key] = $true
      return $Id
    }
  }

  throw "No available $Purpose remains in range $($Range.Start)-$($Range.End)."
}

function Get-ExistingUserBySam([string]$SamAccountName, [string[]]$Properties = @()) {
  $EscapedSam = Escape-LdapFilterValue $SamAccountName
  return Get-ADUser -LDAPFilter "(sAMAccountName=$EscapedSam)" -Properties $Properties -ErrorAction SilentlyContinue
}

function Get-ExistingGroupBySam([string]$SamAccountName, [string[]]$Properties = @()) {
  $EscapedSam = Escape-LdapFilterValue $SamAccountName
  return Get-ADGroup -LDAPFilter "(sAMAccountName=$EscapedSam)" -Properties $Properties -ErrorAction SilentlyContinue
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
$Posix = Get-JsonProperty $State "posix" $null
$UserUidRange = Get-Range $Posix "user_uid_range" 10000 19999
$GroupGidRange = Get-Range $Posix "group_gid_range" 20000 29999
$PrimaryGidRange = Get-Range $Posix "primary_gid_range" 30000 39999
$PrimaryGroupsPath = [string](Get-JsonProperty $Posix "primary_groups_path" (Get-JsonProperty $State "primary_groups_path" $null))

$DesiredUsers = @()
$NormalUsers = @(ConvertTo-Array $State.users)
$DesiredUsers += $NormalUsers

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

$DesiredGroups = @()
$DesiredGroups += ConvertTo-Array $State.groups

if ([string]::IsNullOrWhiteSpace($PrimaryGroupsPath)) {
  $GroupsOu = ConvertTo-Array $State.ous |
    Where-Object { [string](Get-JsonProperty $_ "name" "") -eq "Groups" } |
    Select-Object -First 1

  if ($null -ne $GroupsOu) {
    $PrimaryGroupsPath = Get-ObjectDn $GroupsOu "OU" ([string](Get-JsonProperty $GroupsOu "name" "")) (Get-ObjectPath $GroupsOu ([string]$State.base_dn))
  } else {
    $PrimaryGroupsPath = [string]$State.base_dn
  }
}

$UserPrivateGroupByUsername = @{}
foreach ($User in $NormalUsers) {
  $Username = [string](Get-JsonProperty $User "username" "")
  if ([string]::IsNullOrWhiteSpace($Username)) {
    throw "User entry is missing username."
  }

  $PrivateGroupSamAccountName = "$Username-primary"
  $LegacyPrivateGroup = Get-ExistingGroupBySam $Username @("SamAccountName")
  $ExistingUserForPrivateGroup = Get-ExistingUserBySam $Username @("SamAccountName")
  if ($null -ne $LegacyPrivateGroup -and $null -eq $ExistingUserForPrivateGroup) {
    Invoke-DirectoryChange "Rename legacy private group $Username to $PrivateGroupSamAccountName" {
      Set-ADGroup -Identity $LegacyPrivateGroup.DistinguishedName -SamAccountName $PrivateGroupSamAccountName
      Rename-ADObject -Identity $LegacyPrivateGroup.DistinguishedName -NewName $PrivateGroupSamAccountName
    }
  }

  $PrivateGroup = [pscustomobject]@{
    name = $PrivateGroupSamAccountName
    sam_account_name = $PrivateGroupSamAccountName
    path = $PrimaryGroupsPath
    scope = "Global"
    category = "Security"
    description = "Primary POSIX group for $Username"
    __auto_private_group = $true
  }
  $DesiredGroups += $PrivateGroup
  $UserPrivateGroupByUsername[$Username] = $PrivateGroup
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

$UsedUidNumbers = @{}
$UsedGroupGidNumbers = @{}
$UsedPrimaryGidNumbers = @{}

Get-ADUser -LDAPFilter "(uidNumber=*)" -Properties uidNumber -ErrorAction SilentlyContinue |
  ForEach-Object { Add-UsedId $UsedUidNumbers $_.uidNumber }

Get-ADGroup -LDAPFilter "(gidNumber=*)" -Properties gidNumber -ErrorAction SilentlyContinue |
  ForEach-Object {
    Add-UsedId $UsedGroupGidNumbers $_.gidNumber
    Add-UsedId $UsedPrimaryGidNumbers $_.gidNumber
  }

$DesiredUidNumbers = @{}
foreach ($User in $NormalUsers) {
  $Username = [string](Get-JsonProperty $User "username" "")
  $ExistingUser = Get-ExistingUserBySam $Username @("uidNumber")
  $UidNumber = Get-DesiredUidNumber $User

  if ($null -eq $UidNumber -and $null -ne $ExistingUser -and -not [string]::IsNullOrWhiteSpace([string]$ExistingUser.uidNumber)) {
    $UidNumber = [int]$ExistingUser.uidNumber
  }

  if ($null -eq $UidNumber) {
    $UidNumber = Get-NextAvailableId $UsedUidNumbers $UserUidRange "user UID"
  } else {
    Add-UsedId $UsedUidNumbers $UidNumber
  }

  $UidKey = [string]$UidNumber
  if ($DesiredUidNumbers.ContainsKey($UidKey)) {
    throw "Duplicate uid $UidNumber declared or allocated for users $($DesiredUidNumbers[$UidKey]) and $Username."
  }

  $DesiredUidNumbers[$UidKey] = $Username
  $User | Add-Member -NotePropertyName __desired_uid_number -NotePropertyValue $UidNumber -Force
}

$DesiredGidNumbers = @{}
foreach ($Group in $DesiredGroups) {
  $Name = [string](Get-JsonProperty $Group "name" "")
  if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "Group entry is missing name."
  }

  $ExistingGroup = Get-ExistingGroupBySam ([string](Get-JsonProperty $Group "sam_account_name" $Name)) @("gidNumber")
  $RawGid = Get-JsonProperty $Group "gid" $null
  $GidNumber = $null

  if ($null -ne $RawGid -and -not [string]::IsNullOrWhiteSpace([string]$RawGid)) {
    $ParsedGid = 0
    if (-not [int]::TryParse([string]$RawGid, [ref]$ParsedGid) -or $ParsedGid -le 0) {
      throw "Group $Name has invalid gid '$RawGid'. Use a positive integer Linux GID."
    }
    $GidNumber = $ParsedGid
  } elseif ($null -ne $ExistingGroup -and -not [string]::IsNullOrWhiteSpace([string]$ExistingGroup.gidNumber)) {
    $GidNumber = [int]$ExistingGroup.gidNumber
  } elseif ([bool](Get-JsonProperty $Group "__auto_private_group" $false)) {
    $GidNumber = Get-NextAvailableId $UsedPrimaryGidNumbers $PrimaryGidRange "user primary GID"
  } else {
    $GidNumber = Get-NextAvailableId $UsedGroupGidNumbers $GroupGidRange "group GID"
  }

  if ([bool](Get-JsonProperty $Group "__auto_private_group" $false)) {
    Add-UsedId $UsedPrimaryGidNumbers $GidNumber
  } else {
    Add-UsedId $UsedGroupGidNumbers $GidNumber
  }

  $GidKey = [string]$GidNumber
  if ($DesiredGidNumbers.ContainsKey($GidKey)) {
    throw "Duplicate gid $GidNumber declared or allocated for groups $($DesiredGidNumbers[$GidKey]) and $Name."
  }

  $DesiredGidNumbers[$GidKey] = $Name
  $Group | Add-Member -NotePropertyName __desired_gid_number -NotePropertyValue $GidNumber -Force
}

foreach ($User in $NormalUsers) {
  $Username = [string](Get-JsonProperty $User "username" "")
  $PrivateGroup = $UserPrivateGroupByUsername[$Username]
  $PrimaryGidNumber = [int](Get-JsonProperty $PrivateGroup "__desired_gid_number" 0)
  if ($PrimaryGidNumber -le 0) {
    throw "Could not allocate primary GID for user $Username."
  }
  $User | Add-Member -NotePropertyName __desired_gid_number -NotePropertyValue $PrimaryGidNumber -Force
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

foreach ($Group in $DesiredGroups) {
  $Name = [string](Get-JsonProperty $Group "name" "")
  $SamAccountName = [string](Get-JsonProperty $Group "sam_account_name" $Name)
  $Path = Get-ObjectPath $Group ([string]$State.base_dn)
  $Description = Get-JsonProperty $Group "description" $null
  $Scope = [string](Get-JsonProperty $Group "scope" "Global")
  $Category = [string](Get-JsonProperty $Group "category" "Security")
  $GidNumber = [int](Get-JsonProperty $Group "__desired_gid_number" 0)

  if ([string]::IsNullOrWhiteSpace($Name)) {
    throw "Group entry is missing name."
  }

  $EscapedSam = Escape-LdapFilterValue $SamAccountName
  $Existing = Get-ADGroup -LDAPFilter "(sAMAccountName=$EscapedSam)" -Properties Description,GroupScope,GroupCategory,gidNumber -ErrorAction SilentlyContinue
  if ($null -eq $Existing) {
    Invoke-DirectoryChange "Create group $Name" {
      $NewGroupParams = @{
        Name = $Name
        SamAccountName = $SamAccountName
        Path = $Path
        GroupScope = $Scope
        GroupCategory = $Category
        Description = $Description
      }
      if ($GidNumber -gt 0) { $NewGroupParams.OtherAttributes = @{ gidNumber = $GidNumber } }
      New-ADGroup @NewGroupParams
    }
    continue
  }

  $SetParams = @{
    Identity = $Existing.DistinguishedName
  }
  if ($null -ne $Description -and $Existing.Description -ne $Description) { $SetParams.Description = $Description }

  if ($SetParams.Keys.Count -gt 1) {
    Invoke-DirectoryChange "Update group attributes $Name" {
      Set-ADGroup @SetParams
    }
  }

  if ($GidNumber -gt 0 -and [string]$Existing.gidNumber -ne [string]$GidNumber) {
    Invoke-DirectoryChange "Update group gidNumber $Name" {
      Set-ADGroup -Identity $Existing.DistinguishedName -Replace @{ gidNumber = $GidNumber }
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
  $UidNumber = [int](Get-JsonProperty $User "__desired_uid_number" 0)
  $GidNumber = [int](Get-JsonProperty $User "__desired_gid_number" 0)

  $EscapedUser = Escape-LdapFilterValue $Username
  $Existing = Get-ADUser -LDAPFilter "(sAMAccountName=$EscapedUser)" -Properties GivenName,Surname,DisplayName,EmailAddress,Description,UserPrincipalName,Enabled,PasswordNeverExpires,uidNumber,gidNumber -ErrorAction SilentlyContinue

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
      $OtherAttributes = @{}
      if ($UidNumber -gt 0) { $OtherAttributes.uidNumber = $UidNumber }
      if ($GidNumber -gt 0) { $OtherAttributes.gidNumber = $GidNumber }
      if ($OtherAttributes.Count -gt 0) { $NewUserParams.OtherAttributes = $OtherAttributes }
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

    if ($UidNumber -gt 0 -and [string]$Existing.uidNumber -ne [string]$UidNumber) {
      Invoke-DirectoryChange "Update user uidNumber $Username" {
        Set-ADUser -Identity $Existing.DistinguishedName -Replace @{ uidNumber = $UidNumber }
      }
    }

    if ($GidNumber -gt 0 -and [string]$Existing.gidNumber -ne [string]$GidNumber) {
      Invoke-DirectoryChange "Update user gidNumber $Username" {
        Set-ADUser -Identity $Existing.DistinguishedName -Replace @{ gidNumber = $GidNumber }
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
