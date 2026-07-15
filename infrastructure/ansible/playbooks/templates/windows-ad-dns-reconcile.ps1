param(
  [Parameter(Mandatory = $true)]
  [string]$StatePath,

  [bool]$CheckMode = $false
)

$ErrorActionPreference = "Stop"

function Write-Change {
  param([string]$Message)
  Write-Output "CHANGED: $Message"
  $script:Changed = $true
}

function Assert-RecordType {
  param([string]$Type)

  if ($Type -notin @("A", "CNAME")) {
    throw "Unsupported DNS record type '$Type'. Supported types: A, CNAME."
  }
}

function Get-DesiredState {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "DNS desired state file not found: $Path"
  }

  return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Normalize-StringList {
  param([object[]]$Items)

  return @($Items | ForEach-Object { [string]$_ } | Where-Object { $_ -ne "" } | Sort-Object -Unique)
}

Import-Module DnsServer

$State = Get-DesiredState -Path $StatePath
$script:Changed = $false

if (-not $State.zones -and -not $State.forwarders) {
  throw "DNS desired state must define forwarders and/or zones."
}

if ($null -ne $State.forwarders) {
  $DesiredForwarders = Normalize-StringList -Items @($State.forwarders)
  $CurrentForwarders = Normalize-StringList -Items @((Get-DnsServerForwarder).IPAddress)

  $MissingForwarders = @($DesiredForwarders | Where-Object { $_ -notin $CurrentForwarders })
  $ExtraForwarders = @($CurrentForwarders | Where-Object { $_ -notin $DesiredForwarders })

  if ($MissingForwarders.Count -gt 0 -or $ExtraForwarders.Count -gt 0) {
    Write-Change "Set DNS forwarders -> $($DesiredForwarders -join ', ')"
    if (-not $CheckMode) {
      Set-DnsServerForwarder -IPAddress $DesiredForwarders -UseRootHint $false
    }
  }
}

foreach ($Zone in @($State.zones)) {
  if (-not $Zone.name) {
    throw "Every DNS zone must define name."
  }

  $ZoneName = [string]$Zone.name
  $ExistingZone = Get-DnsServerZone -Name $ZoneName -ErrorAction SilentlyContinue
  if (-not $ExistingZone) {
    throw "DNS zone '$ZoneName' does not exist. Create the AD-integrated zone before managing records."
  }

  foreach ($Record in @($Zone.records)) {
    if (-not $Record.name) {
      throw "Every DNS record in zone '$ZoneName' must define name."
    }
    if (-not $Record.type) {
      throw "DNS record '$($Record.name)' in zone '$ZoneName' must define type."
    }
    if (-not $Record.value) {
      throw "DNS record '$($Record.name)' in zone '$ZoneName' must define value."
    }

    $Name = [string]$Record.name
    $Type = ([string]$Record.type).ToUpperInvariant()
    $Value = [string]$Record.value
    $StateValue = if ($Record.state) { [string]$Record.state } else { "present" }
    $TtlSeconds = if ($Record.ttl) { [int]$Record.ttl } else { 300 }
    $Ttl = New-TimeSpan -Seconds $TtlSeconds

    Assert-RecordType -Type $Type

    $ExistingRecords = @(Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $Name -RRType $Type -ErrorAction SilentlyContinue)

    if ($StateValue -eq "absent") {
      if ($ExistingRecords.Count -gt 0) {
        Write-Change "Remove $Type $Name.$ZoneName"
        if (-not $CheckMode) {
          foreach ($Existing in $ExistingRecords) {
            Remove-DnsServerResourceRecord -ZoneName $ZoneName -InputObject $Existing -Force
          }
        }
      }
      continue
    }

    if ($StateValue -ne "present") {
      throw "DNS record '$Name.$ZoneName' has unsupported state '$StateValue'. Use present or absent."
    }

    $MatchingRecords = @()
    foreach ($Existing in $ExistingRecords) {
      if ($Type -eq "A" -and [string]$Existing.RecordData.IPv4Address -eq $Value) {
        $MatchingRecords += $Existing
      }
      if ($Type -eq "CNAME" -and ([string]$Existing.RecordData.HostNameAlias).TrimEnd(".") -eq $Value.TrimEnd(".")) {
        $MatchingRecords += $Existing
      }
    }

    $NeedsReplace = $ExistingRecords.Count -gt 0 -and $MatchingRecords.Count -eq 0
    $NeedsCreate = $ExistingRecords.Count -eq 0
    $NeedsTtl = $MatchingRecords.Count -gt 0 -and $MatchingRecords[0].TimeToLive.TotalSeconds -ne $TtlSeconds

    if ($NeedsReplace) {
      Write-Change "Replace $Type $Name.$ZoneName -> $Value"
      if (-not $CheckMode) {
        foreach ($Existing in $ExistingRecords) {
          Remove-DnsServerResourceRecord -ZoneName $ZoneName -InputObject $Existing -Force
        }
      }
      $NeedsCreate = $true
    }

    if ($NeedsCreate) {
      Write-Change "Create $Type $Name.$ZoneName -> $Value"
      if (-not $CheckMode) {
        if ($Type -eq "A") {
          Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name $Name -IPv4Address $Value -TimeToLive $Ttl
        } elseif ($Type -eq "CNAME") {
          Add-DnsServerResourceRecordCName -ZoneName $ZoneName -Name $Name -HostNameAlias $Value -TimeToLive $Ttl
        }
      }
    } elseif ($NeedsTtl) {
      Write-Change "Update TTL for $Type $Name.$ZoneName -> $TtlSeconds"
      if (-not $CheckMode) {
        $Old = $MatchingRecords[0]
        $New = $Old.Clone()
        $New.TimeToLive = $Ttl
        Set-DnsServerResourceRecord -ZoneName $ZoneName -OldInputObject $Old -NewInputObject $New
      }
    }
  }
}

if ($script:Changed) {
  Write-Output "CHANGED=True"
} else {
  Write-Output "CHANGED=False"
}
