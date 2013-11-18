@ECHO OFF
REM # FILENAME: run-checks.bat
REM # DATE:     2013-03-18
REM #
REM # DESCRIPTION:
REM #   This script handles the running of the check-system.bat script
REM #   and sending the output to a text file on the user's desktop.
REM #
REM #
REM ##########################################################################

REM # Localize variables
SETLOCAL

REM # Path to where the main scripts are
REM # NOTE: %~dp0 causes NAGIOSCLIENTDIR to be
REM #       relativ to the path of this script.
SET NAGIOSCLIENTDIR=%~dp0

REM # Path to the send_nsca.cfg file
SET LOGFILE=%HOMEPATH%\Desktop\nagios-checks.log

REM # Path to the check-system.bat script
SET CHECKSYSTEM=%NAGIOSCLIENTDIR%\check-system.bat

REM # Run the checks and log the output
"%CHECKSYSTEM%" > "%LOGFILE%"

