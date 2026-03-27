; AIO Studio — Inno Setup 6 installer script
; Usage:  ISCC.exe installer\aio_studio.iss /DAppVersion=1.0.7
;         (run from the repository root after `flutter build windows --release`)

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{B7E3F4A1-9C2D-4E8F-A6B5-1D3C7F0E2A94}
AppName=AIO Studio
AppVersion={#AppVersion}
AppVerName=AIO Studio {#AppVersion}
AppPublisher=AIO Studio
AppPublisherURL=https://github.com/icaruszezen/AIOStudio
AppSupportURL=https://github.com/icaruszezen/AIOStudio/issues
DefaultDirName={autopf}\AIO Studio
DefaultGroupName=AIO Studio
UninstallDisplayIcon={app}\aio_studio.exe
OutputDir=Output
OutputBaseFilename=aio-studio-setup-{#AppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\AIO Studio"; Filename: "{app}\aio_studio.exe"
Name: "{autodesktop}\AIO Studio"; Filename: "{app}\aio_studio.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\aio_studio.exe"; Description: "{cm:LaunchProgram,AIO Studio}"; Flags: nowait postinstall skipifsilent
