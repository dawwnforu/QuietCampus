@echo off
setlocal
chcp 65001 >nul
pushd "%~dp0"
if not exist "runtime\node.exe" (
  echo Missing runtime. Extract the whole ZIP first.
  echo 请先完整解压，再打开启动文件。
  pause
  exit /b 1
)
"runtime\node.exe" "serve.mjs" "site" 7360 --open
if errorlevel 1 pause
popd
