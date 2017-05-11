#requires -Version 5
Configuration ConfigureAlwaysOnCluster
{
    param (

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [String]$ClusterName,

		[Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [UInt32]$DatabaseEnginePort,
		        
        [Parameter(Mandatory)]
        [String]$DatabaseNames,

		[Parameter(Mandatory)]
        [String]$DNSServerName,

        [Parameter(Mandatory)]
        [String]$fileShareWitness,

		[Parameter(Mandatory)]
        [String]$InstanceName,

		[Parameter(Mandatory)]
        [String]$LBName,

		[Parameter(Mandatory)]
        [String]$LBAddress,

		[Parameter(Mandatory)]
        [String]$Secondary,

        [Parameter(Mandatory)]
        [String]$SharePath,

        [Parameter(Mandatory)]
        [String]$SqlAlwaysOnAvailabilityGroupListenerName,

        [Parameter(Mandatory)]
        [UInt32]$SqlAlwaysOnAvailabilityGroupListenerPort,
				
        [Parameter(Mandatory)]
        [String]$SqlAlwaysOnAvailabilityGroupName,

        [Parameter(Mandatory)]
        [String]$SqlAlwaysOnEndpointName,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$SQLServiceCreds,

        [Parameter(Mandatory)]
        [String]$StaticIPAddress,

        [Parameter(Mandatory)]
        [String]$WorkloadType,

        [String]$DomainNetbiosName=(Get-NetBIOSName -DomainName $DomainName),
		[Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30

    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cDisk, xActiveDirectory, xComputerManagement, xDisk, xFailoverCluster, xNetworking, xSql, xSQLps, xSQLServer
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SQLServicecreds.UserName)", $SQLServicecreds.Password)

    Enable-CredSSPNTLM -DomainName $DomainName

    Node localhost
    {

        # Set LCM to reboot if needed
        LocalConfigurationManager
        {
            RebootNodeIfNeeded      = $true
        }

        WindowsFeature "ADTools"
        {
            Ensure                  = "Present"
            Name                    = "RSAT-AD-PowerShell"
        }

        WindowsFeature FailoverFeature
        {
            Ensure                  = "Present"
            Name                    = "Failover-clustering"
        }

        WindowsFeature RSATClusteringMgmt
        {
            Ensure                  = "Present"
            Name                    = "RSAT-Clustering-Mgmt"

            DependsOn               = "[WindowsFeature]FailoverFeature"
        }

        WindowsFeature RSATClusteringPowerShell
        {
            Ensure                  = "Present"
            Name                    = "RSAT-Clustering-PowerShell"

            DependsOn               = "[WindowsFeature]FailoverFeature"
        }

        WindowsFeature RSATClusteringCmdInterface
        {
            Ensure                  = "Present"
            Name                    = "RSAT-Clustering-CmdInterface"

            DependsOn               = "[WindowsFeature]RSATClusteringPowerShell"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName              = $DomainName
            DomainUserCredential    = $DomainCreds
            RetryCount              = 20
            RetryIntervalSec        = 30

            DependsOn               = "[WindowsFeature]ADTools"
        }

        xComputer DomainJoin
        {
            Name                    = $env:COMPUTERNAME
            DomainName              = $DomainName
            Credential              = $DomainCreds

            DependsOn               = "[xWaitForADDomain]DscForestWait"
        }

        xFirewall DatabaseEngineFirewallRule
        {
            Name                    = "SQL-Server-Database-Engine-TCP-In"
            DisplayName             = "SQL Server Database Engine (TCP-In)"
            Group                   = "SQL Server"
            Ensure                  = "Present"
            Enabled                 = "True"
            Profile                 = ("Domain", "Private")
            Direction               = "Inbound"
            LocalPort               = $DatabaseEnginePort -as [String]
            Protocol                = "TCP"
            Description             = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
        }

        xFirewall DatabaseMirroringFirewallRule
        {
            Name                    = "SQL-Server-Database-Mirroring-TCP-In"
            DisplayName             = "SQL Server Database Mirroring (TCP-In)"
            Group                   = "SQL Server"
            Ensure                  = "Present"
            Enabled                 = "True"
            Profile                 = ("Domain", "Private")
            Direction               = "Inbound"
            LocalPort               = "5022"
            Protocol                = "TCP"
            Description             = "Inbound rule for SQL Server to allow TCP traffic for the Database Mirroring."
        }

        xFirewall ListenerFirewallRule
        {
            Name                    = "SQL-Server-Availability-Group-Listener-TCP-In"
            DisplayName             = "SQL Server Availability Group Listener (TCP-In)"
            Group                   = "SQL Server"
            Ensure                  = "Present"
            Enabled                 = "True"
            Profile                 = ("Domain", "Private")
            Direction               = "Inbound"
            LocalPort               = "59999"
            Protocol                = "TCP"
            Description             = "Inbound rule for SQL Server to allow TCP traffic for the Availability Group listener."
        }

        xSQLServerLogin AddDomainAdminAccountToSysadminServerRole
        {
            Ensure                  = "Present"
            Name                    = $DomainCreds.UserName
            LoginType               = "WindowsUser"
            SQLServer               = $env:COMPUTERNAME
            SQLInstanceName         = $InstanceName
            LoginCredential         = $DomainCreds
        }

        xADUser CreateSqlServerServiceAccount
        {
            DomainAdministratorCredential = $DomainCreds
            DomainName              = $DomainName
            UserName                = $SQLCreds.UserName
            Password                = $SQLCreds
            Ensure                  = "Present"

            DependsOn               = "[xSQLServerLogin]AddDomainAdminAccountToSysadminServerRole"
        }

        xSQLServerLogin AddSqlServerServiceAccountToSysadminServerRole
        {
            Ensure                  = "Present"
            Name                    = $SQLCreds.UserName
            LoginType               = "WindowsUser"
            SQLServer               = $env:COMPUTERNAME
            SQLInstanceName         = $InstanceName
            LoginCredential         = $DomainCreds

            DependsOn               = "[xADUser]CreateSqlServerServiceAccount"
        }

        xSqlTsqlEndpoint AddSqlServerEndpoint
        {
            InstanceName            = $InstanceName
            PortNumber              = $DatabaseEnginePort
            SqlAdministratorCredential = $DomainCreds

            DependsOn               = "[xSQLServerLogin]AddSqlServerServiceAccountToSysadminServerRole"
        }

        xSQLServerStorageSettings AddSQLServerStorageSettings
        {
            InstanceName            = $InstanceName
            OptimizationType        = $WorkloadType

            DependsOn               = "[xSqlTsqlEndpoint]AddSqlServerEndpoint"
        }

        xCluster ensureCreated
        {
            Name                    = $ClusterName
            StaticIPAddress         = $StaticIPAddres
            DomainAdministratorCredential = $DomainCreds
        }

        xClusterQuorum FailoverClusterQuorum
        {
            IsSingleInstance        = "Yes"
            Type                    = "NodeAndFileShareMajority"
            Resource                = "\\$($fileShareWitness)\$($SharePath)"

            DependsOn               = "[xCluster]ensureCreated"
        }

        xSQLServerAlwaysOnService CreateAlwaysOnService
        {
            Ensure                  = "Present"
            SQLServer               = $env:COMPUTERNAME
            SQLInstanceName         = $InstanceName

            DependsOn               = "[xCluster]ensureCreated"
        }

        xSQLAddListenerIPToDNS AddLoadBalancer
        {
            LBName                  = $LBName
            Credential              = $DomainCreds
            LBAddress               = $LBAddress
            DNSServerName           = $DNSServer
            DomainName              = $DomainName

            DependsOn               = "[xSQLServerAlwaysOnService]CreateAlwaysOnService"
        }

        xSQLServerEndpoint CreateEndPoint
        {
            Ensure                  = "Present"
            Port                    = 5022
            AuthorizedUser          = $DomainCreds.UserName
            EndPointName            = $SqlAlwaysOnEndpointName

            DependsOn = "[xSQLServerAlwaysOnService]CreateAlwaysOnService"
        }

        xSQLServerAlwaysOnAvailabilityGroup CreateAlwaysOnAvailabilityGroup
        {
            Ensure                  = "Present"
            Name                    = $SqlAlwaysOnAvailabilityGroupName
            SQLServer               = $env:COMPUTERNAME
            SQLInstanceName         = $InstanceName

            DependsOn               = "[xSQLServerEndpoint]CreateEndPoint"
        }

        xSqlNewAGDatabase ConfigAGDatabase
        {
            SqlAlwaysOnAvailabilityGroupName = $SqlAlwaysOnAvailabilityGroupName
            DatabaseNames           = $DatabaseNames
            PrimaryReplica          = $env:COMPUTERNAME
            SecondaryReplica        = "$($Secondary),$($DatabaseEnginePort)"
            SqlAdministratorCredential = $SQLCreds

            DependsOn               = "[xSQLServerAlwaysOnAvailabilityGroup]CreateAlwaysOnAvailabilityGroup"
        }

        xSQLAOGroupEnsure EnsureAlwaysOnGroup
        {
            Ensure = "Present"
            AvailabilityGroupName   = $SqlAlwaysOnAvailabilityGroupName
            AvailabilityGroupNameListener = $SqlAlwaysOnAvailabilityGroupListenerName
            AvailabilityGroupNameIP = $LBAddress
            AvailabilityGroupPort   = $SqlAlwaysOnAvailabilityGroupListenerPort
            EndPointPort            = 5022
            SetupCredential         = $DomainCreds

            DependsOn = "[xSqlNewAGDatabase]ConfigAGDatabase"
        }
			        
    }

}

Function Get-NetBIOSName
{
    [OutputType([string])]
    param
    (
        [string]$DomainName
    )

    if ($DomainName.Contains('.'))
    {
        $length=$DomainName.IndexOf('.')
        if ($length -ge 16)
        {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    } else
    {
        if ($DomainName.Length -gt 15)
        {
            return $DomainName.Substring(0,15)
        } else
        {
            return $DomainName
        }
    }
}

function Enable-CredSSPNTLM
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$DomainName
    )

    # This is needed for the case where NTLM authentication is used

    Write-Verbose 'STARTED:Setting up CredSSP for NTLM'

    Enable-WSManCredSSP -Role client -DelegateComputer localhost, *.$DomainName -Force -ErrorAction SilentlyContinue
    Enable-WSManCredSSP -Role server -Force -ErrorAction SilentlyContinue

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name '\CredentialsDelegation' -ErrorAction SilentlyContinue
    }

    if( -not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -value "wsman/$env:COMPUTERNAME" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -value "wsman/localhost" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -value "wsman/*.$DomainName" -PropertyType string -ErrorAction SilentlyContinue
    }

    Write-Verbose "DONE:Setting up CredSSP for NTLM"
}
