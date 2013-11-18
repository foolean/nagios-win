'# FILENAME:    check_dns.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor a DNS server
'#
'#   This script calls nslookup and parses the output.
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_dns.vbs [OPTIONS]
'#
'#   Where:
'#      /A [HOST|IP]    - Expected hostname or address
'#      /H [HOST|IP]    - Hostname or address to query
'#      /N              - Display output in NSCA output
'#      /S [SERVER]     - DNS server to query
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
Dim strLookup       '# Hostname or address to lookup
Dim strAnswer       '# Expected answer
Dim strServer       '# DNS server to check
Dim strResult       '# Resulting string from the lookup
Dim intStatus       '# Nagios status code
Dim strMessage      '# Nagios status message
Dim strCheckName    '# Base name of this check
Dim strTag          '# Descriptive tag to add to the status message

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "dns"

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
            Case "/A"
                ArgIndex = ArgIndex + 1
                strAnswer = Args(ArgIndex)
            Case "/H"
                ArgIndex = ArgIndex + 1
                strLookup = Args(ArgIndex)
            Case "/N"
                intNSCA = 1
            Case "/S"
                ArgIndex = ArgIndex + 1
                strServer = Args(ArgIndex)
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

'# We must have a hostname
If strComp(strLookup, "" ) = 0 Then
    WScript.Echo "Error, No hostname or address provided"
    WScript.Quit 3
End If

'# Perform the lookup
If IsIPAddress( strLookup ) Then
    strResult = GetNameByAddress(strLookup, strServer)
Else
    strResult = GetAddressByName(strLookup, strServer)
End If

'# Process the tag
If Not IsEmpty(strTag) Then
    strTag = strCheckName & "_" & strTag
Else
    strTag = strCheckName
End If

'# Determine the status
intStatus = 0
strMessage = strLookup & " returns '" & strResult & "'"
If strResult = "DNS request timed out" Then
    intStatus = 2
    strMessage = strResult
ElseIf strAnswer <> "" Then
    If strResult <> strAnswer Then
        intStatus = 2
        strMessage = "expected '" & strAnswer & "' but got '" & strResult & "'"
    End If
ElseIf strResult = "" Then
    intStatus = 2
    strMessage = strLookup & " was not found by the server"
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

'# GetNameByAddress - Perform a DNS lookup of an IP address
Function GetNameByAddress(strIPAddress, strDNSServer)
    Set arrResult = CreateObject("System.Collections.ArrayList")
    Set objShell  = CreateObject("Wscript.Shell")
    strCmd = "%comspec% /c nslookup " & strIPAddress & " " & strDNSServer
    Set objExec = objShell.Exec(strCmd)

    '# Iterate over the nslookup output
    Do Until objExec.StdOut.AtEndOfStream
        strLine = objExec.StdOut.ReadLine()
        If (Left(strLine, 5) = "Name:") Then
            GetNameByAddress = Trim(Mid(strLine,6))
            Exit Function
        End If
    Loop
End Function

'# GetAddressByName - Perform a DNS lookup of a hostname
Function GetAddressByName(strHostName, strDNSServer)
    Dim arrResult   '# Container for holding the list of results
    Dim objShell    '# WScript.Shell object for running nslookup
    Dim strCmd      '# nslookup command to be run
    Dim objExec     '# Resulting object from running the command
    Dim strLine     '# Individual lines being read from the command's stdout
    Dim strResult   '# CVS string of all returned addresses
    Dim strSep      '# Separator used in generating the CSV result
    Dim strAddr     '# Address being worked while iterating over result array
    
    Set arrResult = CreateObject("System.Collections.ArrayList")
    Set objShell  = CreateObject("WScript.Shell")
    strCmd = "%comspec% /c nslookup " & strHostName & " " & strDNSServer
    Set objExec = objShell.Exec(strCmd)

    '# Iterate over the nslookup output
    Do Until objExec.StdOut.AtEndOfStream
        strLine = objExec.StdOut.ReadLine()
        If strLine = "DNS request timed out." Then
            GetAddressByName = "DNS request timed out"
            Exit Function
        Else
            '# Skip the server lines
            If (Left(strLine, 7) = "Server:") Then
                strLine = objExec.Stdout.ReadLine()
            Else
                '# We found a single address
                If (Left(strLine, 8) = "Address:") Then
                    arrResult.Add Trim(Mid(strLine, 9))
                End If

                '# We found multiple addresses
                If (Left(strLine, 10) = "Addresses:") Then
                    arrResult.Add Trim(Mid(strLine, 11))
                    Do Until objExec.StdOut.AtEndOfStream
                        strLine = objExec.StdOut.ReadLine()
                        strIP = Trim(Mid(strLine,4))
                        If strIP <> "" Then
                            arrResult.Add strIP
                        End If
                    Loop
                End If
            End If
        End If
    Loop
        
    '# Sort the results
    arrResult.Sort()
        
    '# Convert the sorted list into a comma-separated list
    strResult = ""
    strSep    = ""
    For Each strAddr In arrResult
            strResult = strResult & strSep & strAddr
        If strSep = "" Then
            strSep = ","
        End If
    Next
        
    '# Return the result
    GetAddressByName = strResult
End Function

'# Simple version function
Function Version
    WScript.Echo WScript.ScriptName & " v" & strVersion
End Function

'# Simple help function
Function Usage
    Version
    WScript.Echo "Usage: " & WScript.ScriptName & "[OPTIONS]"
    WScript.Echo ""
    WScript.Echo "Where:"
    WScript.Echo "  /A [HOST|IP]    - Expected hostname or address"
    WScript.Echo "  /H [HOST|IP]    - Hostname or address to query"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /S [SERVER]     - DNS server to query"
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
