@ECHO OFF
REM # FILENAME: check-system.bat
REM # DATE:     2013-03-18
REM #
REM # DESCRIPTION:
REM #   This script handles the running of the Nagios check_ scripts.  The
REM #   output of this script can be redirected to a file or sent to a
REM #   Nagios server via the send_nsca command.
REM #
REM # NOTES:
REM #   Configuration options for the various checks can be obtained by
REM #   running the script with the /? option.
REM #
REM #   Example:
REM #       cscript //nologo <path-to>\plugins\check_uptime.vbs /?
REM #
REM ##########################################################################

REM # Localize variables
SETLOCAL

REM # Path to where the plugin scripts are
REM # NOTE: Adding %~dp0\ to the front of the path
REM #       will cause PLUGINDIR to be relative to
REM #       the path of this script.
SET PLUGINDIR=%~dp0\plugins

REM # Macro to make calling cscript easier
SET CSCRIPT=CSCRIPT //NOLOGO

REM # Calling this script with the /N argument will
REM # cause output to be formatted for send_nsca.
IF "%1" == "/N" THEN SET NSCA=/N

REM #############################################################
REM #                    Run our checks                         #
REM #############################################################

REM # Check for new error and warning event logs
REM %CSCRIPT% "%PLUGINDIR%\check_eventlog.vbs" %NSCA% /D 5 /L Application
REM %CSCRIPT% "%PLUGINDIR%\check_eventlog.vbs" %NSCA% /D 5 /L System

REM # Check the uptime of the system
REM #   Critical = less than 1 hour
REM #   Warning  = less than 1 day
REM %CSCRIPT% "%PLUGINDIR%\check_uptime.vbs" %NSCA% /W 86400 /C 3600

REM # Check the numnber of users logged into the system
REM #   Critical = 2 or more users
REM #   Warning  = 1 user
REM %CSCRIPT% "%PLUGINDIR%\check_users.vbs" %NSCA% /W 1 /C 2

REM # Check the memory utilization
REM #   Critical = less than or equal to 15% free
REM #   Warning  = less than or equal to 25% free
REM %CSCRIPT% "%PLUGINDIR%\check_free.vbs" %NSCA% /W 25 /C 15

REM # Check the disk usage
REM #   Critical = less than or equal to 20% free
REM #   Warning  = less than or equal to 30% free
REM %CSCRIPT% "%PLUGINDIR%\check_disk.vbs" %NSCA% /D C /W 30 /C 20

REM # Check that our interface is configured the way we want it
REM # Recommended options:
REM #     /A [ADDRESS]    - Expected IP address
REM #     /M [NETMASK]    - Expected Netmask
REM #     /G [GATEWAY]    - Expected Gateway
REM #     /S [DNS[,DNS]]  - Expected DNS servers
REM %CSCRIPT% "%PLUGINDIR%\check_ipconfig.vbs" %NSCA% /T LAN /I "Local Area Connection" /A "192.168.1.2" /M "255.255.255.0" /G "192.168.1.1" /S "192.168.1.10,192.168.2.10"

REM # Check that DNS resolves things that we care about
REM %CSCRIPT% "%PLUGINDIR%\check_dns.vbs" %NSCA% /H "localhost" /A "127.0.0.1" /T localhost

REM # Check that we can reach any required tcp ports
REM %CSCRIPT% "%PLUGINDIR%\check_tcp.vbs" %NSCA% /H "172.16.32.51" /P 3389 /T pos01_rdp

REM # Check that processes we care about are running (or not running)
REM %CSCRIPT% "%PLUGINDIR%\check_process.vbs" %NSCA% /P services.exe

REM # Check that services we care about are running (or not running)
REM # NOTE: You need to use the short service name
REM %CSCRIPT% "%PLUGINDIR%\check_service.vbs" %NSCA% /S TermService

REM # Check the CPU utilization
REM #   Critical = greater than or equal to 90% utilization
REM #   Warning  = greater then or equal to 75% utilization
REM %CSCRIPT% "%PLUGINDIR%\check_load.vbs" %NSCA% /W 75 /C 90

REM # Check the bandwidth utilization
REM #   Critical = greater than or equal to 75% RX and TX utilization
REM #   Warning  = greater than or equal to 55% RX and TX utilization
REM %CSCRIPT% "%PLUGINDIR%\check_ifutil.vbs" %NSCA% /I "Local Area Connection" /W "55:55" /C "75:75"

REM # Check that we can reach and load required web pages
REM %CSCRIPT% "%PLUGINDIR%\check_http.vbs" %NSCA% /U "http://www.google.com" /E 200

REM # Check that our scheduled tasks are running properly
REM %CSCRIPT% "%PLUGINDIR%\check_scheduledtask.vbs" %NSCA% /P "\Path\To\Scheduled Task"

REM # Check if there are updates
REM %CSCRIPT% "%PLUGINDIR%\check_microsoftupdate.vbs" %NSCA%
