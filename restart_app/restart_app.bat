@echo on
set app=cardmon.exe
set app=werfault.exe
:restart
tasklist| find /I "%app%" > nul
rem if app is loaded in RAM (not true), then kill it. Else start app
if %errorlevel% equ 1 
(
H:\CM\RUN.CMD
)
else 
(
taskkill /F /IM %app%
ping 127.0.0.1 /n 4 /w 1000>nul
taskkill /F /IM %error%
goto restart
)
