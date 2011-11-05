echo OFF
for %%X in (ruby.exe) do (set FOUND=%%~$PATH:X)
if defined FOUND (
  echo Using Ruby %FOUND
  ruby shape-parser.rb
  pause
) else (
  echo Ruby is not in your path. Is it installed? See README.txt
  pause
)
