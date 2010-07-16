' ---------------------------------------------------------------------------------------------------------------------------------------------------------
' AUTHOR: 		Brett Hodgson
' DATE:		16 May 2010
'
'PURPOSE: 
'This script creates a cgpsmapper .pv file with the current date for Mapsource Version Identification.  
' This date can be viewed by users with Mapsource via the Utilities->Manage Map Products-> Copyright command.
'
'REQUIRED FILES:
'	- NZO5_pv_template.txt
'	- DateScript.vbs

'get date and convert to string
'
Dim newDate
newDate=CStr(Now())

Set objFS = CreateObject("Scripting.FileSystemObject")
strFile = "NZO5_pv_template.txt"
Set objFile = objFS.OpenTextFile(strFile)

Dim sCurPath
sCurPath = objFS.GetAbsolutePathName(".")
'find #DATE# line in pv template file and replace with actual date and time 
Do Until objFile.AtEndOfStream
    strLine = objFile.ReadLine
    If InStr(strLine,"Copy1")> 0 Then
        strLine = Replace(strLine,"#{DATE}",newDate)
	End If
	If InStr(strLine,"#{PATH}")> 0 Then
        strLine = Replace(strLine,"#{PATH}",sCurPath)
	End If
	
	' write eachline of existing NZO5_pv_template.txt file and updated Copy1 string to newfile.txt
	WScript.Echo strLine
Loop
'create delay so newfile writing completes before next step in batch file
WScript.Sleep(1000)
