'# FILENAME:    check_ipconfig.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the configuration of an interface
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_ipconfig.vbs [OPTIONS]
'#
'#   Where:
'#      /A [ADDR]       - Expected IP address
'#      /D              - Toggle expected DHCP state (default:False)
'#      /E              - Toggle expected Enabled state (default:True)
'#      /G [ADDR]       - Expected gateway address
'#      /I [NAME]       - Interface name to check
'#      /M [MASK]       - Expected netmask
'#      /N              - Display output in NSCA output
'#      /S [SVR[,SVR]]  - Expected DNS server list
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /V              - Display version information
'#      /X [SFX[,SFX]]  - Expected DNS suffix list
'#      /?              - Display help
'#
'#   Note: the output can be piped directly into send_nsca
'#
'# COPYRIGHT:
'#   This program is free software: you can redistribute it and/or modify
'#   it under the terms of the GNU General Puplic License as published by
'#   the Free Software Foundation, either version 3 of the License, or
'#   any later version.
'#
'#   This program is distributed in the hope that it will be useful,
'#   but WITHOUT ANY WARRANTY; without even the implied warranty of
'#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'#   GNU General Public License for more details.
'#
'#   You should have received a copy of the GNU General Public License
'#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
'#
'#############################################################################

'# Declare our variables
Option Explicit
Dim strVersion          '# Version of this script
Dim intNSCA             '# Flag to provide NSCA output
Dim objNTInfo           '# Object for getting the hostname of this system
Dim strHostName         '# Hostname of this server
Dim Args                '# Command-line arguments
Dim intIPEnabledState   '# Expected interface state
Dim intDHCPEnabledState '# Expected DHCP state
Dim strInterfaceName    '# Interface to check
Dim arrIPConfig         '# Array with the resulting configuration
Dim intStatus           '# Nagios status code
Dim strMessage          '# Nagios status message
Dim strAddress          '# Expected address of the interface
Dim strGateway          '# Expected gateway of the interface
Dim strNetmask          '# Expected netmask of the interface
Dim strDNSServerList    '# Expected DNS server list of the interface
Dim strDNSSuffixList    '# Expected DNS suffix list
Dim strCheckName        '# Base name of this check
Dim strTag              '# Descriptive tag to add to the status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "ipconfig"

'# NSCA or Nagios format
intNSCA = 0

'# Defaults
intIPEnabledState   = True      '# The interface should be enabled
intDHCPEnabledState = False     '# The interface should not use DHCP

'# Nagios status
Dim strReturnCode(4)
strReturnCode(0) = "OK"
strReturnCode(1) = "WARNING"
strReturnCode(2) = "CRITICAL"
strReturnCode(3) = "UNKNOWN"

'# Constants for the array location of 
'# the various elements of the interface
const intIPEnabled      = 0
const intDHCPEnabled    = 1
const intDNSHostName    = 2
const intDNSDomain      = 3
const intDNSServers     = 4
const intIPAddress      = 5
const intIPSubnet       = 6
const intDefaultGateway = 7
const intDNSSuffixes    = 8

'# Get the hostname
Set objNTInfo = CreateObject("WinNTSystemInfo")
strHostName = lcase(objNTInfo.ComputerName)

'# Parse the command-line arguments
Dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
            Case "/A"
                ArgIndex = ArgIndex + 1
                strAddress = Args(ArgIndex)                             
            Case "/D"
                intDHCPEnabledState = True
            Case "/E"
                intIPEnabledState = False
            Case "/G"
                ArgIndex = ArgIndex + 1
                strGateway = Args(ArgIndex)                             
            Case "/I"
                ArgIndex = ArgIndex + 1
                strInterfaceName = Args(ArgIndex)
            Case "/M"
                ArgIndex = ArgIndex + 1
                strNetmask = Args(ArgIndex)                             
            Case "/N"
                intNSCA = 1
            Case "/S"
                ArgIndex = ArgIndex + 1
                strDNSServerList = Args(ArgIndex)                               
            Case "/T"
                ArgIndex = ArgIndex + 1
                strTag = Args(ArgIndex)
            Case "/V"
                Version
                WScript.Quit 1
            Case "/X"
                ArgIndex = ArgIndex + 1
                strDNSSuffixList = Args(ArgIndex)                               
            Case "/?"
                Usage
            Case else
                WScript.Echo "unknown argument '" & Args(ArgIndex) & "'"
                Usage
        End Select
    Next
End If

'# We must have an interface name
If strComp(strInterfaceName, "" ) = 0 Then
    WScript.Echo "Error, No interface name provided"
    WScript.Quit 3
End If

'# We must have an address
If strComp(strAddress, "" ) = 0 Then
    WScript.Echo "Error, No address provided"
    WScript.Quit 3
End If

'# Get the current interface configuration
Set arrIPConfig = GetIPConfig( strInterfaceName )

'# Determine the status
intStatus = 0
strMessage = ""
'# Validate the enabled state of the interface
If arrIPConfig.Item(intIPEnabled) <> intIPEnabledState Then
    intStatus = 2
    strMessage = strMessage & "(enabled is " & _
        arrIPConfig.Item(intIPEnabled) & _
        ", should be " & intIPEnabledState & ") "
End If
'# Validate the dhcp state of the interface
If arrIPConfig.Item(intDHCPEnabled) <> intDHCPEnabledState Then
    intStatus = 2
    strMessage = strMessage & "(dhcp is " & _
        arrIPConfig.Item(intDHCPEnabled) & _
        ", should be " & intDHCPEnabledState & ") "
End If
'# Validate the IP address if requested to
If Not IsEmpty( strAddress ) Then
    If arrIPConfig.Item(intIPAddress) <> strAddress Then
        intStatus = 2
        strMessage = strMessage & "(address is " &_
            arrIPConfig.Item(intIPAddress) & _
            ", should be " & strAddress & ") "
    End If
End If
'# Validate the gateway is within the network
If IsInNetwork( arrIPConfig.Item(intDefaultGateway), _
                arrIPConfig.Item(intIPAddress),      _
                arrIPConfig.Item(intIPSubnet) ) Then
    intStatus = 2
    strMessage = strMessage & "(gateway " &_
        arrIPConfig.Item(intDefaultGateway) & " is outside " &_
        "of the network " & arrIPConfig.Item(intIPAddress) & "/" &_
        arrIPConfig.Item(intIPSubnet) & ") "
End If
'# Validate the gateway if requested to
If Not IsEmpty( strGateway ) Then
    If arrIPConfig.Item(intDefaultGateway) <> strGateway Then
        intStatus = 2
        strMessage = strMessage & "(gateway is " &_
            arrIPConfig.Item(intDefaultGateway) & _
            ", should be " & strGateway & ") "
    End If
End If
'# Validate the netmask if requested to
If Not IsEmpty( strNetmask ) Then
    If arrIPConfig.Item(intIPSubnet) <> strNetmask Then
        intStatus = 2
        strMessage = strMessage & "(netmask is " &_
            arrIPConfig.Item(intIPSubnet) & _
            ", should be " & strNetmask & ") "
    End If
End If
'# Validate the DNS server liste if requested to
If Not IsEmpty( strDNSServerList ) Then
    If arrIPConfig.Item(intDNSServers) <> strDNSServerList Then
        intStatus = 2
        strMessage = strMessage & "(dns servers are " &_
            arrIPConfig.Item(intDNSServers) & _
            ", should be " & strDNSServerList & ") "
    End If
End If
'# Validate the DNS suffix search list if requested to
If Not IsEmpty( strDNSSuffixList ) Then
    If arrIPConfig.Item(intDNSSuffixes) <> strDNSSuffixList Then
        intStatus = 2
        strMessage = strMessage & "(dns suffix list is " &_
            arrIPConfig.Item(intDNSSuffixes) & _
            ", should be " & strDNSSuffixList & ") "
    End If
End If

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName & "_" & strInterfaceName
End If

'# Set a normal message if everything is OK
If intStatus = 0 Then
    strMessage = "interface configuration is correct"
End If

'# Write an event log
LogEvent intStatus, strHostName & _
                    " " & strTag & " " & _
                     strReturnCode(intStatus) & _
                    " " & strMessage

'# NSCA gets slightly different output
If intNSCA Then
    Wscript.Echo "" & _
    strHostName & _
    " " & strTag & " " & _
    intStatus & _
    " " & strMessage
Else
    Wscript.Echo "" & _
    strTag & " " & _
    strReturnCode(intStatus) & _
    ": " & strMessage
End If
WScript.Quit intStatus

'# GetIPConfig - Get the interface's configuration (returns and ArrayList object)
Function GetIPConfig( strInterfaceName )
    Dim objWMIService           '# WMI Service object for selecting the interface
    Dim strQuery                '# Search string to select the interface
    Dim colItems                '# Collection of interface objects
    Dim objItem                 '# Interface object
    Dim arrResult               '# Array for storing results
    Dim strIfQuery              '# Search string to select interface configuration
    Dim colIfItems              '# Collection of interface configuration objects
    Dim objIfItem               '# Interface configuration object
    Dim strSep                  '# Separator used in generating the CSV result
    Dim strDNSServers           '# DNS server list
    Dim strDNSServer            '# DNS server when iterating over the list
    Dim strIPAddresses          '# IP address list of the interface
    Dim strIPAddress            '# IP address when iterating over the list
    Dim strIPSubnets            '# Netmask list of the interface
    Dim strIPSubnet             '# Netmask when iterating over the list
    Dim strDefaultIPGateways    '# Gateway list of the interface
    Dim strDefaultIPGateway     '# Gateway when iterating over the list
    Dim strDNSDomainSuffixes    '# DNS suffix list of the interface
    Dim strDNSDomainSuffix      '# DNS suffix when iterating over the list
    
    '# Search for the interface by name
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    strQuery = "Select * From Win32_NetworkAdapter Where NetConnectionID = '" & strInterfaceName & "'"
    Set colItems = objWMIService.ExecQuery(strQuery)

    '# Creat the ArrayList that we'll store our findings in
    Set arrResult = CreateObject("System.Collections.ArrayList")

    '# Iterate over the interfaces that we've found
    For Each objItem In colItems
        strIfQuery = "Select * from Win32_NetworkAdapterConfiguration where Description='" & objItem.Name & "'"
        Set colIfItems = objWMIService.ExecQuery(strIfQuery)
        For Each objIfItem In colIfItems
            arrResult.Add objIfItem.IPEnabled
            arrResult.Add objIfItem.DHCPEnabled
            arrResult.Add objIfItem.DNSHostName
            arrResult.Add objIfItem.DNSDomain
                        
            '# Get the list of DNS servers
            If Not IsNull(objIfItem.DNSServerSearchOrder) Then
                strSep = ""
                For Each strDNSServer In objIfItem.DNSServerSearchOrder
                    strDNSServers = strDNSServers & strSep & strDNSServer
                    If strSep = "" Then
                        strSep = ","
                    End If
                Next
                arrResult.Add strDNSServers
            Else
                arrResult.Add ""
            End If
                        
            '# Get the list of IP addresses
            If Not IsNull(objIfItem.IPAddress) Then 
                strSep = ""
                For Each strIPAddress In objIfItem.IPAddress
                    If IsIPAddress( strIPAddress ) Then
                        strIPAddresses = strIPAddresses & strSep & strIPAddress
                        If strSep = "" Then
                            strSep = ","
                        End If
                    End If
                Next
                arrResult.Add strIPAddresses
            Else
                arrResult.Add ""
            End If
                        
            '# Get the list of netmasks
            If Not IsNull(objIfItem.IPSubnet) Then 
                strSep = ""
                For Each strIPSubnet In objIfItem.IPSubnet
                    If IsIPAddress( strIPSubnet ) Then
                        strIPSubnets = strIPSubnets & strSep & strIPSubnet
                        If strSep = "" Then
                            strSep = ","
                        End If
                    End If
                Next
                arrResult.Add strIPSubnets
            Else
                arrResult.Add ""
            End If
                        
            '# Get the list of gateways
            If Not IsNull(objIfItem.DefaultIPGateway) Then 
                strSep = ""
                For Each strDefaultIPGateway In objIfItem.DefaultIPGateway
                    If IsIPAddress( strDefaultIPGateway ) Then
                        strDefaultIPGateways = strDefaultIPGateways & strSep & strDefaultIPGateway
                        If strSep = "" Then
                            strSep = ","
                        End If
                    End If
                Next
                arrResult.Add  strDefaultIPGateways
            Else
                arrResult.Add ""
            End If
                        
            '# Get the list of DNS suffixes
            If Not IsNull(objIfItem.DNSDomainSuffixSearchOrder) Then 
                strSep = ""
                For Each strDNSDomainSuffix In objIfItem.DNSDomainSuffixSearchOrder
                    strDNSDomainSuffixes = strDNSDomainSuffixes & strSep & strDNSDomainSuffix
                    If strSep = "" Then
                        strSep = ","
                    End If
                Next
                arrResult.Add  strDNSDomainSuffixes
            Else
                arrResult.Add ""
            End If

        Next
    Next
        
    '# Return our results
    Set GetIPConfig = arrResult
End Function

'# Helper function to determin if a string is an IP address
Function IsIPAddress(strIPAddress)
    Dim arrOctets   '# Array to hold octets of the IPv4 adddress
    Dim intOctet    '# Individual octet for numeric testing

    arrOctets = split(strIPAddress, ".")
    If UBound(arrOctets) = 3 Then
        For Each intOctet In arrOctets
            If Not IsNumeric(intOctet) Then
                IsIPAddress = false
                Exit Function
            End If
        Next
        IsIPAddress = true
        Exit Function
    End If
    IsIPAddress = false
End Function

'# Simple version function
Function Version
    WScript.Echo WScript.ScriptName & " v" & strVersion
End Function

'# Simple help function
Function Usage
    Version
    WScript.Echo "Usage: " & Wscript.ScriptName & "[OPTIONS]"
    WScript.Echo ""
    WScript.Echo "Where:"
    WScript.Echo "  /A [ADDR]       - Expected IP address"
    WScript.Echo "  /D              - Toggle expected DHCP state (default:False)"
    WScript.Echo "  /E              - Toggle expected Enabled state (default:True)"
    WScript.Echo "  /G [ADDR]       - Expected gateway address"
    WScript.Echo "  /I [NAME]       - Interface name to check"
    WScript.Echo "  /M [MASK]       - Expected netmask"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /S [SVR[,SVR]]  - Expected DNS server list"
    WScript.Echo "  /T [TAG]        - Descriptive tag to add to the status"
    WScript.Echo "  /X [SFX[,SFX]]  - Expected DNS suffix list"
    WScript.Echo "  /?              - Display help"

    WScript.Quit
End Function

'# LogEvent - Write an event log
Function LogEvent( intType, strLogMessage )
    Dim strLogType(4)   '# Nagios status code to log type mapping
    Dim WshShell        '# WScript.Shell object
    Dim strCommand      '# evencreate command to run
    
    '# Log types to Nagios status code mapping
    strLogType(0) = "SUCCESS"
    strLogType(1) = "WARNING"
    strLogType(2) = "ERROR"
    strLogType(3) = "WARNING"

    '# Create a WScript.Shell object
    Set WshShell = WScript.CreateObject("WScript.Shell")
    
    '# Assemble the eventcreate command
    strCommand = "eventcreate "                    & _
                 "/ID 100 "                        & _
                 "/T " & strLogType(intType) & " " & _
                 "/L APPLICATION "                 & _
                 "/SO " &  WScript.ScriptName & " " & _
                 "/D " &  Chr(34) & strLogMessage & Chr(34)

    '# Write the event log
    WshShell.Run strCommand, 0, true
End Function

'# IsInNetwork - Determine if two addresses are in the
'#               same network based on the netmask.
Function IsInNetwork( strAddress1, strAddress2, strNetmask )
    Dim strNetwork1
    Dim strNetwork2
    
    '# Calculate the network address for each address based on the netmask
    strNetwork1 = GetNetworkAddress( strAddress1, strNetmask )
    strNetwork2 = GetNetworkAddress( strAddress2, strNetmask )
   
    '# If the networks are the same then they're in the same network (Duh)
    If strNetwork1 = strNetwork2 Then
        IsInNetwork = 1
        Exit Function
    End If
    IsInNetwork = 0
End Function

'# GetNetworkAddress - Calculate the network address of an IP and netmask
Function GetNetworkAddress( strAddress, strNetmask )
    Dim arrAddress      '# Array for the address octets
    Dim arrNetmask      '# Array for the netmask octets
    Dim arrNetwork(3)   '# Array for the network octets
    Dim I               '# Simple counter
    
    '# Split the address and netmask into their octets
    arrAddress = Split( strAddress, "." )
    arrNetmask = Split( strNetmask, "." )
    
    '# Iterate over the octets calculating the network by
    '# OR-ing the address octets with the netmask octets
    If UBound(arrAddress) = 3 And UBound(arrNetmask) = 3 Then
        For I = 0 To 3
            arrNetwork(I) = arrAddress(I) And arrNetmask(I)
        Next
    End If
    
    '# Return the dotted-quad network address
    GetNetworkAddress = Join( arrNetwork, "." )
 End Function
