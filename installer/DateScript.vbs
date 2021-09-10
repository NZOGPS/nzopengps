' ---------------------------------------------------------------------------------------------------------------------------------------------------------
' AUTHOR:	Brett Hodgson
' DATE:		16 May 2010
' MODIFIED:	Gary Turner
' DATE:		16 Jan 2015
' PURPOSE:	Get author from Environment
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

Set WshShell = WScript.CreateObject("WScript.Shell")

Dim newDate
newDate=CStr(Now())
Dim thisYear
thisYear=Year(newDate)
Dim yearVerArr()
Dim lastVersion
Dim newVersion
Dim verStr

Function getVer(findYear)
' Get years and max versions from file
	newVer = 0
	Dim i : i = 0
	set yvre = New RegExp
	yvre.Pattern = "(\d{4}):(\d{2}):(.*)"
	Set objDVFile = objFS.OpenTextFile("YearVersion.txt")
	Do Until objDVFile.AtEndOfStream
		strLine = objDVFile.ReadLine
		If yvre.Test(strLine) Then
			Set rematch = yvre.Execute(strLine)
			ReDim Preserve yearVerArr(2,i)
			yearVerArr(0,i) = rematch(0).SubMatches(0)
			yearVerArr(1,i) = rematch(0).SubMatches(1)
			yearVerArr(2,i) = rematch(0).SubMatches(2)
			if StrComp(CStr(thisYear), yearVerArr(0,i)) = 0  Then 
			call WshShell.Popup(thisyear,5,"This Year found",0)
			'need to check if it's the same day?
				newVer = CInt(yearVerArr(1,i))
			End If
			i = i + 1
		End If
	Loop
	objDVFile.Close
	if newVer = 0 Then 
		getVer = 0 
	Else
		getVer = newVer
	End If
End Function

Function updateYVA (year,version,date)
' update Year Version Array with current data
	Dim Found : Found = False
	Dim UB : UB = UBound(yearVerArr,2)
	
	For i = 0 to UB
		if StrComp(CStr(year), yearVerArr(0,i)) = 0 Then ' same year as now found
			Found = True
			yearVerArr(1,i) = Right("0" & version,2)
			yearVerArr(2,i) = date
		End If
	Next
	if not Found Then 'this is a new year
		UB = UB + 1
		ReDim Preserve yearVerArr(2,UB)
		yearVerArr(0,UB) = year
		yearVerArr(1,UB) = Right("0" & version,2)
		yearVerArr(2,UB) = date
	End If
End Function

Function writeYearVer()
' update file with new data
	Dim i
	Set objDVFile = objFS.OpenTextFile("YearVersion.txt",2)
	For i = 0 to UBound(yearVerArr,2)
		objDVFile.Write(yearVerArr(0,i)&":")
		objDVFile.Write(yearVerArr(1,i)&":")
		objDVFile.WriteLine(yearVerArr(2,i))
	Next
End Function
	
Set objFS = CreateObject("Scripting.FileSystemObject")

lastVersion = getVer(thisYear)
newVersion = lastVersion + 1
call updateYVA(thisYear,newVersion,newDate)
writeYearVer()
verStr = thisYear mod 100 & Right("0" & newVersion,2)

strFile = "NZO5_pv_template.txt"
Set objFile = objFS.OpenTextFile(strFile)

Set wshShell = CreateObject( "WScript.Shell" )
creator = wshShell.ExpandEnvironmentStrings( "%nzogps_inst_creator%" )
if creator = "%nzogps_inst_creator%" then creator = "Unknown"
subdir = wshShell.ExpandEnvironmentStrings( "%nzogps_inst_loc%" )
if subdir = "%nzogps_inst_loc%" then subdir = ""

Dim sCurPath
sCurPath = objFS.GetAbsolutePathName(".")
sCurPath = objFS.BuildPath(sCurPath,subdir)
sCurPath = objFS.GetAbsolutePathName(sCurPath)

'find #DATE# line in pv template file and replace with actual date and time 
Do Until objFile.AtEndOfStream
	strLine = objFile.ReadLine
	If InStr(strLine,"Copy1")> 0 Then
		strLine = Replace(strLine,"#{DATE}",newDate)
		strLine = Replace(strLine,"#{CREATOR}",creator)
	End If

	If InStr(strLine,"#{VERSION}")> 0 Then
		strLine = Replace(strLine,"#{VERSION}",verStr)
	End If

	If InStr(strLine,"#{PATH}")> 0 Then
		strLine = Replace(strLine,"#{PATH}",sCurPath)
	End If
	
	' write eachline of existing NZO5_pv_template.txt file and updated Copy1 string to newfile.txt
	WScript.Echo strLine
Loop
'create delay so newfile writing completes before next step in batch file
WScript.Sleep(1000)
