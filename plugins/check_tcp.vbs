'# FILENAME:    check_tcp.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor a remote tcp port
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_tcp.vbs [OPTIONS]
'#
'#   Where:
'#      /H [HOST]       - Host to check
'#      /N              - Display output in NSCA output
'#      /P [PORT]       - TCP port to check
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
Dim strHost         '# Host to check
Dim intPort         '# Port to check
Dim intStatus       '# Nagios status code
Dim strMessage      '# Nagios status message
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message
Dim intResult       '# Result of the port check

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "tcp"

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

'# Parse the command-line arguments
Dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))                
            Case "/H"
                ArgIndex = ArgIndex + 1
                strHost = Args(ArgIndex)            
            Case "/N"
                intNSCA = 1
            Case "/P"
                ArgIndex = ArgIndex + 1
                intPort = Int(Args(ArgIndex))   
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

'# We must have a host and port
If IsEmpty( strHost ) Then
    WScript.Echo "Error, No host provided"
    WScript.Quit 3
End If
If IsEmpty( intPort ) Then
    WScript.Echo "Error, No port provided"
    WScript.Quit 3
End If

'# Check the port
intResult = CheckTCP( strHost, intPort )

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName & "_" & intPort
End If

'# Determine our result
intStatus = 3
Select Case intResult
    Case 0
        strMessage = strHost & ":" & intPort & " is listening"
        intStatus  = 0
    Case 1
        strMessage = strHost & ":" & intPort & " is not listening"
        intStatus  = 2
    Case 2
        strMessage = strHost & ":" & intPort & " is probably being filtered"
        intStatus  = 2
    Case Else
        strMessage = strHost & ":" & intPort & " returned  a strange (" & intResult & ")"
End Select

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

Function CheckTCP( strHost, intPort )
    Dim strScriptDir    '# Directory where this script is
    Dim strPortQuery    '# Full path to the portqry command
    Dim WshShell        '# WScript.Shell object
    Dim strCmd          '# Full command to execute
    Dim intResult       '# Exit code from the command
    
    '# Get the scripts directory
    strScriptDir = left(WScript.ScriptFullName,(Len(WScript.ScriptFullName))-(len(WScript.ScriptName)))
    
    '# Assemble the path to portqry.exe
    strPortQuery = chr(34) & strScriptDir & "..\bin\PortQry.exe" & chr(34)

    '# Run the command
    Set WshShell = WScript.CreateObject("WScript.Shell")
    strCmd = strPortQuery & " -n " & strHost & " -e " & intPort & " -p tcp -q"
    intResult = WshShell.Run(strCmd, 0, true)
    
    '# Return the result
    CheckTCP = intResult
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
    WScript.Echo "  /H [HOST]       - Host to check"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /T [TAG]        - Descriptive tag to add to the status"
    WScript.Echo "  /P [PORT]       - TCP port to check"
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
