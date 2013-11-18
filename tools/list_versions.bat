@ECHO OFF

REM # Localize variables
SETLOCAL

REM # Path to where the plugin scripts are
REM # NOTE: Adding %~dp0\..\ to the front of the path
REM #       will cause PLUGINDIR to be relative to
REM #       the path of this script.
SET PLUGINDIR=%~dp0\..\plugins

REM # Macro to make calling cscript easier
SET CSCRIPT=CSCRIPT //NOLOGO

REM # Run each script with the /V option
%CSCRIPT% "%PLUGINDIR%\check_disk.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_dns.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_eventlog.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_file.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_free.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_http.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_ifutil.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_ipconfig.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_load.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_log.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_microsoftupdate.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_process.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_scheduledtask.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_service.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_tcp.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_uptime.vbs" /V
%CSCRIPT% "%PLUGINDIR%\check_users.vbs" /V