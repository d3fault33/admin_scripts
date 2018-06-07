@echo on
rem xcopy understands UNC-paths in contrast to copy
@set src=\\s527-fs02\work\VERSII\_softclu\SCBKI\2017\rask\*

@set dest=\\s527-card\Work\cirrus\*

rem adding windows system dir to path variable due to starting this script on Winserver 
rem with UAC enabled under admin account 
set path=C:\Windows\System32\;%oldpath%

xcopy %src% %dest% /E /Y /H /R /C >> D:\copylog.txt
