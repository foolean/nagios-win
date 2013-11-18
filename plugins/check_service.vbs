'# FILENAME:    check_service.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the state of a service
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_service.vbs [OPTIONS]
'#
'#   Where:
'#      /N              - Display output in NSCA output
'#      /R              - Toggle running state to 'stopped'
'#      /S [NAME]       - Short name of the service to check
'#      /T [TAG]        - Descriptive tag to add to the status
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
Dim strVersion      '# Version of this script
Dim intNSCA         '# Flag to provide NSCA output
Dim objNTInfo       '# Object for getting the hostname of this system
Dim strHostName     '# Hostname of this server
Dim Args            '# Command-line arguments
Dim intRunning      '# Default running state
Dim strServiceName  '# Service to check
Dim intIsRunning    '# Running state of the service
Dim strStateOK      '# Status text for OK response
Dim strStateCrit    '# Status text for CRITICAL response
Dim strState        '# Status text based on the state of the service
Dim intStatus       '# Nagios status code
Dim strMessage      '# Nagios status message
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "svc"

'# NSCA or Nagios format
intNSCA = 0

'# Service should be running
intRunning = 1

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
            Case "/N"
                intNSCA = 1
            Case "/R"
                intRunning = 0
            Case "/S"
                ArgIndex = ArgIndex + 1
                strServiceName = Args(ArgIndex)
            Case "/T"
                ArgIndex = ArgIndex + 1
                strTag = Args(ArgIndex)
            Case "/V"
                Version
                WScript.Quit 1
            Case "/?"
                Usage
            Case else
                WScript.Echo "unknown argument '" & Args(ArgIndex) & "'"
                Usage
        End Select
    Next
End If

'# We must have a service name
If strComp(strServiceName, "" ) = 0 Then
    WScript.Echo "Error, No service name provided"
    WScript.Quit 3
End If

'# Get the state of the service
intIsRunning = isServiceRunning(strServiceName)

'# Success and failure state text
If intRunning = 1 Then
    strStateOK   = "is running"
    strStateCrit = "is stopped, should be running"
Else
    strStateOK   = "is stopped"
    strStateCrit = "is running, should be stopped"
End If

'# Determine the status
intStatus = 0
strState  = strStateOK
If intIsRunning <> intRunning Then
    strState = strStateCrit
    intStatus = 2
End If
strMessage = strServiceName & " " & strState

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName & "_" & strServiceName
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

'# Get the status of the service
Function isServiceRunning(strServiceName)
    Dim objWMIService, strWMIQuery

    strWMIQuery = "Select * from Win32_Service Where Name = '" & strServiceName & "' and state='Running'"

    Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")

    If objWMIService.ExecQuery(strWMIQuery).Count > 0 Then
        isServiceRunning = 1
    Else
        isServiceRunning = 0
    End If
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
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /R              - Toggle running state to 'stopped'"
    WScript.Echo "  /S [NAME]       - Short name of the service to check"  
    WScript.Echo "  /T [TAG]        - Descriptive tag to add to the status"
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
