'# FILENAME:    check_users.vbs
'# AUTHOR:              Bennett Samowich <bennett@foolean.org>
'# DATE:                2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the number of logged in users
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_users.vbs [OPTIONS]
'#
'#   Where:
'#      /C [NUM]        - Critical number of users
'#      /N              - Display output in NSCA output
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /V              - Display version information
'#      /W [NUM]        - Warning number of users
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
Dim intCrit         '# Critical level
Dim intWarn         '# Warning level
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message
Dim intStatus       '# Nagios status code
Dim strMessage      '# Nagios status message
Dim intNumUsers     '# Number of active users

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "users"

'# NSCA or Nagios format
intNSCA = 0

'# Critical and warning levels
intCrit = 2
intWarn = 1

'# Nagios status
dim strReturnCode(4)
strReturnCode(0) = "OK"
strReturnCode(1) = "WARNING"
strReturnCode(2) = "CRITICAL"
strReturnCode(3) = "UNKNOWN"

'# Get the hostname
Set objNTInfo = CreateObject("WinNTSystemInfo")
strHostName = lcase(objNTInfo.ComputerName)

'# Parse the command-line arguments
dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
            Case "/C"
                ArgIndex = ArgIndex + 1
                intCrit = Int(Args(ArgIndex))
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
                intWarn = Int(Args(ArgIndex))
            Case "/?"
                Usage
            Case else
                WScript.Echo "unknown argument '" & Args(ArgIndex) & "'"
                Usage
        End Select
    Next
End If

'# Get the number of logged on users
intNumUsers = GetNumUsers()

'# Determine the status
intStatus = 0
If intNumUsers >= intCrit Then
    intStatus = 2
ElseIf intNumUsers >= intWarn Then
    intStatus = 1
End If
strMessage = intNumUsers & " users currently logged in"

'# Write an event log
LogEvent intStatus, strHostName & _
                    " " & strTag & " " & _
                     strReturnCode(intStatus) & _
                    " " & strMessage

'# NSCA gets slightly different output
If intNSCA Then
    Wscript.Echo "" & _
    strHostName & _
    " users " & _
    intStatus & _
    " " & strMessage
Else
    Wscript.Echo "" & _
    "users " & _
    strReturnCode(intStatus) & _
    ": " & strMessage
End If

WScript.Quit intStatus

'# GetNumUsers - return the number of logged on users
'# 
'# Note: Win32_LogonSession does not accurately reflect the number of
'#       logged on users.  Instead, we count the number of processes
'#       with the name 'explorer.exe'.
Function GetNumUsers
    Dim objWMI          '# WMI object for getting the number of users
    Dim strQuery        '# Query to search for active sessions
    Dim colSessions     '# Collection of session objects
    
    Set objWMI = GetObject("winmgmts:\\.\root\cimv2") 
    strQuery = "Select Name from Win32_Process Where Name='explorer.exe'"
    Set colSessions = objWMI.ExecQuery( strQuery ) 
    GetNumUsers = colSessions.Count
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
    WScript.Echo "  /C [NUM]        - Critical number of users"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /W [NUM]        - Warning number of users"
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
