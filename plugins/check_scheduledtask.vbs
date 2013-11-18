'# FILENAME:    check_scheduledtasks.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Nagios check to monitor a scheduled task
'#
'#   Due to the way VBScript process the Schedule.Service objects,
'#   you MUST provide the full path to the task.  You can learn the
'#   full path by running the command-line tool 'schtasks'.  The
'#   output will display the Folder and list of task names in that
'#   folder.  The full path is the combination of folder\name.
'#
'#   Example:
'#   Folder: \Microsoft\Windows\Defrag
'#   TaskName                                 Next Run Time          Status
'#   ======================================== ====================== =========
'#   ScheduledDefrag                          N/A                    Ready
'#
'#   Full Path = "\Microsoft\Windows\Defrag\ScheduledDefrag"
'#
'# USAGE:
'#   CSCRIPT //NOLOGO check_scheduledtasks.vbs [OPTIONS]
'#
'#   Where:
'#      /C [SECONDS]    - Critcal seconds since last run
'#      /E              - Toggle expected Enabled state (default:True)
'#      /N              - Display output in NSCA output
'#      /P [PATH]       - Full path of the task to check
'#      /T [TAG]        - Descriptive tag to add to the status
'#      /V              - Display version information
'#      /W [SECONDS]    - Warning seconds since last run
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
Dim strTaskPath     '# Full path of the task to check
Dim objFoundTask    '# Task object for the found task
Dim intStatus       '# Nagios status code
Dim strMessage      '# Nagios status message
Dim strTag          '# Descriptive tag to add to the status message
Dim intEnabledState '# Expected interface state
Dim intWarnSeconds  '# Warning seconds since last run
Dim intCritSeconds  '# Critical seconds since last run
Dim intLastRun      '# Seconds since last run

'# Our version number
strVersion = "1.0.0"

'# Base name of this check
strCheckName = "task"

'# NSCA or Nagios format
intNSCA = 0

'# Defaults
intEnabledState  = True    '# The task should be enabled
intWarnSeconds   = -1
intCritSeconds   = -1

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
                intCritSeconds = Int(Args(ArgIndex))
            Case "/E"
                intEnabledState = False
            Case "/N"
                intNSCA = 1
            Case "/P"
                ArgIndex = ArgIndex + 1
                strTaskPath = Args(ArgIndex)
            Case "/T"
                ArgIndex = ArgIndex + 1
                strTag = Args(ArgIndex)
            Case "/V"
                Version
                WScript.Quit 1
            Case "/W"
                ArgIndex = ArgIndex + 1
                intWarnSeconds = Int(Args(ArgIndex))
            Case "/?"
                Usage
            Case else
                WScript.Echo "unknown argument '" & Args(ArgIndex) & "'"
                Usage
        End Select
    Next
End If

'# We must have a task path
If strComp(strTaskPath, "" ) = 0 Then
    WScript.Echo "Error, No task path provided"
    WScript.Quit 3
End If

'# Get the task information
Set objFoundTask = GetTask( strTaskPath )
intLastRun = DateDiff("s", objFoundTask.LastRunTime, Now)

'# Determine the status
intStatus = 0
If Not objFoundTask Is Nothing Then
    If objFoundTask.Enabled <> intEnabledState Then
        intStatus = 2
        If objFoundTask.Enabled Then
            strMessage = "The task is enabled, should be disabled"
        Else
            strMessage = "The task is disabled, should be enabled"
        End If
    ElseIf objFoundTask.LastRunTime = "12:00:00 AM" Then
        intStatus = 1
        strMessage = "The task has not been run"
    ElseIf intCritSeconds >= 0 And intLastRun >= intCritSeconds Then
        intStatus = 2
        strMessage = "The task was last run at " & objFoundTask.LastRunTime & " (" & intLastRun & " seconds ago)"
    ElseIf intWarnSeconds >= 0 And intLastRun >=intWarnSeconds Then
        intStatus = 1
        strMessage = "The task was last run at " & objFoundTask.LastRunTime & " (" & intLastRun & " seconds ago)"
    ElseIf objFoundTask.LastTaskResult = 0 Then
        strMessage = "The task completed successfully at: " & objFoundTask.LastRunTime
    ElseIf objFoundTask.LastTaskResult = 267009 Then
        strMessage = "The task is currently running"
    ElseIf objFoundTask.LastTaskResult = 267010 And intEnableState = 1 Then
        intStatus = 2
        strMessage = "The task is not scheduled"
    Else
        intStatus = 2
        strMessage = "The task returned (" & objFoundTask.LastTaskResult & ")"
    End If
Else
    intStatus = 2
    strMessage = "The requested task does not exist"
End If

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

'# GetTaskName - return base name of the task
Function GetTaskName( strTaskPath )
    Dim x, y
    Dim tmpstring

  tmpstring = strTaskPath
  x = Len(strTaskPath)
  for y = x to 1 step -1
    if mid(strTaskPath, y, 1) = "\" or _
      mid(strTaskPath, y, 1) = ":" or _
      mid(strTaskPath, y, 1) = "/" then
      tmpstring = mid(strTaskPath, y+1)
      exit for
    end if
  next
  GetTaskName = tmpstring
End Function

'# GetTask - return a Task object or 'Nothing'
Function GetTask( strTaskPath )
    Dim objService      '# Schedule service object
    Dim objTask         '# Task object
    
    Set objService = CreateObject("Schedule.Service")
    Call objService.Connect()
    On Error Resume Next
    Set objTask = objService.GetFolder("\").GetTask(strTaskPath)
    If Err <> 0 Then
        Err.Clear
        Set GetTask = Nothing
        Exit Function
    End If
    On Error Goto 0
    Set GetTask = objTask
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
    WScript.Echo "  /C [SECONDS]   - Critical seconds since last run"
    WScript.Echo "  /E              - Toggle expected Enabled state (default:True)"
    WScript.Echo "  /N              - Display output in NSCA output"
    WScript.Echo "  /P [PATH]       - Full path of the task"
    WScript.Echo "  /T [TAG]        - Descriptive tag to add to the status"
    WScript.Echo "  /W [SECONDS     - Warning seconds since last run"
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
