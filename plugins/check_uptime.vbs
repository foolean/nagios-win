'# FILENAME:    check_uptime.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the uptime of a system.
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_uptime.vbs [OPTIONS]
'#
'#   Where:
'#      /C [CRIT]       - Critical seconds of uptime
'#      /N              - Display output in NSCA output
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /V              - Display version information
'#      /W [WARN]       - Warning seconds of uptime
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
Dim intUptime       '# Number of seconds the system has been up
Dim intStatus       '# Nagios status code
Dim strMessage      '# Nagios status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "uptime"

'# NSCA or Nagios format
intNSCA = 0

'# Critical and warning levels
intCrit = 3600
intWarn = 86400

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

'# Get the uptime
intUptime = GetUptime()

'# Determine the status
intStatus = 0
If intUptime < intCrit Then
    intStatus = 2
ElseIf intUptime < intWarn Then
    intStatus = 1
End If
strMessage = "The system has been up for " & _
             SecondsToHuman(intUptime) & _
             " (" & intUptime & "s)"

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName
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

'# Get the uptime of the system in seconds
Function GetUptime
    Dim objWMIDateTime  '# Date/Time object
    Dim objWMI          '# WMI object for getting OS information
    Dim colOS           '# Collection of OS objects
    Dim objOS           '# Operating system object
    
    Set objWMIDateTime = CreateObject("WbemScripting.SWbemDateTime")
    Set objWMI         = GetObject("winmgmts:\\.\root\cimv2")
    Set colOS          = objWMI.InstancesOf("Win32_OperatingSystem")

    For Each objOS In colOS
        objWMIDateTime.Value = objOS.LastBootUpTime

        '# Return the uptime in seconds
        GetUptime = Abs(DateDiff("S",objWMIDateTime.GetVarDate,Now))
    Next
End Function

'# Convert seconds to human readable days, hours, minutes, seconds
Function SecondsToHuman(intTime)
    Dim intDays     '# Number of days
    Dim intHours    '# Number of hours
    Dim intMinutes  '# Number of minutes
    Dim intSeconds  '# Number of seconds
    
    '# Compute the days, minutes, hours, and seconds
    intDays    = Int( intTime / 86400 )
    intHours   = Int( intTime / 3600 ) Mod 3600 
    intMinutes = Int( intTime / 60 ) Mod 60
    intSeconds = intTime Mod 60

    '# Generate and return the string
    SecondsToHuman = intDays    & " days "    & _
                     intHours   & " hours "   & _
                     intMinutes & " minutes " & _
                     intSeconds & " seconds"
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
    WScript.Echo "  /C [CRIT]       - Critical seconds of uptime"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /W [WARN]       - Warning seconds of uptime"
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
