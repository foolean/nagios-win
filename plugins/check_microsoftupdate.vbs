'# FILENAME:    check_microsoftupdate.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the available updates from microsoft update
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_microsoftupdate.vbs [OPTIONS]
'#
'#   Where:
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
Dim strVersion              '# Version of this script
Dim intNSCA                 '# Flag to provide NSCA output
Dim objNTInfo               '# Object for getting the hostname of this system
Dim strHostName             '# Hostname of this server
Dim Args                    '# Command-line arguments
Dim intCriticalUpdates      '# Number of available critical updates
Dim intImportantUpdates     '# Number of available important updates
Dim intModerateUpdates      '# Number of available moderate updates
Dim intLowUpdates           '# Number of available low updates
Dim intUnspecifiedUpdates   '# Number of available unspecified updates
Dim intNumUpdates           '# Total number of available updates
Dim intStatus               '# Nagios status code
Dim strMessage              '# Nagios status message 
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "updates"

'# NSCA or Nagios format
intNSCA = 0

'# Nagios status
Dim strReturnCode(4)
strReturnCode(0) = "OK"
strReturnCode(1) = "WARNING"
strReturnCode(2) = "CRITICAL"
strReturnCode(3) = "UNKNOWN"

'# Get the hostname
Set objNTInfo = CreateObject("WinNTSystemInfo")
strHostName = lcase(objNTInfo.ComputerName)

'# Initialize update type counters
intCriticalUpdates    = 0
intImportantUpdates   = 0
intModerateUpdates    = 0
intLowUpdates         = 0
intUnspecifiedUpdates = 0

'# Parse the command-line arguments
Dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
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

'# Get the number of available updates
intNumUpdates = GetUpdateCounts()

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName
End If

'# Determine the status
intStatus = 0
If intLowUpdates > 0 Or intUnspecifiedUpdates Then
    intStatus = 1
End If
If intCriticalUpdates > 0 Or intImportantUpdates > 0 Or intModerateUpdates > 0 Then
    intStatus = 2
End If
strMessage = intNumUpdates & " updates available (" & _
        "critical:" & intCriticalUpdates    & ", " & _
        "important:" & intImportantUpdates   & ", " & _
        "moderate:" & intModerateUpdates    & ", " & _
        "low:" & intLowUpdates         & ", " & _
        "unspecified:" & intUnspecifiedUpdates & ")"

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

'# GetUpdateCounts - Get the number of available updates
Function GetUpdateCounts
    Dim updateSession   '# Update.Session object
    Dim updateSearcher  '# Seacher object
    Dim searchResult    '# Result object
    Dim objUpdates      '# Collection of update objects
    Dim objUpdate       '# Update object
    
    intNumUpdates = 0
    Set updateSession  = CreateObject("Microsoft.Update.Session")
    Set updateSearcher = updateSession.CreateupdateSearcher()
    Set searchResult   = updateSearcher.Search("(IsInstalled=0)")
    Set objUpdates     = CreateObject("Microsoft.Update.UpdateColl")

    For Each objUpdate In searchResult.Updates
        Select Case objUpdate.MsrcSeverity
            Case "Critical"
                intCriticalUpdates = intCriticalUpdates + 1
            Case "Important"
                intImportantUpdates = intImportantUpdates + 1
            Case "Moderate"
                intModerateUpdates = intModerateUpdates + 1
            Case "Low"
                intLowUpdates = intLowUpdates + 1
            Case Else
                intUnspecifiedUpdates = intUnspecifiedUpdates + 1
        End Select
        intNumUpdates = intNumUpdates + 1
        objUpdates.Add(objUpdate)
    Next

    GetUpdateCounts = intNumUpdates
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
