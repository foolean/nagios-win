'# FILENAME:    check_file.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor a file
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_file.vbs [OPTIONS]
'#
'#   Where:
'#      /c [SECONDS]    - Critical age in seconds
'#      /C [BYTES]      - Critical size in bytes
'#      /F [NAME]       - File name to check
'#      /N              - Display output in NSCA output
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /V              - Display version information
'#      /w [SECONDS]    - Warning age in seconds
'#      /W [BYTES]      - Warning size in bytes
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
Dim intAgeWarn      '# Warning level for file age
Dim intAgeCrit      '# Critical level for file age
Dim intSizeWarn     '# Warning level for file size
Dim intSizeCrit     '# Critical level for file size
Dim objNTInfo       '# Object for getting the hostname of this system
Dim strHostName     '# Hostname of this server
Dim Args            '# Command-line arguments
Dim intStatus       '# Nagios status
Dim strMessage      '# Nagios status message
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message
Dim strFileName     '# Full path of the file to check
Dim arrFileStats    '# Array of file stats

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "disk"

'# NSCA or Nagios format
intNSCA = 0

'# Critical and warning levels
intAgeCrit  = -1
intAgeWarn  = -1
intSizeWarn = -1
intSizeCrit = -1

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
dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
            Case "/c"
                ArgIndex = ArgIndex + 1
                intAgeCrit = Int(Args(ArgIndex))
            Case "/C"
                ArgIndex = ArgIndex + 1
                intSizeCrit = Int(Args(ArgIndex))
            Case "/F"
                ArgIndex = ArgIndex + 1
                strFileName = Args(ArgIndex)
            Case "/N"
                intNSCA = 1
            Case "/w"
                ArgIndex = ArgIndex + 1
                intAgeWarn = Int(Args(ArgIndex))
            Case "/W"
                ArgIndex = ArgIndex + 1
                intSizeWarn = Int(Args(ArgIndex))
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

'# We must have an file name
If IsEmpty( strFileName ) Then
    WScript.Echo "Error, No file name provided"
    WScript.Quit 3
End If

'# Check the file
arrFileStats = GetFileStats( strFileName )

'# Determine the status
intStatus = 0
If IsEmpty( arrFileStats ) Then
    intStatus = 2
    strMessage = "File not found - " & strFileName
Else
    strMessage = strFileName & " is " & arrFileStats(0) & " seconds old and " & arrFileStats(1) & " bytes"
    If intAgeCrit >= 0 And arrFileStats(0) >= intAgeCrit Then
        intStatus = 2
    ElseIf intAgeWarn >= 0 And arrFileStats(0) >= intAgeWarn Then
        intStatus = 1
    End If
    If intSizeCrit >= 0 And arrFileStats(1) >= intSizeCrit Then
        intStatus = 2
    ElseIf intSizeWarn >= 0 And arrFileStats(1) >= intSizeWarn Then
        intStatus = 1
    End If
End If

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName & "_" & strFileName
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

'# GetFileStats - Get the size in bytes and the 
'#                last modified time in seconds of a file
Function GetFileStats( strFileName )
    Dim objFSO      '# Filesystem object
    Dim objFile     '# File object
    
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    If objFSO.FileExists( strFileName ) Then
        Set objFile = objFSO.GetFile( strFileName )
        GetFileStats = Array( DateDiff("s", objFile.DateLastModified, Now), objFile.Size )
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
    WScript.Echo "  /c [SECONDS]    - Critical age in seconds"
    WScript.Echo "  /C [BYTES]      - Critical size in bytes"
    WScript.Echo "  /F [NAME]       - File name to check"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /w [SECONDS]    - Warning age in seconds"
    WScript.Echo "  /W [BYTES]      - Warning size in bytes"
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
