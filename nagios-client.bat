@ECHO OFF
REM # FILENAME: nagios-client.bat
REM # DATE:     2013-03-18
REM #
REM # DESCRIPTION:
REM #   This script handles the running of the check-system.bat script
REM #   and sending the output to the Nagios server using send_nsca.
REM #
REM #
REM ##########################################################################

REM # Localize variables
SETLOCAL

REM # Hostname, FQDN, or IP address of the Nagios server
SET NAGIOSSERVER=nagios.server

REM # Port on the Nagios server where nsca is listening
SET NSCAPORT=5667

REM # Path to where the main scripts are
REM # NOTE: %~dp0 causes NAGIOSCLIENTDIR to be
REM #       relativ to the path of this script.
SET NAGIOSCLIENTDIR=%~dp0

REM # Path to the send_nsca.cfg file
SET SENDNSCACFG=%NAGIOSCLIENTDIR%\send_nsca.cfg

REM # Path to the send_nsca.exe binary
SET SENDNSCA=%NAGIOSCLIENTDIR%\bin\send_nsca.exe

REM # Path to the check-system.bat script
SET CHECKSYSTEM=%NAGIOSCLIENTDIR%\check-system.bat

REM # Output file
SET OUTPUTFILE=%NAGIOSCLIENTDIR%\nagios.out

REM # Run the checks and send the data
CALL "%CHECKSYSTEM%" /N > "%OUTPUTFILE%"
type "%OUTPUTFILE%" | "%SENDNSCA%" -H "%NAGIOSSERVER%" -p %NSCAPORT% -d " " -c "%SENDNSCACFG%"
del "%OUTPUTFILE%"
