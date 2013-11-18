'# FILENAME:    list_services.vbs
'# AUTHOR:      Bennett Samowich <bennett@foolean.org>
'# DATE:        2013-03-18
'#
'# DESCRIPTION:
'#   Simple script to list all services on a system.  The output will be
'#   in <name>:<startmode>:<state>:<status> format which will facilitate
'#   programmatic parsing.
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
Dim objWMIService
Dim colItems
Dim objItem

'# Create an object and search for all services
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Set colItems = objWMIService.ExecQuery("Select * from Win32_Service")

'# Iterate over the services and output them in
'# <name>:<startmode>:<state>:<status> format.
For Each objItem In colItems
    WScript.Echo             "" & _
        objItem.Name      & ":" & _
        objItem.StartMode & ":" & _
        objItem.State     & ":" & _
        objItem.Status
 Next
