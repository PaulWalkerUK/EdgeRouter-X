Set-StrictMode -Version Latest

<#
.SYNOPSIS
Reads config data from a file

.DESCRIPTION
Reads the configuration data from a psd1 file

.PARAMETER dataFile
Specifies the file name.
#>
Function Get-Config {
    [CmdletBinding()]
    Param([string] $dataFile)

    Process {
        $script:config = Import-PowershellDataFile $dataFile -ErrorAction Stop
        Write-Verbose "Data file imported"
        $config.firewalls|%{$_.add("name", "$($_.from)-$($_.to)")}
    }
}


<#
.SYNOPSIS
Outputs details of a firewall

.DESCRIPTION
Almost like a toString() method, useful for debugging/testing

.PARAMETER firewall
The firewall to outpu

.OUTPUTS
System.String
#>
Function Out-FirewallToString {
    [CmdletBinding()]
    Param([string] $firewall)

    Process {
        ForEach ($fw in $firewalls) {
            If ($fw.name -eq $firewall) {
                
                "From:[$($fw.from)] " +
                "To:[$($fw.to)] " +
                "DefaultAction:[$($fw.defaultAction)] " +
                "LogDefault:[$($fw.logDefault)] " +
                "Rules:[$($fw.rules -join '][')]"
            }
        }
    }
}


<#
.SYNOPSIS
Verifies the correct firewalls have been defined

.DESCRIPTION
A firewall should be defined between each zone (one for each direction),
i.e. if there are 3 zones then there should be 6 firewalls.

Write-Warning is used to alert of any problems
#>
Function Test-CorrectFirewallsDefined {
    [CmdletBinding()]
    Param()

    Process {
        ForEach ($a in $config.zones) {
            ForEach ($b in $config.zones) {
                If ($a.zoneName -ne $b.zoneName) {
                    $matchingFirewalls = $config.firewalls|?{($_.from -eq $a.zoneName) -and ($_.to -eq $b.zoneName)}|measure|select -ExpandProperty count
                    If ($matchingFirewalls -ne 1) {
                        Write-Warning "Firewall [$($a.zoneName)-$($b.zoneName)] has been defined $matchingFirewalls times"
                    }
                }
            }
        }
    }
}


<#
.SYNOPSIS
Generates the commands to build the firewalls

.DESCRIPTION
Generates the CLI commands necessary to build the firewalls

.OUTPUTS
System.String[]
#>
Function Out-Commands {
    [CmdletBinding()]
    Param()

    Process {
        ForEach ($gen in $config.generic) {
            "set firewall $gen"
        }
        
        ForEach ($grp in $config.addressGroups) {
            "set firewall group address-group $($grp.groupName) description '$($grp.description)'"

            ForEach ($addr in $grp.addresses) {
                "set firewall group address-group $($grp.groupName) address $addr"
            }
        }

        ForEach ($grp in $config.portGroups) {
            "set firewall group port-group $($grp.groupName) description '$($grp.description)'"

            ForEach ($prt in $grp.ports) {
                "set firewall group port-group $($grp.groupName) port $prt"
            }
        }

        ForEach ($toZone in $config.zones) {
            "set zone-policy zone $($toZone.zoneName) default-action $($toZone.defaultAction)"
            
            If ($toZone.zoneName -eq "local") {
                "set zone-policy zone $($toZone.zoneName) $($toZone.interface)"
            }
            Else {
                "set zone-policy zone $($toZone.zoneName) interface $($toZone.interface)"
            }

            ForEach ($fromZone in $config.zones) {
                If ($fromZone.zoneName -ne $toZone.zoneName) {
                    "set zone-policy zone $($toZone.zoneName) from $($fromZone.zoneName) firewall name $($fromZone.zoneName)-$($toZone.zoneName)"

                    $fw = $config['firewalls']|?{($_.from -eq $fromZone.zoneName) -and ($_.to -eq $toZone.zoneName)}|select -First 1

                    If (($fw|measure).count -ne 0) {
                        "set firewall name $($fw.name) default-action $($fw.defaultAction)"
                        
                        If ($fw.logDefault) {
                            "set firewall name $($fw.name) enable-default-log"
                        }
                        
                        ForEach ($rule in $config.rules|sort {$_.number}) {
                            If ($rule.id -in $fw.rules) {
                                "set firewall name $($fw.name) rule $($rule.number) action $($rule.action)"
                                "set firewall name $($fw.name) rule $($rule.number) description '$($rule.description)'"
                                "set firewall name $($fw.name) rule $($rule.number) log $($rule.log)"

                                ForEach ($c in $rule.criteria) {
                                    "set firewall name $($fw.name) rule $($rule.number) $c"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


<#
.SYNOPSIS
Get commands to build firewalls for the supplied configuration

.DESCRIPTION
Generates commands to build the firewalls based on the specified configuration 
data.

.PARAMETER dataFile
Specifies the .psd1 file containing the configuration data.

.OUTPUT
System.String[]
#>
Function Get-Firewall {
Param([string] $dataFile)
    Get-Config -dataFile $dataFile
    Test-CorrectFirewallsDefined
    Out-Commands|sort
}