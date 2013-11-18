'# FILENAME:    check_ifutil.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor network utilization of an interface
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_ifutil.vbs [OPTIONS]
'#
'#   Where:
'#      /C [RX:TX]      - Critical RX and TX utilization percentage
'#      /I [NAME]       - Interface name
'#      /N              - Display output in NSCA output
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /W [RX:TX]      - Warning RX and TX utilization percentage
'#      /V              - Display version information
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
Dim strCheckName        '# Base name of this check
Dim strCrit             '# Critical level
Dim strWarn             '# Warning level
Dim strInterfaceName    '# Name of interface to check
Dim arrCrit             '# Array used to split critical levels
Dim arrWarn             '# Array used to split warning levels
Dim intRxCrit           '# Critical RX level
Dim intTxCrit           '# Critical TX level
Dim intRxWarn           '# Warning RX level
Dim intTxWarn           '# Warning TX level
Dim strUtil             '# Interface utilization
Dim arrUtil             '# Array used to split utilization levels
Dim intRxUtil           '# Current RX level
Dim intTxUtil           '# Current TX level
Dim intStatus           '# Nagios status code
Dim strMessage          '# Nagios status message
Dim strTag              '# Descriptive tag to add to the status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "bandwidth"

'# NSCA or Nagios format
intNSCA = 0

'# Critical and warning levels
strCrit = "75:75"
strWarn = "55:55"

'# Nagios status
Dim strReturnCode(4)
strReturnCode(0) = "OK"
strReturnCode(1) = "WARNING"
strReturnCode(2) = "CRITICAL"
strReturnCode(3) = "UNKNOWN"

'# Get the hostname
Set objNTInfo = CreateObject("WinNTSystemInfo")
strHostName = lcase(objNTInfo.ComputerName)

'# Parse the command-line arguments
Dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
            Case "/C"
                ArgIndex = ArgIndex + 1
                strCrit = Args(ArgIndex)
            Case "/I"
                ArgIndex = ArgIndex + 1
                strInterfaceName = Args(ArgIndex)
            Case "/N"
                intNSCA = 1
            Case "/T"
                ArgIndex = ArgIndex + 1
                strTag = Args(ArgIndex)
            Case "/V"
                Version
                WScript.Quit 1
            Case "/W"
                ArgIndex = ArgIndex + 1
                strWarn = Args(ArgIndex)
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

'# Split the critical values into RX and TX components
arrCrit = split( strCrit, ":", 2)
intRxCrit = Int(arrCrit(0))
intTxCrit = Int(arrCrit(1))

'# Split the warning values into RX and TX components
arrWarn = split( strWarn, ":", 2)
intRxWarn = Int(arrWarn(0))
intTxWarn = Int(arrWarn(1))

'# Split the current utilization
strUtil = GetUtilization(strInterfaceName)
arrUtil = split( strUtil, ":", 2)
intRxUtil = Int(arrUtil(0))
intTxUtil = Int(arrUtil(1))

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName & "_" & strInterfaceName
End If

'# Determine the status
intStatus = 0
If intRxUtil >= intRxWarn Or intTxUtil >= intTxWarn Then
    intStatus = 1
End If
If intRxUtil >= intRxCrit Or intTxUtil >= intTxCrit Then
    intStatus = 2
End If
strMessage = "rx:" & intRxUtil & "%, tx:" & intTxUtil & "%"

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

'# GetUtilization - Return the RX:TX utilization percentages
Function GetUtilization( strInterfaceName )
    Dim objWMIService       '# WMI Service object for selecting the interface
    Dim strQuery            '# Search string to select the interface
    Dim colItems            '# Collection of interface objects
    Dim objItem             '# Interface object
    Dim strName             '# Reformatted interface name
    Dim strPerfQuery        '# Search string to select interface statistics
    Dim colPerfItems        '# Collection of interface statistic object
    Dim objPerfItem         '# Interface statistic object
    Dim intRxUtilization    '# RX utilization
    Dim intTxUtilization    '# TX utilization
    
    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
    strQuery = "Select * From Win32_NetworkAdapter Where NetConnectionID = '" & strInterfaceName & "'"
    Set colItems = objWMIService.ExecQuery(strQuery)
    For Each objItem in colItems
        strName = Replace(objItem.Name, "(", "[")
        strName = Replace(strName, ")", "]")
        strName = Replace(strName, "#", "_")
        strName = Replace(strName, "/", "_")

        strPerfQuery = "Select * From Win32_PerfFormattedData_Tcpip_NetworkInterface Where Name = '" & strName & "'"
        Set colPerfItems = objWMIService.ExecQuery(strPerfQuery)

        For Each objPerfItem in colPerfItems
            intRxUtilization = Int(((objPerfItem.BytesReceivedPerSec * 8) / objPerfItem.CurrentBandwidth) * 100)
            intTxUtilization = Int(((objPerfItem.BytesSentPerSec * 8) / objPerfItem.CurrentBandwidth) * 100)

            GetUtilization = intRxUtilization & ":" & intTxUtilization
        Next
    Next
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
    WScript.Echo "  /C [RX:TX]      - Critical RX and TX utilization percentage"
    WScript.Echo "  /I [NAME]       - Interface name"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /T [TAG]        - Descriptive tag to add to the status"
    WScript.Echo "  /W [RX:TX]      - Warning RX and TX utilization percentage"
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
