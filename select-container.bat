SET containerId=%1
if "%containerId%"=="" (
  call stats.bat
  SET /P "containerId=Which container to run this command? "
)