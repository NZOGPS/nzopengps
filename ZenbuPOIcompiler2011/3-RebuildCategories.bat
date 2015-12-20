if not defined nzogps_ruby_cmd call ..\setlocals.bat
%nzogps_ruby_cmd% rebuild_category_files.rb
pause
%nzogps_git% commit -m "Zenbu Category Update" -uno ..\ZenbuPOIcategories2011\*.txt
pause
%nzogps_git% push
pause
