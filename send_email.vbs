'# FILENAME:    send_email.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#      This script reads Nagios NSCA formatted data and sends email
'#      notifications for checks that are at warning and critical levels.
'#
'# USAGE:
'#      CSCRIPT //NOLOGO send_email.vbs [OPTIONS]
'#
'#      Where:
'#          /F [FROM]       - Address the message should be from
'#          /P [PORT]       - SMTP port on the server to connect to
'#          /R [RECIPIENT]  - Address to send the message to
'#          /S [SERVER]     - SMTP server to connect to
'#          /V              - Display version information
'#          /?              - Display help
'#
'#############################################################################

'# Declare our variables
Option Explicit
Dim strVersion          '# Version of this script
Dim objNTInfo		    '# Object for getting the hostname of this system
Dim strHostName		    '# Hostname of this server
Dim Args			    '# Command-line arguments
Dim strServer           '# SMTP server to send mail through
Dim intport             '# Port on the SMTP server to connect to
Dim strFrom             '# Who the message is from
Dim strTo               '# Who to send the message to
Dim strSubject          '# Subject line of the message
Dim strBody             '# Body of the message
Dim strLine             '# Variable for reading stdin
Dim arrData             '# Array for parsing incoming data

'# Our version number
strVersion = "1.0.0"

'# Get the hostname
Set objNTInfo = CreateObject("WinNTSystemInfo")
strHostName = lcase(objNTInfo.ComputerName)

'# Defaults
intport = 25
strFrom = "Administrator@" & strHostname

'# Parse the command-line arguments
Dim ArgIndex
Set Args = wscript.Arguments
If Args.Count > 0 Then
    For ArgIndex = 0 To Args.Count - 1
        Select Case (Args(ArgIndex))
            Case "/F"
                ArgIndex = ArgIndex + 1
                strFrom = Args(ArgIndex)
            Case "/P"
                ArgIndex = ArgIndex + 1
                intPort = Int(Args(ArgIndex))
            Case "/R"
                ArgIndex = ArgIndex + 1
                strTo = Args(ArgIndex)
            Case "/S"
                ArgIndex = ArgIndex + 1
                strServer = Args(ArgIndex)
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

'# We must have a SMTP server
If strComp(strSMTP_Server, "" ) = 0 Then
    WScript.Echo "Error, No SMTP server provided"
    WScript.Quit 1
End If

'# We must have a recipient
If strComp(strTo, "" ) = 0 Then
    WScript.Echo "Error, No recipient provided"
    WScript.Quit 1
End If

'# Iterate over stdin
Do Until WScript.StdIn.AtEndOfStream
    strLine = WScript.StdIn.ReadLine()
    
    '# Split the Nagios/NSCA data into its component parts
    arrData = Split(strLine, " ", 3)
    
    '# Nagios output typically has a ':' following the status
    arrData(1) = Replace(arrData(1), ":", "")
    
    '# We're only going to send notifications that are not ok
    If arrData(1) <> "OK" Then
        '# Assemble the subject and message body
        strSubject = "** PROBLEM alert - " & arrData(0) & " is " & arrData(1) & " **"
        strBody    = arrData(2)
        
        '# Send the notification
        SendMessage strServer, strPort, strFrom, strTo, strSubject, strBody
    End If
Loop

WScript.Quit 0

'# SendMessage - send an email message through a SMTP server
Function SendMessage(   _
    strSMTP_Server,     _
    strSMTP_port,       _
    strSMTP_From,       _
    strSMTP_To,         _
    strSMTP_Subject,    _
    strSMTP_Body        _
)
    Dim strSchema       '# Schema for sending mail without SMTP service
    Dim objEmail        '# Email object
    Dim objEmailFields  '# Email fields object (helps with line length)
    
    '# Schema to send mail without having to install
    '# the STMP service on the server.
    strSchema = "http://schemas.microsoft.com/cdo/configuration/"
    
    '# Create our email object
    Set objEmail = CreateObject("CDO.Message")
    
    '# Set the message contents
    objEmail.From     = strSMTP_From
    objEmail.To       = strSMTP_To
    objEmail.Subject  = strSMTP_Subject
    objEmail.Textbody = strSMTP_Body

    '# Configure the remote SMTP server to use
    Set objEmailFields = objEmail.Configuration.Fields
    objEmailFields.Item(strSchema&"sendusing")      = 2
    objEmailFields.Item(strSchema&"smtpserver")     = strSMTP_Server
    objEmailFields.Item(strSchema&"smtpserverport") = intSMTP_Port
    objEmailFields.Update

    '# Send the message
    objEmail.Send
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
    WScript.Echo "  /F [FROM]       - Address the message should be from"
    WScript.Echo "  /P [PORT]       - SMTP port on the server to connect to"
    WScript.Echo "  /R [RECIPIENT]  - Address to send the message to"
    WScript.Echo "  /S [SERVER]     - SMTP server to connect to"
    WScript.Echo "  /?              - Display help"

    WScript.Quit 1
End Function
