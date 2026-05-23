; Helium WinUpdater - https://github.com/nwn900/helium-winupdater
; Based on LibreWolf WinUpdater by ltguillaume - https://codeberg.org/librewolf/winupdater
;@Ahk2Exe-SetFileVersion 1.0.0
;@Ahk2Exe-SetProductVersion 1.0.0

;@Ahk2Exe-Base Unicode 32*
;@Ahk2Exe-SetCompanyName Helium Community
;@Ahk2Exe-SetCopyright ltguillaume / ported for Helium
;@Ahk2Exe-SetDescription Helium WinUpdater
;@Ahk2Exe-SetMainIcon Helium-WinUpdater.ico
;@Ahk2Exe-SetOrigFilename Helium-WinUpdater.exe
;@Ahk2Exe-SetProductName Helium WinUpdater
;@Ahk2Exe-UpdateManifest 0, WinUpdater

#NoEnv
#SingleInstance, Off

Global Args       := ""
, Browser         := "Helium"
, BrowserExe      := "helium.exe"
, BrowserPortable := "Helium\" BrowserExe
, ConnectCheckUrl := "https://api.github.com"
, ReleaseApiUrl   := "https://api.github.com/repos/imputnet/helium-windows/releases/latest"
, UpdaterApiUrl   := "https://api.github.com/repos/nwn900/helium-winupdater/releases/latest"
, SetupParams     := "/D={}"
, TaskCreateFile  := "ScheduledTask-Create.ps1"
, TaskRemoveFile  := "ScheduledTask-Remove.ps1"
, UpdaterFile     := Browser "-WinUpdater.exe"
, PortableExe     := Browser "\" BrowserExe
, IsPortable      := FileExist(A_ScriptDir "\" PortableExe)
, RunningPortable := A_Args[1] = "/Portable"
, Scheduled       := A_Args[1] = "/Scheduled"
, SettingTask     := A_Args[1] = "/CreateTask" Or A_Args[1] = "/RemoveTask"
, ChangesMade     := False
, Done            := False
, IniFile, Path, Folder, ProgramW6432, WorkDir, ExtractDir, Build, IgnoreCrlErrors, NoSigChecks, UpdateSelf, Task, CurrentDomain, CurrentUpdaterVersion
, ReleaseInfo, CurrentVersion, NewVersion, SetupFile, GuiHwnd, LogField, ProgField, VerField, TaskSetField, UpdateButton, ShutdownBlocked, Died

; Strings
Global _Updater       := Browser " WinUpdater"
, _Show               := "Show"
, _PortableHelp       := "Portable Help"
, _UpdaterHelp        := "WinUpdater Help"
, _Settings           := "Settings"
, _Exit               := "Exit"
, _NoConnectionError  := "Could not connect to " SubStr(ConnectCheckUrl, 1, InStr(ConnectCheckUrl, "/",,, 3) - 1) "."
, _IsRunningError     := _Updater " is already running."
, _IsElevated         := "To set up scheduled tasks properly, please do not run WinUpdater as administrator."
, _NoDefaultBrowser   := "Could not open your default browser."
, _SelfUpdating       := "Downloading new WinUpdater version..."
, _Checking           := "Checking for new version..."
, _SetTask            := "Schedule a task for automatic update checks while`nuser {} is logged on."
, _SettingTask        := (A_Args[1] = "/CreateTask" ? "Creating" : "Removing") " scheduled task..."
, _Done               := " Done."
, _GetPathError       := "Could not find the path to " Browser ".`nBrowse to " BrowserExe " in the following dialog."
, _SelectFileTitle    := _Updater " - Select " BrowserExe "..."
, _WritePermError     := "Could not write to {}. Please check the current user account's write permissions for this folder."
, _CopyError          := "Could not copy {}"
, _32BitHelium        := "Helium does not provide a 32-bit build."
, _32BitOS            := "Consider using a 64-bit Windows installation if possible."
, _SwitchTo64         := "Click Yes to switch to the 64-bit build or No to quit."
, _GetBuildError      := "Could not determine the build type of " Browser "."
, _GetVersionError    := "Could not determine the current version of`n{}"
, _CrlError           := "The server certificate revocation check for {} has failed. Right-click on WinUpdater's tray icon, then ""WinUpdater Help"" for more info.`nContinue anyway?"
, _DownloadJsonError  := "Could not download the {Task} releases file."
, _JsonVersionError   := "Could not get version info from the {Task} releases file."
, _FindUrlError       := "Could not find the URL to download {Task}."
, _Downloading        := "Downloading new version..."
, _DownloadSelfError  := "Could not download the new WinUpdater version."
, _DownloadSetupError := "Could not download the setup file."
, _Downloaded         := "New version downloaded."
, _CheckingHash       := "Checking file integrity..."
, _FindChecksumError  := "Could not find the checksum for the downloaded file."
, _ChecksumMatchError := "The file checksum for {} did not match, so it's possible the download failed."
, _ChangesMade        := "However, new files were written to the target folder!"
, _NoChangesMade      := "No changes were made to your " Browser " folder."
, _Extracting         := "Extracting portable version..."
, _StartUpdate        := "  &Start update  "
, _Installing         := "Installing new version..."
, _UpdateError        := "Error while updating{}."
, _SilentUpdateError  := "Silent update did not complete.`nDo you want to run the interactive installer?"
, _NewVersionFound    := "New version available.`nClose " Browser " to continue..."
, _NoNewVersion       := "No new version found."
, _ExtractionError    := "Could not extract the {Task} archive.`nMake sure " Browser " is not running and restart the updater."
, _MoveToTargetError  := "Could not move the following file into the target folder:`n{}"
, _IsUpdating         := "Update in progress..."
, _IsUpdated          := Browser " has been updated."
, _To                 := "to"
, _GoToWebsite        := "<a>Restart WinUpdater</a> or visit the <a>project website</a> for help."

Init()
CheckArgs()
CheckPaths()
GetCurrentVersion()
If (ThisUpdaterRunning())
	Die(_IsRunningError,, !Scheduled)
Unelevate()
CheckWriteAccess()
If (SettingTask Or !A_Args.Length())
	GuiShow()
If (SettingTask)
	TaskSet()
CheckConnection()
If (UpdateSelf And A_IsCompiled)
	SelfUpdate()
SwitchTo64()
If (GetNewVersion())
	GetUpdate()
Exit()

Init() {
	FileGetVersion, CurrentUpdaterVersion, %A_ScriptFullPath%
	CurrentUpdaterVersion := RegExReplace(CurrentUpdaterVersion, "(\.0)+$")
	EnvGet, ProgramW6432, ProgramW6432
	If (ProgramW6432 = "")
		ProgramW6432 := "?"
	SplitPath, A_ScriptFullPath,,,, BaseName
	IniFile := A_ScriptDir "\" BaseName ".ini"
	IniRead, IgnoreCrlErrors, %IniFile%, Settings, IgnoreCrlErrors, 0
	IniRead, NoSigChecks, %IniFile%, Settings, NoSigChecks, 1
	IniRead, UpdateSelf, %IniFile%, Settings, UpdateSelf, 1
	IniRead, WorkDir, %IniFile%, Settings, WorkDir, %A_Temp%
	IniWrite, %IgnoreCrlErrors%, %IniFile%, Settings, IgnoreCrlErrors
	IniWrite, %NoSigChecks%, %IniFile%, Settings, NoSigChecks
	IniWrite, %UpdateSelf%, %IniFile%, Settings, UpdateSelf
	Menu, Tray, Tip, %_Updater% %CurrentUpdaterVersion%
	Menu, Tray, NoStandard
	Menu, Tray, Add, %_Show%, Action
	Menu, Tray, Add, %_PortableHelp%, Action
	Menu, Tray, Add, %_UpdaterHelp%, Action
	Menu, Tray, Add, %_Settings%, Action
	Menu, Tray, Add, %_Exit%, Action
	Menu, Tray, Default, %_Show%

	; Set up GUI
	Gui, +HwndGuiHwnd -MaximizeBox
	Gui, Color, 152671
	Gui, Add, Picture, x12 y10 w64 h64 Icon2, %A_ScriptFullPath%
	Gui, Font, cC0D9FF s22 w700, Segoe UI
	Gui, Add, Text, x85 y4 BackgroundTrans, %Browser%
	Gui, Font, cFFFFFF s9 w700
	Gui, Add, Text, vVerField x86 y42 w222 BackgroundTrans
	Gui, Font, w400
	Gui, Add, Progress, vProgField w217 h20 cC0D9FF, 10
	Gui, Add, Text, vLogField w222
	Gui, Margin,, 15
	Gui, Show, Hide, %_Updater% %CurrentUpdaterVersion%

	If (SettingTask Or !A_Args.Length()) {
		If (!IsPortable And FileExist(A_ScriptDir "\" TaskCreateFile) And FileExist(A_ScriptDir "\" TaskRemoveFile)) {
			Gui, Add, CheckBox, vTaskSetField gTaskSet x15 y+10 w290 cBCBCBC Center Check3 -Tabstop, % StrReplace(_SetTask, "{}", A_UserName)
			TaskCheck()
		}
	}

	HotKey, IfWinActive, ahk_id %GuiHwnd%
	HotKey, F1, Help
}

Help() {
	Action("WinUpdater", False, False)
}

Action(ItemName, GuiEvent, LinkIndex) {
	Switch ItemName
	{
		Case _Show:
			If (!WinExist("ahk_id " GuiHwnd))
				GuiShow()
			WinWait, ahk_id %GuiHwnd%
			WinActivate
			Return
		Case _Settings:
			Run, %IniFile%
			Return
		Case _Exit:
			If (Died Or Done)
				GuiClose()
			Else
				GuiShow()
			Return
		Default:
			If (LinkIndex = 1)
				Return Restart()
			If (LinkIndex = 2)
				ItemName := "WinUpdater"

			Url := "https://github.com/imputnet/helium-windows"
			If (ItemName = "Portable Help")
				Url := "https://github.com/imputnet/helium#downloads"
			Try Run, %Url%
			Catch {
				RegRead, DefBrowser, HKCR, .html
				RegRead, DefBrowser, HKCR, %DefBrowser%\Shell\Open\Command
				Run, % StrReplace(DefBrowser, "%1", Url)
				If (ErrorLevel)
					MsgBox, 48, %_Updater%, %_NoDefaultBrowser%
			}
	}
}

CheckArgs() {
	Args := ""
	For i, Arg in A_Args
	{
		If (InStr(Arg, A_Space))
			Arg := """" Arg """"
		Args .= " " Arg
	}
}

CheckPaths() {
	If (IsPortable)
		Path := A_ScriptDir "\" BrowserPortable
	Else {
		IniRead, Path, %IniFile%, Settings, Path, 0
		If (!Path) {
			EnvGet, LocalAppData, Local AppData
			Path := LocalAppData "\imput\" Browser "\Application\" BrowserExe
			If (!FileExist(Path)) {
				RegRead, Path, HKLM\SOFTWARE\Clients\StartMenuInternet\%Browser%\shell\open\command
				If (ErrorLevel Or !InStr(Path, BrowserExe))
					Path := ProgramW6432 "\" Browser "\" BrowserExe
			}
		}
		Path := Trim(Path, """")
	}

	If (FileExist(Path ".wubak")) {
		FileMove, %Path%.wubak, %Path%, 1
		If (ErrorLevel And !A_IsAdmin And !Portable)
			RunElevated()
	}

	Folder := StrReplace(Path, "\" BrowserExe)
	Menu, Tray, Tip, %_Updater% %CurrentUpdaterVersion%`n%Folder%

	If (SubStr(WorkDir, 1, 1) = ".")
		WorkDir := A_ScriptDir . SubStr(WorkDir, 2)
	If (WorkDir <> "" And !FileExist(WorkDir))
		FileCreateDir, %WorkDir%
	If (WorkDir = "" Or !InStr(FileExist(WorkDir), "D"))
		WorkDir := A_Temp
	ExtractDir := WorkDir "\" Browser "-Extracted"
	SetWorkingDir, %WorkDir%

	CheckPath:
	If (!FileExist(Path)) {
		MsgBox, 48, %_Updater%, %_GetPathError%
		EnvGet, LocalAppData, Local AppData
		DefaultSearchDir := LocalAppData "\imput\Helium\Application"
		FileSelectFile, Path, 3, %DefaultSearchDir%\%BrowserExe%, %_SelectFileTitle%, %BrowserExe%
		If (ErrorLevel)
			ExitApp
		Else {
			IniWrite, %Path%, %IniFile%, Settings, Path
			Goto, CheckPath
		}
	}
}

ThisUpdaterRunning() {
	Process, Exist
	Query := "Select ProcessId from Win32_Process where ProcessId!=" ErrorLevel " and ExecutablePath=""" StrReplace(A_ScriptFullPath, "\", "\\") """"
	For Process in ComObjGet("winmgmts:").ExecQuery(Query) {
		Sleep, 1000
		For Process in ComObjGet("winmgmts:").ExecQuery(Query)
			Return True
		Break
	}
}

CheckWriteAccess() {
	If (!FileExist(A_ScriptDir "\" BrowserExe)) {
		FileAppend,, %IniFile%
		If (!ErrorLevel) {
			If (WorkDir <> A_Temp) {
				FileCreateDir, %ExtractDir%
				If (ErrorLevel)
					Die(_WritePermError, WorkDir)
			}
			Return
		}
	}

	AppData := A_AppData "\" Browser "\WinUpdater"

	If (IsPortable Or A_ScriptDir = AppData)
		Die(_WritePermError, A_ScriptDir)

	FileCreateDir, %AppData%
	If (ErrorLevel)
		Die(_WritePermError, AppData)

	Files := [ A_ScriptName, TaskCreateFile, TaskRemoveFile ]
	For Index, File in Files {
		If (!FileExist(AppData "\" File))
			FileCopy, %A_ScriptDir%\%File%, %AppData%
		If (ErrorLevel)
			Die(_CopyError, File " " _To "`n" AppData)
	}

	Run, %AppData%\%A_ScriptName% %Args%
	ExitApp
}

GetCurrentVersion() {
	If (Sz := DllCall("Version\GetFileVersionInfoSizeW", "WStr", Path, "Int", 0))
		If (DllCall("Version\GetFileVersionInfoW", "WStr", Path, "Int", 0, "UInt", VarSetCapacity(V, Sz), "Str", V))
			If (DllCall("Version\VerQueryValueW", "Str", V, "WStr", "\StringFileInfo\000004B0\ProductVersion", "PtrP", pInfo, "Int", 0))
				CurrentVersion := StrGet(pInfo, "UTF-16")

	If (!CurrentVersion)
		Die(_GetVersionError, Path)

	Build := GetCurrentBuild()

	GuiControl,, VerField, %CurrentVersion% (%Build%)
}

GetCurrentBuild() {
	Try {
		File := FileOpen(Path, "r")
		If (File) {
			File.Seek(0x3C, 0)
			Offset := File.ReadUInt()
			File.Seek(Offset, 0)
			If (File.ReadUInt() = 0x4550) {
				File.Seek(Offset + 4, 0)
				Machine := File.ReadUShort()
			}
			File.Close()

			Switch Machine {
				Case 0x8664:
					Return "x86_64"
				Case 0x014C:
					Return "i686"
				Case 0xAA64:
					Return "arm64"
			}
		}
		Die(_GetBuildError)
	} Catch e
		Die(_GetBuildError ": " e.Message)
}

SwitchTo64() {
	If (Build <> "i686")
		Return
	If (!A_Is64bitOS)
		Die(_32BitHelium " " _32BitOS)

	MsgBox, 52, %_Updater%, %_32BitHelium% %_SwitchTo64%
	IfMsgBox, No
		Die(_32BitHelium)

	Build := "x86_64"
}

CheckConnection() {
	Connected := Download(ConnectCheckUrl)
	If (!Connected Or !InStr(Connected, "github")) {
		RegExMatch(Connected, "i)<title>(.+?)</title>", Title)
		Title := Title1 ? "`n" Title1 "." : ""
		Die(_NoConnectionError Title,, !Scheduled)
	}
}

SelfUpdate() {
	Task := _Updater
	If (!VerCompare(GetLatestVersion(), ">" CurrentUpdaterVersion))
		Return

	RegExMatch(ReleaseInfo, "i)""name"":\s*""(" Browser "-WinUpdater.{1,15}\.zip)"".*?""browser_download_url"":\s*""(.+?)""", DownloadInfo)
	If (!DownloadInfo1 Or !DownloadInfo2)
		Return Log("SelfUpdate", _FindUrlError, True)

	Progress(_SelfUpdating)
	PreventShutdown()

	SelfUpdateZip := DownloadInfo1
	DownloadUrl := DownloadInfo2
	UrlDownloadToFile, %DownloadUrl%, %SelfUpdateZip%
	If (ErrorLevel Or !FileExist(SelfUpdateZip))
		Return Log("SelfUpdate", _DownloadSelfError, True)
	Verify(SelfUpdateZip)

	FileMove, %A_ScriptFullPath%, %A_ScriptFullPath%.wubak, 1
	If (!Extract(WorkDir "\" SelfUpdateZip, A_ScriptDir))
		Return Log("SelfUpdate", _ExtractionError, True)

	FileDelete, %SelfUpdateZip%
	If (IsPortable) {
		FileDelete, %A_ScriptDir%\%TaskCreateFile%
		FileDelete, %A_ScriptDir%\%TaskRemoveFile%
	}

	If (!FileExist(A_ScriptDir "\" UpdaterFile))
		Die(_ExtractionError)

	If (A_ScriptName <> UpdaterFile)
		FileMove, %A_ScriptDir%\%UpdaterFile%, %A_ScriptFullPath%

	Run, %A_ScriptFullPath% %Args%
	ExitApp
}

GetNewVersion() {
	Progress(_Checking)
	Task := Browser
	NewVersion := GetLatestVersion()
	IniRead, LastUpdateTo, %IniFile%, Log, LastUpdateTo, False
	If (!VerCompare(NewVersion, ">" CurrentVersion)) {
		Progress(_NoNewVersion, True)
		Log("LastResult", _NoNewVersion)
		Return False
	}
	Return NewVersion
}

GetUpdate() {
	GuiControl,, VerField, %CurrentVersion% %_To% %NewVersion% (%Build%)
	If (Portable Or !Scheduled)
		GuiShow()

	Download:
	DownloadUpdate()
	Verify(SetupFile)
	Waited := BrowserWaitClose()

	If (Waited) {
		If (VerCompare(GetNewVersion(), ">" NewVersion)) {
			FileDelete, %SetupFile%
			Goto, Download
		} Else
			Verify(SetupFile, False)
	}

	RunUpdate()
}

GetHeliumArch() {
	Switch Build {
		Case "x86_64":
			Return "x64"
		Case "arm64":
			Return "arm64"
		Default:
			Return Build
	}
}

DownloadUpdate() {
	; Match asset name pattern: helium_{version}_{arch}-installer.exe or helium_{version}_{arch}-windows.zip
	ArchSuffix := GetHeliumArch()
	FilenameEnd := "_" ArchSuffix (IsPortable ? "-windows\.zip" : "-installer\.exe")
	RegExMatch(ReleaseInfo, "i)""name"":\s*""(helium_.{1,40}?" FilenameEnd ")"".*?""browser_download_url"":\s*""(.+?)""", DownloadInfo)

	If (!DownloadInfo1 Or !DownloadInfo2)
		Die(_FindUrlError)

	SetupFile := DownloadInfo1
	DownloadUrl := DownloadInfo2

	If (FileExist(SetupFile))
		Return

	; Download setup file
	Progress(_Downloading)
	UrlDownloadToFile, %DownloadUrl%, %SetupFile%
	If (ErrorLevel Or !FileExist(SetupFile))
		Die(_DownloadSetupError)
}

BrowserWaitClose() {
	Wait:
	For Proc in ComObjGet("winmgmts:").ExecQuery("Select ProcessId from Win32_Process where ExecutablePath=""" StrReplace(Path, "\", "\\") """") {
		If (!Notified) {
			Progress(_NewVersionFound)
			Notify(_NewVersionFound)
			Notified := True
		}
		ReleaseMem()
		Process, WaitClose, % Proc.ProcessId
		Goto, Wait
	}

	Return Notified
}

ReleaseMem() {
	Proc := DllCall("OpenProcess", "UInt", 0x001F0FFF, "Int", 0, "Int", DllCall("GetCurrentProcessId"))
	DllCall("SetProcessWorkingSetSize", "UInt", Proc, "Int", -1, "Int", -1)
	DllCall("CloseHandle", "Int", Proc)
}

Verify(File, HashOnly = True) {
	; Get SHA256 digest from GitHub API JSON for the downloaded asset
	If (Task = _Updater And !HashOnly)
		Return

	RegEx := "i)""name"":\s*""" RegExReplace(File, "([\.\-])", "\$1") """.*?""digest"":\s*""sha256:([a-f0-9]+)"""
	RegExMatch(ReleaseInfo, RegEx, Checksum)
	If (!Checksum1)
		Die(_FindChecksumError)

	If (Task = Browser)
		Progress(_CheckingHash)
	If (Checksum1 <> Hash(File))
		Die(_ChecksumMatchError, File)
}

RunUpdate() {
	PreventShutdown()
	If (IsPortable)
		ExtractPortable()
	Else {
		If (A_IsAdmin)
			Install()
		Else {
			Progress(_Downloaded)
			Gui, Add, Button, vUpdateButton gInstall w148 x86 y110 Default, %_StartUpdate%
			GuiControl, Move, TaskSetField, y146
			GuiShow(True)
		}
	}
}

ExtractPortable() {
	BrowserWaitClose()
	PreventRunningWhileUpdating()
	Progress(_Extracting)
	If (!Extract(WorkDir "\" SetupFile, ExtractDir))
		Die(_ExtractionError)

	Loop, Files, %ExtractDir%\*, D
	{
		HeliumExtracted := A_LoopFilePath
		Break
	}

	; Remove files not present in the new version's browser folder
	SetWorkingDir, %A_ScriptDir%\%Browser%
	Loop, Files, *, R
	{
		If (!FileExist(HeliumExtracted "\" Browser "\" A_LoopFilePath) And A_LoopFileName <> BrowserExe ".wubak") {
			FileCreateDir, %Folder%.wubak\%A_LoopFileDir%
			FileMove, %A_LoopFilePath%, %Folder%.wubak\%A_LoopFilePath%, 1
		}
	}

	SetWorkingDir, %HeliumExtracted%

	Loop, Files, *, R
	{
		If (A_LoopFileName = BrowserExe Or A_LoopFileName = UpdaterFile)
			Continue
		FileGetSize, CurrentFileSize, %A_ScriptDir%\%A_LoopFilePath%
		If (!FileExist(A_ScriptDir "\" A_LoopFileDir))
			FileCreateDir, %A_ScriptDir%\%A_LoopFileDir%
		If (!FileExist(A_ScriptDir "\" A_LoopFilePath) Or A_LoopFileSize <> CurrentFileSize Or Hash(A_LoopFilePath) <> Hash(A_ScriptDir "\" A_LoopFilePath)) {
			FileMove, %A_LoopFilePath%, %A_ScriptDir%\%A_LoopFilePath%, 1
			If (ErrorLevel)
				Die(_MoveToTargetError, A_LoopFilePath)
			ChangesMade := True
		}
	}
	FileMove, %Browser%\%BrowserExe%, %Path%, 1
	If (ErrorLevel)
		Die(_MoveToTargetError, BrowserExe)

	SetWorkingDir, %WorkDir%
	WriteReport()
}

Install() {
	GuiControl, Disable, UpdateButton
	BrowserWaitClose()
	PreventRunningWhileUpdating()
	Progress(_Installing)
	If (Scheduled)
		Notify(_Installing, CurrentVersion " " _To " v" NewVersion, 3000)
	SetupParams := StrReplace(SetupParams, "{}", Folder)
	; Run silent setup
	RunWait, %SetupFile% /S %SetupParams%,, UseErrorLevel
	If (!ErrorLevel)
		WriteReport()
	Else {
		MsgBox, 52, %_Updater%, %_SilentUpdateError%
		IfMsgBox, No
			Progress(StrReplace(_UpdateError, "{}"), True)
		Else {
			RunWait, %SetupFile% %SetupParams%,, UseErrorLevel
			If (ErrorLevel)
				Die(StrReplace(_UpdateError, "{}", " (" A_LastError ")"))
			Else
				WriteReport()
		}
	}
}

PreventRunningWhileUpdating() {
	If (A_IsAdmin Or IsPortable)
		FileMove, %Path%, %Path%.wubak, 1
}

WriteReport() {
	Log("LastUpdate", "(" Build ")", True)
	Log("LastUpdateFrom", CurrentVersion)
	Log("LastUpdateTo", NewVersion)
	Log("LastResult", _IsUpdated)
	Progress(_IsUpdated, True)
	Notify(_IsUpdated, CurrentVersion " " _To " v" NewVersion, Scheduled And !ShutdownBlocked ? 60000 : 0)

	Exit()
}

Restart() {
	Return Exit(True)
}

Exit(Restart = False) {
	If (!Restart And !ShutdownBlocked And !A_Args.Length() And WinExist("ahk_id " GuiHwnd))
		GuiWaitClose()
	Else
		Gui, Destroy

	Log("LastRun",, True)
	SetWorkingDir, %WorkDir%
	If (SetupFile And (Died = _DownloadSetupError Or Died = _ChecksumMatchError Or Done)) {
		Sleep, 2000
		FileDelete, %SetupFile%
	}
	If (IsPortable)
		FileRemoveDir, %ExtractDir%, 1
	If (FileExist(A_ScriptFullPath ".wubak") And !FileExist(A_ScriptFullPath))
		FileMove, %A_ScriptFullPath%.wubak, %A_ScriptFullPath%
	Else
		FileDelete, %A_ScriptFullPath%.wubak

	If (FileExist(Path ".wubak")) {
		If (FileExist(Path))
			FileDelete, %Path%.wubak
		Else
			FileMove, %Path%.wubak, %Path%
	}

	If (Restart)
		Run, % A_ScriptFullPath StrReplace(Args, "/Scheduled")
	Else If (IsPortable And RunningPortable) {
		A_Args.RemoveAt(1)
		CheckArgs()
		Run, %A_ScriptDir%\%Browser%\%BrowserExe% %Args%
	}

	ExitApp
}

; Helper functions

Die(Error, Var = False, Show = True) {
	Msg := Error
	If (Var)
		Msg := StrReplace(Msg, "{}", Var)
	Msg := StrReplace(Msg, "{Task}", Task)
	Log("LastResult", Msg)
	GuiControl, Hide, ProgField
	GuiControl, Hide, LogField
	GuiControl, Disable, TaskSetField
	GuiControl, Hide, TaskSetField
	GuiControl, Hide, UpdateButton
	Gui, Font, s38
	Gui, Add, Text, x264 y-2 cYellow, % Chr("0x26A0")
	Gui, Font, s9
	Msg := Msg " " (ChangesMade ? _ChangesMade : _NoChangesMade) "`n`n" _GoToWebsite
	Gui, Add, Link, gAction x15 y81 w290 cCCCCCC, %Msg%

	Died := Error
	If (Show)
		GuiShow(True)
	Else
		Exit()
}

Download(URL) {
	CurrentDomain := SubStr(URL, 1, InStr(URL, "/",,, 3) - 1)
	SetTimer, CrlCheck
	Try {
		Random, Num, 1, 1024
		Object := ComObjCreate("Msxml2.XMLHTTP")
		Object.open("GET", URL "?i=" Num, false)
		Object.setRequestHeader("User-Agent", "WinUpdater")
		Object.send()
		Result := Object.responseText
	} Catch {
		Result := False
	}
	SetTimer, CrlCheck, Delete
	CurrentDomain := ""
	Return Result
}

CrlCheck() {
	If (WinExist("ahk_exe " UpdaterFile " ahk_class #32770",, Browser)) {
		If (!IgnoreCrlErrors) {
			Msg := StrReplace(_CrlError, "{}", CurrentDomain)
			MsgBox, 52, %_Updater%, %Msg%
			IfMsgBox, No
			{
				ControlClick, Button2
				Return
			}
		}
		ControlClick, Button1
	}
}

PreventShutdown() {
	DllCall("kernel32.dll\SetProcessShutdownParameters", "UInt", 0x4FF, "UInt", 0)
	OnMessage(0x0011, "BlockShutdown")
}

BlockShutdown(wParam, lParam) {
	DllCall("ShutdownBlockReasonCreate", "ptr", GuiHwnd, "wstr", _IsUpdating)
	ShutdownBlocked := True
	OnExit("AllowShutdown")
	GuiShow()
	Return False
}

AllowShutdown() {
	DllCall("ShutdownBlockReasonDestroy", "ptr", A_ScriptHwnd)
	OnExit(A_ThisFunc, 0)
}

Extract(From, To) {
	FileRemoveDir, %ExtractDir%, 1
	FileCopyDir, %From%, %To%, 1
	Error := ErrorLevel
	If (Error) {
		FileRemoveDir, %ExtractDir%, 1
		FileCreateDir, %ExtractDir%
		SetWorkingDir, %To%
		RunWait, powershell.exe -NoProfile -Command "Expand-Archive """%From%""" . -Force" -ErrorAction Stop,, Hide
		Error := ErrorLevel
		SetWorkingDir, %WorkDir%
	}

	Return !(Error <> 0)
}

GetLatestVersion() {
	ReleaseUrl := (Task = _Updater ? UpdaterApiUrl : ReleaseApiUrl)
	ReleaseInfo := Download(ReleaseUrl)
	If (!ReleaseInfo) {
		If (Task = _Updater)
			Return CurrentUpdaterVersion
		Else
			Die(_DownloadJsonError)
	}

	RegExMatch(ReleaseInfo, "i)tag_name"":\s*""v?(.+?)""", Release)
	LatestVersion := Release1
	If (!LatestVersion) {
		If (Task = _Updater And InStr(ReleaseInfo, "{") <> 1)
			Return CurrentUpdaterVersion
		Else
			Die(_JsonVersionError)
	}

	Return LatestVersion
}

GuiClose() {
	try {
		Gui, Destroy
	} catch {}
	Exit()
}

GuiEscape:
	If (Died Or Done)
		GuiClose()
Return

GuiShow(Wait = False) {
	NoFocus := WinExist("ahk_id " GuiHwnd) ? "NA" : "Minimize"
	Gui, Show, % "AutoSize " (Focus() ? "" : NoFocus)
	If (!Focus())
		Gui, Flash
	ControlFocus, SysLink1
	If (Wait)
		GuiWaitClose()
}

GuiWaitClose() {
	ReleaseMem()
	WinWaitClose, ahk_id %GuiHwnd%
}

Focus() {
	Return WinActive("ahk_id " GuiHwnd) Or !Scheduled Or ShutdownBlocked
}

Hash(filePath, hashType = 4) {
	PROV_RSA_AES := 24
	CRYPT_VERIFYCONTEXT := 0xF0000000
	BUFF_SIZE := 1024 * 1024
	HP_HASHVAL := 0x0002
	HP_HASHSIZE := 0x0004

	HASH_ALG := hashType = 1 ? (CALG_MD2 := 32769) : HASH_ALG
	HASH_ALG := hashType = 2 ? (CALG_MD5 := 32771) : HASH_ALG
	HASH_ALG := hashType = 3 ? (CALG_SHA := 32772) : HASH_ALG
	HASH_ALG := hashType = 4 ? (CALG_SHA_256 := 32780) : HASH_ALG
	HASH_ALG := hashType = 5 ? (CALG_SHA_384 := 32781) : HASH_ALG
	HASH_ALG := hashType = 6 ? (CALG_SHA_512 := 32782) : HASH_ALG

	f := FileOpen(filePath, "r", "CP0")
	If (!IsObject(f))
		Return 0

	If (!hModule := DllCall("GetModuleHandleW", "str", "Advapi32.dll", "Ptr"))
		hModule := DllCall("LoadLibraryW", "str", "Advapi32.dll", "Ptr")

	If (!DllCall("Advapi32\CryptAcquireContextW"
			,"Ptr*", hCryptProv
			,"Uint", 0
			,"Uint", 0
			,"Uint", PROV_RSA_AES
			,"UInt", CRYPT_VERIFYCONTEXT))
		Goto, FreeHandles

	If (!DllCall("Advapi32\CryptCreateHash"
			, "Ptr",  hCryptProv
			, "Uint", HASH_ALG
			, "Uint", 0
			, "Uint", 0
			, "Ptr*", hHash))
		Goto, FreeHandles

	VarSetCapacity(read_buf, BUFF_SIZE, 0)
	hCryptHashData := DllCall("GetProcAddress", "Ptr", hModule, "AStr", "CryptHashData", "Ptr")

	While (cbCount := f.RawRead(read_buf, BUFF_SIZE)) {
		If (cbCount = 0)
			Break

		If (!DllCall(hCryptHashData
				, "Ptr",  hHash
				, "Ptr",  &read_buf
				, "Uint", cbCount
				, "Uint", 0))
			Goto, FreeHandles
	}

	If (!DllCall("Advapi32\CryptGetHashParam"
			, "Ptr",   hHash
			, "Uint",  HP_HASHSIZE
			, "Uint*", HashLen
			, "Uint*", HashLenSize := 4
			, "UInt",  0))
		Goto, FreeHandles

	VarSetCapacity(pbHash, HashLen, 0)
	If (!DllCall("Advapi32\CryptGetHashParam"
			, "Ptr",   hHash
			, "Uint",  HP_HASHVAL
			, "Ptr",   &pbHash
			, "Uint*", HashLen
			, "UInt",  0))
		Goto, FreeHandles

	SetFormat, Integer, Hex
	Loop, %HashLen%
	{
		num := NumGet(pbHash, A_Index - 1, "UChar")
		hashVal .= SubStr((num >> 4), 0) . substr((num & 0xf), 0)
	}
	SetFormat, Integer, D

FreeHandles:
	f.Close()
	DllCall("FreeLibrary", "Ptr", hModule)
	DllCall("Advapi32\CryptDestroyHash", "Ptr", hHash)
	DllCall("Advapi32\CryptReleaseContext", "Ptr", hCryptProv, "UInt", 0)

	Return hashVal
}

Log(Key, Msg = "", PrefixTime = False) {
	Msg := StrReplace(Msg, "{Task}", Task)
	If (PrefixTime) {
		FormatTime, CurrentTime
		Msg := CurrentTime " " Msg
	}
	Msg := StrReplace(Msg, "`n", " ")
	IniWrite, %Msg%, %IniFile%, Log, %Key%
}

Notify(Msg, Ver = 0, Delay = 0) {
	If (!Ver)
		Ver := NewVersion
	Menu, Tray, Tip, %_Updater% %CurrentUpdaterVersion%`n%Folder%`n`n%Msg%
	If (Scheduled Or Delay) {
		TrayTip, %Msg%, v%Ver%,, 16
		Sleep, %Delay%
	}
}

Progress(Msg, End = False) {
	GuiControl,, LogField, % SubStr(Msg, InStr(Msg, "`n") + 1)
	If (End)
		GuiControl,, ProgField, 100
	Else If (Msg <> _NewVersionFound)
		GuiControl,, ProgField, +15

	Menu, Tray, Tip, %_Updater% %CurrentUpdaterVersion%`n%Folder%`n`n%Msg%
	Done := End
}

TaskCheck() {
	RunWait schtasks.exe /query /tn "%_Updater% (%A_UserName%)",, Hide
	GuiControl,, TaskSetField, % ErrorLevel = 0
	Gui, Submit, NoHide
}

TaskSet() {
	If (SettingTask) {
		Progress(_SettingTask)
		If (A_Args[1] = "/CreateTask")
			TaskSetField := 0
		Else If (A_Args[1] = "/RemoveTask")
			TaskSetField := 1
		Sleep, 1000
	}

	Script := A_ScriptDir "\" (TaskSetField = 0 ? TaskCreateFile : TaskRemoveFile)
	GuiControl,, TaskSetField, -1
	RunWait, powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "%Script%"
	WinWaitActive, ahk_id %GuiHwnd%
	Sleep, 1000
	WinWaitActive
	TaskCheck()

	If (SettingTask) {
		SettingTask := 0
		Progress(_SettingTask _Done, True)
		GuiShow(True)
	}
}

RunElevated() {
	Try {
		Run *RunAs "%A_ScriptFullPath%" %Args% /Restart
	}
	ExitApp
}

Unelevate(Forced = False) {
	If (!A_IsAdmin Or IsPortable Or (Scheduled And !Forced) Or RegExMatch(DllCall("GetCommandLine", "str"), " /Restart(?!\S)"))
		Return

	If (RunUnelevated(A_ScriptFullPath, "/Restart " Args, A_ScriptDir))
		ExitApp
	Else
		Die(_IsElevated)
}

RunUnelevated(Prms*) {
	Try {
		ShellWindows := ComObjCreate("Shell.Application").Windows
		VarSetCapacity(_Hwnd, 4, 0)
		Desktop := ShellWindows.FindWindowSW(0, "", 8, ComObj(0x4003, &_Hwnd), 1)
		If Ptlb := ComObjQuery(Desktop
				, "{4C96BE40-915C-11CF-99D3-00AA004AE837}"
				, "{000214E2-0000-0000-C000-000000000046}")
		{
				If DllCall(NumGet(NumGet(Ptlb + 0) + 15 * A_PtrSize), "ptr", Ptlb, "ptr*", Psv := 0) = 0
				{
						VarSetCapacity(IID_IDispatch, 16)
						NumPut(0x46000000000000C0, NumPut(0x20400, IID_IDispatch, "int64"), "int64")
						DllCall(NumGet(NumGet(psv+0)+15*A_PtrSize), "ptr", Psv
							, "uint", 0, "ptr", &IID_IDispatch, "ptr*", Pdisp := 0)
						Shell := ComObj(9, Pdisp, 1).Application
						Shell.ShellExecute(Prms*)
						ObjRelease(Psv)
				}
				ObjRelease(Ptlb)
		}
		Return True
	} Catch e
		Return False
}
