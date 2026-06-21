; Inno Setup script for MODIPAY Windows desktop installer.
; Build the release binaries first, then compile this script with ISCC:
;   D:\Project\src\flutter\bin\flutter.bat build windows --release
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\modipay.iss
; Output lands in installer\Output\ModipaySetup-<version>.exe

#define AppName "MODIPAY"
#define AppVersion "1.0.2"
#define AppPublisher "Moditeknosolusindo"
#define AppExeName "modipay.exe"

[Setup]
AppId={{332548B8-1BE7-44EA-9A4C-067BC938B58D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=ModipaySetup-{#AppVersion}
SetupIconFile=..\assets\icons\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
