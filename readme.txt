This is a collection of VBScript scripts and supporting executables to enable
a Windows system to perform monitoring checks and send the results to a remote
Nagios server.

[ Copyright ]

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Puplic License as published by
   the Free Software Foundation, either version 3 of the License, or
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.


[ Installation ]

1) Copy the entire contents to a directory on the system

   Example:
   C:\Program Files\Nagios Client\
   ... or ...
   C:\Program Files (x86)\Nagios Client\

2) Ensure that only the necessary accounts have write access to this
   directory.

   This is important to ensure that the scripts, which will run with
   elevated privleges, can not be used as an attack vector on the system.

3) Customize the check-system.bat script to include only the checks that
   you care about.  There will be some that are common to all systems and
   others that are unique to each system.   The choice is yours.

4) Customize the NAGIOSSERVER and NSCAPORT variables in nagios-client.bat
   so that it will be correctly oriented toward your Nagios server

5) Customize the send_nsca.cfg configuration file to match your Nagios
   environment.

6) Run the nagios-client.bat script manually and review the output to ensure
   you are getting the output you desire it is ready to be sent to the
   Nagios server

7) Set up a Scheduled Task to run the nagios-client.bat script every
   5 minutes or whatever your polling schedule is.



[ Structure ]

This Nagios Client collection is arranged in a specific layout that must not
change.  If you need to change the layout then you will also need to modify
the main scripts to be aware of the new layout.

The Layout
+--+ <NagiosClient>\            - Root of whereever you put the collection
   |
   +--+ plugins\                - Directory where the plugin scripts are kept
   |
   +--+ bin\                    - Directory where binary executables are kept
   |
   +--+ check-system.bat        - Script to run the individual checks
   |
   +--+ nagios-client.bat       - Main Nagios client script
   |
   +--+ send_nsca.cfg           - Configuration file for send_nsca.exe

You shouldn't need to touch anything in 'bin' or 'plugins' unless you're
adding new checks or fixing bugs in the existing ones.


[ User Account Control ]

User Account Control (UAC) is a Windows technology that limits an application
to standard user privileges until an Administrator authorizes elevation.  This
mechanism improves the overal security posture of the system.  The check_
plugins are not currently UAC aware and may not function properly when run in
normal user context.  They should run fine when run as a scheduled task  using
the SYSTEM account.

For more information about UAC, 
see: http://en.wikipedia.org/wiki/User_Account_Control


You can check the state of UAC by using the uac_status.vbs script found in the
tools directory.  Alternately, you can use the reg.exe command to query the
registry directly.

cscript //nologo <nagios-client>/tools/uac_status.vbs

reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA

    Disabled:   EnableLUA    REG_DWORD    0x0
    Enabled:    EnableLUA    REG_DWORD    0x1


[ Plugins ]

The following is the list of plugins that are currently in the package

check_disk.vbs              - Check disk utilization
check_dns.vbs               - Check DNS server
check_eventlog.vbs          - Check for new error and warning event logs
check_file.vbs              - Check file existence, size, last write
check_free.vbs              - Check percentage of free memory
check_http.vbs              - Check remote URLs (http, https, ftp, etc)
check_ifutil.vbs            - Check bandwidth utilization
check_ipconfig.vbs          - Check network interface configuration
check_load.vbs              - Check the CPU load
check_microsoftupdate.vbs   - Check if updates are available
check_process.vbs           - Check if a process is running (or not running)
check_scheduledtask.vbs     - Check a scheduled task 
check_service.vbs           - Check if a service is running (or not running)
check_tcp.vbs               - Check if a remote TCP port is listening
check_uptime.vbs            - Check the uptime of the system
check_users.vbs             - Check the number of logged in users


[ Tools ]

The following tools are provided in an attempt to make life a little easier.

list_services.vbs               - List all services on the system
ScheduledTask_CheckSystem.xml   - XML export of the 'Check System' task
uac_status.vbs                  - Display if User Account Control (UAC) is enabled
