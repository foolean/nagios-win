'# FILENAME:    uac_status.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Simple script to display if User Account Control (UAC)
'#   is enabled or disabled.
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
Dim WshShell        '# WScript shell object
Dim intEnabled      '# Value if disabled or enabled
Dim strRegistryKey  '# Registry key to check

strRegistryKey = "HKLM\SOFTWARE\Microsoft\Windows\" & _
                 "CurrentVersion\Policies\System\"  & _
                 "EnableLUA"
                 
'# Create our shell object
Set WshShell = WScript.CreateObject("WScript.Shell")

'# Get the value of EnableLUA
intEnabled = WshShell.RegRead( strRegistryKey )
If intEnabled Then
    WScript.Echo "User Account Control (UAC) is enabled"
Else
    WScript.Echo "User Account Control (UAC) is disabled"
End If
