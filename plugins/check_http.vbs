'# FILENAME:    check_http.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor the a remote web page
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_http.vbs [OPTIONS]
'#
'#   Where:
'#      /A [USER:PASS]  - Authentication credentials to use
'#      /E [CODE]       - Expected HTTP code (e.g. 200,302,401)
'#      /N              - Display output in NSCA output
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /U [URL]        - URL to check
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
Dim intExpect       '# Expected HTTP return code
Dim intStatus       '# Nagios status
Dim strURL          '# URL to check
Dim strProtocol     '# Protocol portion of the url
Dim strAuth         '# Authentication credentials
Dim strUsername     '# Username for authentication
Dim strPassword     '# Password for authentication
Dim intResult       '# Resulting HTTP return code
Dim strStatus       '# Nagios status code
Dim strMessage      '# Nagios status message
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "http"

'# NSCA or Nagios format
intNSCA = 0

'# Defaults
intExpect   = 200
strUsername = NULL
strPassword = NULL

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
            Case "/A"
                ArgIndex = ArgIndex + 1
                strAuth = Args(ArgIndex)                                
            Case "/E"
                ArgIndex = ArgIndex + 1
                intExpect = Int(Args(ArgIndex))                         
            Case "/N"
                intNSCA = 1
            Case "/T"
                ArgIndex = ArgIndex + 1
                strTag = Args(ArgIndex)
            Case "/U"
                ArgIndex = ArgIndex + 1
                strURL = Args(ArgIndex)         
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

'# We must have an URL
If strComp(strURL, "" ) = 0 Then
    WScript.Echo "Error, No url provided"
    WScript.Quit 3
End If

'# Use the protocol portion of the URL as the CheckName
strProtocol = Left(strURL, InStr(strURL, ":") - 1)
If strProtocol <> "" Then
    strCheckName = strProtocol
End If

'# Grab the authentication credentials if they were provided
If Not IsEmpty( strAuth ) Then
    arrCredentials = Split( strAuth, ":", 2 )
    strUsername = arrCredentials(0)
    strPassword = arrCredentials(1)
End If

'# Check the URL
intResult = CheckURL( strUrl, strUsername, strPassword)

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName
End If

'# Determine our result
intStatus = 0
strMessage = strURL & " returned HTTP-" & intResult
If intResult = 0 Then
    intStatus = 2
    strMessage = "unable to load " & strURL
ElseIf intResult <> intExpect Then
    intStatus = 2
    strMessage = "got HTTP-" & intResult & ", expected HTTP-" & intExpect
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

'# CheckURL - Check a web page
Function CheckURL( strURL, strUsername, strPassword )
    Dim objHTTP     '# HTTP object for retrieving URL
    
    Set objHTTP = CreateObject("MSXML2.XMLHTTP")
    objHTTP.Open "GET", strURL, false, strUsername, strPassword
    On Error Resume Next
    objHTTP.Send
    If Err <> 0 Then
        Err.Clear
        CheckURL = 0
    Else
        CheckURL = objHTTP.Status
    End If
    On Error Goto 0
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
    WScript.Echo "  /A [USER:PASS]  - Authentication credentials to use"
    WScript.Echo "  /E [CODE]       - Expected HTTP code (e.g. 200,302,401)"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /T [TAG]        - Descriptive tag to add to the status"
    WScript.Echo "  /U [URL]        - URL to check"
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
