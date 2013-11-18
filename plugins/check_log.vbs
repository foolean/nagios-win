'# FILENAME:    check_eventlog.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the event log for new error and warning events
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_scheduledtasks.vbs [OPTIONS]
'#
'#   Where:
'#      /D [MINUTES]    - Duration to check for new logs
'#      /N              - Display output in NSCA output
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
Dim strCheckName    '# Base name of this check
Dim intDuration     '# Duration, in minutes, to check for new event logs
Dim arrLogCounts

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "task"

'# NSCA or Nagios format
intNSCA = 0

'# Nagios status
dim strReturnCode(4)
strReturnCode(0) = "OK"
strReturnCode(1) = "WARNING"
strReturnCode(2) = "CRITICAL"
strReturnCode(3) = "UNKNOWN"

'# Get the hostname
Set objNTInfo = CreateObject("WinNTSystemInfo")
strHostName = lcase(objNTInfo.ComputerName)

'# Defaults
intDuration = 5

'# Parse the command-line arguments
dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
            Case "/D"
                ArgIndex = ArgIndex + 1
                intDuration = Int(Args(ArgIndex))
            Case "/N"
                intNSCA = 1
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

'# Get the number event logs
arrLogCounts = GetLogCounts( intDuration )

'# Determine the status
intStatus = 0

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName & "_" & Replace(GetTaskName(strTaskPath), " ", "_")
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

'# GetEventCounts - Get the number of warning and error events
'#                  that occured in the past intDuration minutes
Function GetLogCounts( intDuration )
    Dim strLogDate      '# Date intDuration minutes ago
    Dim strDate         '# strLogDate in ISO format
    Dim strQuery        '# Base search query
    Dim objWMI          '# WMI object
    Dim colEvents       '# Collection of found events
    Dim arrLogs(1)      '# Array for results
    
    '# The duration should be a positive integer
    If intDuration < 0 Then
        intDuration = Abs(intDuration)
    End If
    
    '# Get the date/time of intDuration minutes ago in ISO8601 format
    strLogDate = DateAdd("n", intDuration * -1, Now())
    strDate    = DatePart("yyyy",strLogDate) _
        & Right("0" & DatePart("m", strLogDate), 2) _
        & Right("0" & DatePart("d", strLogDate), 2) _
        & Right("0" & DatePart("h", strLogDate), 2) _
        & Right("0" & DatePart("n", strLogDate), 2) _
        & Right("0" & DatePart("s", strLogDate), 2) _
        & ".000000-000"

    '# Assemble the date select portion of the query
    strQuery = "SELECT * FROM Win32_NTLogEvent" & _
               " WHERE TimeWritten >= '" & strDate & "' "

    '# Create a WMI object
    Set objWMI = GetObject("winmgmts:\\.\root\cimv2")

    '# Get the number of warning events
    Set colEvents = objWMI.ExecQuery(strQuery & "And Type = 'Warning'")
    arrLogs(0) = colEvents.Count

    '# Get the number of error events
    Set colEvents = objWMI.ExecQuery(strQuery & "And Type = 'Error'")
    arrLogs(1) = colEvents.Count

    '# Return the counts
    GetLogCounts = arrLogs
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
    WScript.Echo "  /D [MINUTES]    - Duration to check for new logs"
    WScript.Echo "  /N              - Display output in NSCA output"
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
