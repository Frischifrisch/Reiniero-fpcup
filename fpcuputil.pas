{ Utility unit for various FPCup versions
Copyright (C) 2012-2014 Reinier Olislagers, Ludo Brands

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Library General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at your
option) any later version with the following modification:

As a special exception, the copyright holders of this library give you
permission to link this library with independent modules to produce an
executable, regardless of the license terms of these independent modules,and
to copy and distribute the resulting executable under terms of your choice,
provided that you also meet, for each linked independent module, the terms
and conditions of the license of that module. An independent module is a
module which is not derived from or based on this library. If you modify
this library, you may extend this exception to your version of the library,
but you are not obligated to do so. If you do not wish to do so, delete this
exception statement from your version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
for more details.

You should have received a copy of the GNU Library General Public License
along with this library; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
}

unit fpcuputil;
{ Utility functions that might be needed by fpcup core and plugin units }

//{$mode DELPHI}{$H+}
{$mode objfpc}{$H+}

{$define ENABLEWGET}
{$define ENABLENATIVE}

{$ifdef Haiku}
// synaser does not compile under Haiku
{$undef ENABLENATIVE}
{$endif}
{$ifdef OpenBSD}
// synaser does not work under OpenBSD
{$undef ENABLENATIVE}
{$endif}
{$ifdef Darwin}
// Do not use wget and family under Darwin
{$undef ENABLEWGET}
{$endif}
{$ifdef Windows}
// Do not use wget and family under Windows
{.$undef ENABLEWGET}
{$endif}

{$if not defined(ENABLEWGET) and not defined(ENABLENATIVE)}
{$error No downloader defined !!! }
{$endif}

interface

uses
  Classes, SysUtils, strutils,
  typinfo,
  zipper,
  fphttpclient, // for github api file list and others
  {$ifdef darwin}
  ns_url_request,
  {$endif}
  fpopenssl,openssl,
  //fpftpclient,
  eventlog;

Const
  MAXCONNECTIONRETRIES=5;
  {$ifdef LCL}
  BeginSnippet='fpcupdeluxe:'; //helps identify messages as coming from fpcupdeluxe instead of make etc
  {$else}
  {$ifndef FPCONLY}
  BeginSnippet='fpclazup:'; //helps identify messages as coming from fpclazup instead of make etc
  {$else}
  BeginSnippet='fpcup:'; //helps identify messages as coming from fpcup instead of make etc
  {$endif}
  {$endif}
  Seriousness: array [TEventType] of string = ('custom:', 'info:', 'WARNING:', 'ERROR:', 'debug:');


type
  //callback = class
  //  class procedure Status (Sender: TObject; Reason: THookSocketReason; const Value: String);
  //end;

  {TThreadedUnzipper}

  TOnZipProgress = procedure(Sender: TObject; FPercent: double) of object;
  TOnZipFile = procedure(Sender: TObject; AFileName : string; FileCount,TotalFileCount:cardinal) of object;
  TOnZipCompleted = TNotifyEvent;

  TThreadedUnzipper = class(TThread)
  private
    FStarted: Boolean;
    FErrMsg: String;
    FUnZipper: TUnZipper;
    FPercent: double;
    FFileCount: cardinal;
    FFileList:TStrings;
    FTotalFileCount: cardinal;
    FCurrentFile: string;
    FOnZipProgress: TOnZipProgress;
    FOnZipFile: TOnZipFile;
    FOnZipCompleted: TOnZipCompleted;
    procedure DoOnProgress(Sender : TObject; Const Pct : Double);
    procedure DoOnFile(Sender : TObject; Const AFileName : string);
    procedure DoOnZipProgress;
    procedure DoOnZipFile;
    procedure DoOnZipCompleted;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure DoUnZip(const ASrcFile, ADstDir: String; Files:array of string);
  published
    property OnZipProgress: TOnZipProgress read FOnZipProgress write FOnZipProgress;
    property OnZipFile: TOnZipFile read FOnZipFile write FOnZipFile;
    property OnZipCompleted: TOnZipCompleted read FOnZipCompleted write FOnZipCompleted;
  end;

  TNormalUnzipper = class(TObject)
  private
    FUnZipper: TUnZipper;
    FFileCnt: cardinal;
    FFileList:TStrings;
    FTotalFileCnt: cardinal;
    FCurrentFile: string;
    FFlat:boolean;
    procedure DoOnFile(Sender : TObject; Const AFileName : string);
  public
    function DoUnZip(const ASrcFile, ADstDir: String; Files:array of string):boolean;
    property Flat:boolean read FFlat write FFlat default False;
  end;


  { TLogger }
  TLogger = class(TObject)
  private
    FLog: TEventLog; //Logging/debug output to file
    function GetLogFile: string;
    procedure SetLogFile(AValue: string);
  public
    // Write to log and optionally console with seriousness etInfo
    procedure WriteLog(Message: string; ToConsole: Boolean=true);overload;
    // Write to log and optionally console with specified seriousness
    procedure WriteLog(EventType: TEventType;Message: string; ToConsole: Boolean);overload;
    property LogFile: string read GetLogFile write SetLogFile ;
    constructor Create;
    destructor Destroy; override;
  end;

  TBasicDownLoader = Class(TComponent)
  private
    FVerbose:boolean;
    FMaxRetries:byte;
    FUsername: string;
    FPassword: string;
    FHTTPProxyHost: string;
    FHTTPProxyPort: integer;
    FHTTPProxyUser: string;
    FHTTPProxyPassword: string;
    procedure parseFTPHTMLListing(F:TStream;filelist:TStringList);
  protected
    procedure SetVerbose(aValue:boolean);virtual;
    property MaxRetries : Byte Read FMaxRetries Write FMaxRetries;
    property Username: string read FUsername;
    property Password: string read FPassword;
    property HTTPProxyHost: string read FHTTPProxyHost;
    property HTTPProxyPort: integer read FHTTPProxyPort;
    property HTTPProxyUser: string read FHTTPProxyUser;
    property HTTPProxyPassword: string read FHTTPProxyPassword;
    property Verbose: boolean write SetVerbose;
  public
    constructor Create;virtual;
    constructor Create(AOwner: TComponent);override;
    destructor Destroy;override;
    procedure setCredentials(user,pass:string);virtual;
    procedure setProxy(host:string;port:integer;user,pass:string);virtual;
    function getFile(const URL,filename:string):boolean;virtual;abstract;
    function getFTPFileList(const URL:string; filelist:TStringList):boolean;virtual;abstract;
    function checkURL(const URL:string):boolean;virtual;abstract;
  end;

  {$ifdef ENABLENATIVE}
  TUseNativeDownLoader = Class(TBasicDownLoader)
  private
    {$ifdef Darwin}
    aFPHTTPClient:TNSHTTPSendAndReceive;
    {$else}
    aFPHTTPClient:TFPHTTPClient;
    {$endif}
    StoredTickCount:QWord;
    aFilename:string;
    procedure DoProgress(Sender: TObject; Const ContentLength, CurrentPos : Int64);
    procedure DoOnWriteStream(Sender: TObject; APos: Int64);
    procedure DoHeaders(Sender : TObject);
    procedure DoPassword(Sender: TObject; var {%H-}RepeatRequest: Boolean);
    procedure ShowRedirect({%H-}ASender : TObject; Const ASrc : String; Var ADest : String);
    function Download(const URL: String; filename:string):boolean;
    function FTPDownload(Const URL : String; filename:string):boolean;
    function HTTPDownload(Const URL : String; filename:string):boolean;
  protected
    procedure SetVerbose(aValue:boolean);override;
  public
    constructor Create;override;
    destructor Destroy; override;
    procedure setProxy(host:string;port:integer;user,pass:string);override;
    function getFile(const URL,filename:string):boolean;override;
    function getFTPFileList(const URL:string; filelist:TStringList):boolean;override;
    function checkURL(const URL:string):boolean;override;
  end;
  {$endif}

  {$ifdef ENABLEWGET}
  TUseWGetDownloader = Class(TBasicDownLoader)
  private
    FCURLOk:boolean;
    FWGETOk:boolean;
    //WGETBinary:string;
    function WGetDownload(Const URL : String; Dest : TStream):boolean;
    function LibCurlDownload(Const URL : String; Dest : TStream):boolean;
    function WGetFTPFileList(const URL:string; filelist:TStringList):boolean;
    function LibCurlFTPFileList(const URL:string; filelist:TStringList):boolean;
    function Download(const URL: String; Dest: TStream):boolean;
    function FTPDownload(Const URL : String; Dest : TStream):boolean;
    function HTTPDownload(Const URL : String; Dest : TStream):boolean;
  public
    class var
        WGETBinary:string;
    constructor Create;override;
    constructor Create(aWGETBinary:string);
    function getFile(const URL,filename:string):boolean;override;
    function getFTPFileList(const URL:string; filelist:TStringList):boolean;override;
    function checkURL(const URL:string):boolean;override;
  end;
  {$endif}

  {$ifdef ENABLENATIVE}
  TNativeDownloader = TUseNativeDownLoader;
  {$else}
  TNativeDownloader = TUseWGetDownloader;
  {$endif}
  {$ifdef ENABLEWGET}
  TWGetDownloader = TUseWGetDownloader;
  {$else}
  TWGetDownloader = TUseNativeDownLoader;
  {$endif}

// Create shortcut on desktop to Target file
procedure CreateDesktopShortCut(Target, TargetArguments, ShortcutName: string) ;
// Create shell script in ~ directory that links to Target
procedure CreateHomeStartLink(Target, TargetArguments, ShortcutName: string);
{$IFDEF MSWINDOWS}
// Delete shortcut on desktop
procedure DeleteDesktopShortcut(ShortcutName: string);
{$ENDIF MSWINDOWS}
// Copy a directory recursive
function DirCopy(SourcePath, DestPath: String): Boolean;
// Delete directory and children, even read-only. Equivalent to rm -rf <directory>:
function DeleteDirectoryEx(DirectoryName: string): boolean;
// Recursively delete files with specified name(s), only if path contains specfied directory name somewhere (or no directory name specified):
function DeleteFilesSubDirs(const DirectoryName: string; const Names:TStringList; const OnlyIfPathHas: string): boolean;
// Recursively delete files with specified extension(s),
// only if path contains specfied directory name somewhere (or no directory name specified):
function DeleteFilesExtensionsSubdirs(const DirectoryName: string; const Extensions:TstringList; const OnlyIfPathHas: string): boolean;
// only if filename contains specfied part somewhere
function DeleteFilesNameSubdirs(const DirectoryName: string; const OnlyIfNameHas: string): boolean;
function GetFileNameFromURL(URL:string):string;
function StripUrl(URL:string): string;
function GetCompilerVersion(CompilerPath: string): string;
function GetLazbuildVersion(LazbuildPath: string): string;
procedure GetVersionFromString(const VersionSnippet:string;var Major,Minor,Build: Integer);
function CalculateFullVersion(Major,Minor,Release:integer):dword;
function GetNumericalVersion(VersionSnippet: string): word;
function GetVersionFromUrl(URL:string): string;
function GetReleaseCandidateFromUrl(aURL:string): integer;
// Download from HTTP (includes Sourceforge redirection support) or FTP
// HTTP download can work with http proxy
function Download(UseWget:boolean; URL, TargetFile: string; HTTPProxyHost: string=''; HTTPProxyPort: integer=0; HTTPProxyUser: string=''; HTTPProxyPassword: string=''): boolean;
function GetGitHubFileList(aURL:string;fileurllist:TStringList; HTTPProxyHost: string=''; HTTPProxyPort: integer=0; HTTPProxyUser: string=''; HTTPProxyPassword: string=''):boolean;
{$IFDEF MSWINDOWS}
function CheckFileSignature(aFilePath: string): boolean;
function DownloadByPowerShell(URL, TargetFile: string): boolean;
// Get Windows major and minor version number (e.g. 5.0=Windows 2000)
function GetWin32Version(out Major,Minor,Build : Integer): Boolean;
function IsWindows64: boolean;
// Get path for Windows per user storage of application data. Useful for storing settings
function GetLocalAppDataPath: string;
{$ENDIF MSWINDOWS}
//check if there is at least one directory between Dir and root
function ParentDirectoryIsNotRoot(Dir:string):boolean;
// Shows non-debug messages on screen (no logging); also shows debug messages if DEBUG defined
procedure infoln(Message: string; const Level: TEventType=etInfo);
// Moves file if it exists, overwriting destination file
function MoveFile(const SrcFilename, DestFilename: string): boolean;
//Get a temp file
Function GetTempFileNameExt(Const Dir,Prefix,Ext : String) : String;
//Get a temp directory
Function GetTempDirName(Const Dir,Prefix : String) : String;
// Correct line-endings
function FileCorrectLineEndings(const SrcFilename, DestFilename: string): boolean;
// Correct directory separators
function FixPath(const s:string):string;
function FileIsReadOnly(const s:string):boolean;
function MaybeQuoted(const s:string):string;
// Like ExpandFilename but does not expand an empty string to current directory
function SafeExpandFileName (Const FileName : String): String;
// Get application name
function SafeGetApplicationName: String;
// Get application path
function SafeGetApplicationPath: String;
function SaveFileFromResource(filename,resourcename:string):boolean;
// Copies specified resource (e.g. fpcup.ini, settings.ini)
// to application directory
function SaveInisFromResource(filename,resourcename:string):boolean;
// Searches for SearchFor in the stringlist and returns the index if found; -1 if not
// Search optionally starts from position SearchFor
function StringListStartsWith(SearchIn:TStringList; SearchFor:string; StartIndex:integer=0; CS:boolean=false): integer;
{$IFDEF UNIX}
function XdgConfigHome: String;
function GetGCCDirectory:string;
{$ENDIF UNIX}
{$ifdef Darwin}
function GetSDKVersion(aSDK: string):string;
{$endif}
function CompareVersionStrings(s1,s2: string): longint;
function ExistWordInString(aString:pchar; aSearchString:string; aSearchOptions: TStringSearchOptions): Boolean;
function GetEnumNameSimple(aTypeInfo:PTypeInfo;const aEnum:integer):string;
// Emulates/runs which to find executable in path. If not found, returns empty string
function Which(Executable: string): string;
function IsExecutable(Executable: string):boolean;
function CheckExecutable(Executable, Parameters, ExpectOutput: string): boolean;
function GetJava: string;
function CheckJava: boolean;
function ExtractFileNameOnly(const AFilename: string): string;
function DoubleQuoteIfNeeded(s: string): string;

function UppercaseFirstChar(s: String): String;
function DirectoryIsEmpty(Directory: string): Boolean;
function GetTargetCPU:string;
function GetTargetOS:string;
function GetTargetCPUOS:string;
function GetFPCTargetCPUOS(const aCPU,aOS:string;const Native:boolean=true): string;
function GetDistro:string;
function GetFreeBSDVersion:byte;
function checkGithubRelease(const aURL:string):string;
{$IF FPC_FULLVERSION < 30300}
Function Pos(Const Substr : RawByteString; Const Source : RawByteString; Offset : Sizeint = 1) : SizeInt;
{$ENDIF}
var
  resourcefiles:TStringList;

implementation

uses
  {$ifdef LCL}
  Forms,Controls,
  {$endif}
  IniFiles,
  DOM,DOM_HTML,SAX_HTML,
  {$ifdef ENABLENATIVE}
  ftpsend,
  {$else}
  ftplist,
  {$endif}
  FileUtil,
  LazFileUtils,
  fpwebclient,fphttpwebclient,
  fpjson, jsonparser,
  uriparser
  {$IFDEF MSWINDOWS}
    //Mostly for shortcut code
    ,windows, shlobj {for special folders}, ActiveX, ComObj, WinDirs
  {$ENDIF MSWINDOWS}
  {$IFDEF UNIX}
  ,unix,baseunix
  {$ENDIF}
  {$IFDEF ENABLEWGET}
  // for wget downloader
  ,process
  // for libc downloader
  ,fpcuplibcurl
  {$ENDIF ENABLEWGET}
  ,processutils
  ;

const
  USERAGENT = 'curl/7.50.1 (i686-pc-linux-gnu) libcurl/7.50.1 OpenSSL/1.0.1t zlib/1.2.8 libidn/1.29 libssh2/1.4.3 librtmp/2.3';
  //USERAGENT = 'Mozilla/5.0 (compatible; fpweb)';
  //USERAGENT = 'Mozilla/4.0 (compatible; MSIE 5.01; Windows NT 5.0)';
  CURLUSERAGENT='curl/7.51.0';

{$i revision.inc}

type
  TOnWriteStream = procedure(Sender: TObject; APos: Int64) of object;

  TDownloadStream = class(TStream)
  private
    FOnWriteStream: TOnWriteStream;
    FStream: TStream;
  public
    constructor Create(AStream: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(Offset: LongInt; Origin: Word): LongInt; override;
    procedure DoProgress;
  published
    property OnWriteStream: TOnWriteStream read FOnWriteStream write FOnWriteStream;
  end;


function GetStringFromBuffer(const field:PChar):string;
begin
  if ( field <> nil ) then
  begin
    //strpas(field);
    result:=field;
    UniqueString(result);
    SetLength(result,strlen(field));
  end else result:='';
end;

function ResNameProc({%H-}ModuleHandle : TFPResourceHMODULE; {%H-}ResourceType, ResourceName : PChar; {%H-}lParam : PtrInt) : LongBool; stdcall;
var
  aName:string;
begin
  if Assigned(resourcefiles) then
  begin
    if Is_IntResource(ResourceName)
       then aName:=InttoStr({%H-}PtrUInt(ResourceName))
       else aName:=GetStringFromBuffer(ResourceName);
    resourcefiles.Append(aName);
  end;
  Result:=true;
end;

function ResTypeProc(ModuleHandle : TFPResourceHMODULE; ResourceType : PChar; lParam : PtrInt) : LongBool; stdcall;
var
  aType:string;
  RT:integer;
begin
  if Is_IntResource(ResourceType) then RT:={%H-}PtrUInt(ResourceType) else
  begin
    aType:=GetStringFromBuffer(ResourceType);
    RT:=StrToIntDef(aType,0);
  end;
  // get only the plain files (resource type 10; RT_RCDATA)
  if RT=10 then EnumResourceNames(ModuleHandle,ResourceType,@ResNameProc,lParam);
  Result:=true;
end;

procedure DoEnumResources;
begin
  EnumResourceTypes(HINSTANCE,@ResTypeProc,0);
end;

{$ifdef mswindows}
function GetWin32Version(out Major,Minor,Build : Integer): Boolean;
var
  Info: TOSVersionInfo;
begin
Info.dwOSVersionInfoSize := SizeOf(Info);
if GetVersionEx(Info) then
begin
  with Info do
  begin
    Win32Platform:=dwPlatformId;
    Major:=dwMajorVersion;
    Minor:=dwMinorVersion;
    Build:=dwBuildNumber;
    result:=true
  end;
end
  else result:=false;
end;

function IsWindows64: boolean;
  {
  Detect if we are running on 64 bit Windows or 32 bit Windows,
  independently of bitness of this program.
  Original source:
  http://www.delphipraxis.net/118485-ermitteln-ob-32-bit-oder-64-bit-betriebssystem.html
  modified for FreePascal in German Lazarus forum:
  http://www.lazarusforum.de/viewtopic.php?f=55&t=5287
  }
{$ifdef WIN32} //Modified KpjComp for 64bit compile mode
type
  TIsWow64Process = function( // Type of IsWow64Process API fn
      Handle: Windows.THandle; var Res: Windows.BOOL): Windows.BOOL; stdcall;
var
  IsWow64Result: Windows.BOOL; // Result from IsWow64Process
  IsWow64Process: TIsWow64Process; // IsWow64Process fn reference
begin
  // Try to load required function from kernel32
  IsWow64Process := TIsWow64Process(Windows.GetProcAddress(
    Windows.GetModuleHandle('kernel32'), 'IsWow64Process'));
  if Assigned(IsWow64Process) then
  begin
    // Function is implemented: call it
    if not IsWow64Process(Windows.GetCurrentProcess, IsWow64Result) then
      raise SysUtils.Exception.Create('IsWindows64: bad process handle');
    // Return result of function
    Result := IsWow64Result;
  end
  else
    // Function not implemented: can't be running on Wow64
    Result := False;
{$else} //if were running 64bit code, OS must be 64bit :)
begin
  Result := True;
{$endif}
end;
{$endif}


function SafeExpandFileName (Const FileName : String): String;
begin
  if FileName='' then
    result:=''
  else
    result:=ExpandFileName(FileName);
end;

function SafeGetApplicationName: String;
var
  StartPath: String;
  {$ifdef Darwin}
  x:integer;
  {$endif}
begin
 {$ifdef LCL}
 StartPath:=Application.ExeName;
 {$else}
 StartPath:=Paramstr(0);
 {$endif}
 {$ifdef Darwin}
 // we need the .app itself !!
 x:=pos('/Contents/MacOS',StartPath);
 if x>0 then
 begin
   Delete(StartPath,x,MaxInt);
   (*
   x:=RPos('/',StartPath);
   if x>0 then
   begin
     Delete(StartPath,x+1,MaxInt);
   end;
   *)
 end;
 {$endif}
 if FileIsSymlink(StartPath) then
    StartPath:=GetPhysicalFilename(StartPath,pfeException);
 result:=StartPath;
end;

function SafeGetApplicationPath: String;
begin
  result:=ExtractFilePath(SafeGetApplicationName);

  (*
 //StartPath:=IncludeTrailingPathDelimiter(ProgramDirectory);
 StartPath:=Application.Location;
 {$ifdef Darwin}
 // do not store settings inside app iself ...
 // not necessary the right choice ... ;-)
 x:=pos('/Contents/MacOS',StartPath);
 if x>0 then
 begin
   Delete(StartPath,x,MaxInt);
   x:=RPos('/',StartPath);
   if x>0 then
   begin
     Delete(StartPath,x+1,MaxInt);
   end;
 end;
  {$endif}
 if FileIsSymlink(StartPath) then
    StartPath:=GetPhysicalFilename(StartPath,pfeException);
 result:=ExtractFilePath(StartPath);
 *)

 if DirectoryExists(result) then
    result:=GetPhysicalFilename(result,pfeException);
 result:=IncludeTrailingPathDelimiter(result);
end;

function SaveFileFromResource(filename,resourcename:string):boolean;
var
  fs:Tfilestream;
begin
  result:=false;

  try
    if FileExists(filename) then SysUtils.DeleteFile(filename);
    with TResourceStream.Create(hInstance, resourcename, RT_RCDATA) do
    try
      try
        fs:=Tfilestream.Create(filename,fmCreate);
        Savetostream(fs);
      finally
        fs.Free;
      end;
    finally
      Free;
    end;
    result:=FileExists(filename);
  except
    on E: Exception do
      infoln('File from resource creation error: '+E.Message,etError);
  end;
end;


function SaveInisFromResource(filename,resourcename:string):boolean;
var
  fs:Tfilestream;
  ms:TMemoryStream;
  BackupFileName:string;
  Ini:TMemIniFile;
  OldIniVersion,NewIniVersion:string;
begin
  result:=false;

  try
    if NOT FileExists(filename) then
    begin
      result:=SaveFileFromResource(filename,resourcename);
  end
  else
  begin

    // create memory stream of resource
    ms:=TMemoryStream.Create;
    try
      with TResourceStream.Create(hInstance, resourcename, RT_RCDATA) do
      try
        Savetostream(ms);
      finally
        Free;
     end;
     ms.Position:=0;

     Ini:=TMemIniFile.Create(ms);
     {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION > 30000)}
     Ini.Options:=[ifoStripQuotes];
     {$ELSE}
     ini.StripQuotes:=true;
     {$ENDIF}
     NewIniVersion:=Ini.ReadString('fpcupinfo','inifileversion','0.0.0.0');
     Ini.Free;

     Ini:=TMemIniFile.Create(filename);
     {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION > 30000)}
     Ini.Options:=[ifoStripQuotes];
     {$ELSE}
     ini.StripQuotes:=true;
     {$ENDIF}
     OldIniVersion:=Ini.ReadString('fpcupinfo','inifileversion','0.0.0.0');
     Ini.Free;

     if OldIniVersion<>NewIniVersion then
     begin
       BackupFileName:=ChangeFileExt(filename,'.bak');
       while FileExists(BackupFileName) do BackupFileName := BackupFileName + 'k';
         FileUtil.CopyFile(filename,BackupFileName);
         if SysUtils.DeleteFile(filename) then
         begin
           ms.Position:=0;
           fs := TFileStream.Create(filename,fmCreate);
           try
             fs.CopyFrom(ms, ms.Size);
           finally
             FreeAndNil(fs);
           end;
         end;
     end;

    finally
      ms.Free;
    end;

  end;

    result:=FileExists(filename);

  except
    on E: Exception do
      infoln('File creation error: '+E.Message,etError);
  end;

end;

{$IFDEF MSWINDOWS}
procedure CreateDesktopShortCut(Target, TargetArguments, ShortcutName: string);
var
  IObject: IUnknown;
  ISLink: IShellLink;
  IPFile: IPersistFile;
  PIDL: PItemIDList;
  InFolder: array[0..MAX_PATH] of Char;
  LinkName: WideString;
begin
  { Creates an instance of IShellLink }
  IObject := CreateComObject(CLSID_ShellLink);
  ISLink := IObject as IShellLink;
  IPFile := IObject as IPersistFile;

  ISLink.SetPath(pChar(Target));
  ISLink.SetArguments(pChar(TargetArguments));
  ISLink.SetWorkingDirectory(pChar(ExtractFilePath(Target)));

  { Get the desktop location }
  SHGetSpecialFolderLocation(0, CSIDL_DESKTOPDIRECTORY, PIDL);
  SHGetPathFromIDList(PIDL, InFolder);
  LinkName := IncludeTrailingPathDelimiter(InFolder) + ShortcutName+'.lnk';

  { Get rid of any existing shortcut first }
  SysUtils.DeleteFile(LinkName);

  { Create the link }
  IPFile.Save(PWChar(LinkName), false);
end;
{$ENDIF MSWINDOWS}

{$IFDEF UNIX}
{$IFNDEF DARWIN}
procedure CreateDesktopShortCut(Target, TargetArguments, ShortcutName: string);
var
  OperationSucceeded: boolean;
  ResultCode: boolean;
  XdgDesktopContent: TStringList;
  XdgDesktopFile: string;
begin
  // Fail by default:
  OperationSucceeded:=false;
  XdgDesktopFile:=IncludeTrailingPathDelimiter(GetTempDir(false))+'fpcup-'+shortcutname+'.desktop';
  XdgDesktopContent:=TStringList.Create;
  try
    XdgDesktopContent.Add('[Desktop Entry]');
    XdgDesktopContent.Add('Version=1.0');
    XdgDesktopContent.Add('Encoding=UTF-8');
    XdgDesktopContent.Add('Type=Application');
    XdgDesktopContent.Add('Icon='+ExtractFilePath(Target)+'images/icons/lazarus.ico');
    XdgDesktopContent.Add('Exec='+Target+' '+TargetArguments+' %f');
    XdgDesktopContent.Add('Name='+ShortcutName);
    XdgDesktopContent.Add('GenericName=Lazarus IDE with Free Pascal Compiler');
    XdgDesktopContent.Add('Category=Application;IDE;Development;GUIDesigner;');
    XdgDesktopContent.Add('Keywords=editor;Pascal;IDE;FreePascal;fpc;Design;Designer;');
    //XdgDesktopContent.Add('StartupWMClass=Lazarus');
    //XdgDesktopContent.Add('MimeType=text/x-pascal;');
    //XdgDesktopContent.Add('Patterns=*.pas;*.pp;*.p;*.inc;*.lpi;*.lpk;*.lpr;*.lfm;*.lrs;*.lpl;');
    // We're going to try and call xdg-desktop-icon
    // this may fail if shortcut exists already
    try
      XdgDesktopContent.SaveToFile(XdgDesktopFile);
      FpChmod(XdgDesktopFile, &711); //rwx--x--x
      OperationSucceeded:=(ExecuteCommand('xdg-desktop-icon install ' + XdgDesktopFile,false)=0);
    except
      OperationSucceeded:=false;
    end;

    if OperationSucceeded=false then
    begin
      infoln('CreateDesktopShortcut: xdg-desktop-icon failed to create shortcut to '+Target,etWarning);
      //infoln('CreateDesktopShortcut: going to create shortcut manually',etWarning);
      //FileUtil.CopyFile(XdgDesktopFile,'/usr/share/applications/'+ExtractFileName(XdgDesktopFile));
    end;
    // Temp file is no longer needed....
    try
      SysUtils.DeleteFile(XdgDesktopFile);
    finally
      // Swallow, let filesystem maintenance clear it up
    end;
  finally
    XdgDesktopContent.Free;
  end;
end;
{$ELSE DARWIN}
procedure CreateDesktopShortCut(Target, TargetArguments, ShortcutName: string);
begin
  // Create shortcut on Desktop and in Applications
  fpSystem(
    '/usr/bin/osascript << EOF'+#10+
    'tell application "Finder"'+#10+
      'set myLazApp to POSIX file "'+IncludeLeadingPathDelimiter(Target)+'.app" as alias'+#10+
      'try'+#10+
          'set myLazDeskShort to (path to desktop folder as string) & "'+ShortcutName+'" as alias'+#10+
          'on error'+#10+
             'make new alias to myLazApp at (path to desktop folder as text)'+#10+
             'set name of result to "'+ShortcutName+'"'+#10+
      'end try'+#10+
      'try'+#10+
          'set myLazAppShort to (path to applications folder as string) & "'+ShortcutName+'" as alias'+#10+
          'on error'+#10+
             'make new alias to myLazApp at (path to applications folder as text)'+#10+
             'set name of result to "'+ShortcutName+'"'+#10+
      'end try'+#10+

    'end tell'+#10+
    'EOF');
end;
{$ENDIF DARWIN}
{$ENDIF UNIX}

procedure CreateHomeStartLink(Target, TargetArguments,
  ShortcutName: string);
var
  ScriptText: TStringList;
  ScriptFile: string;
begin
  {$IFDEF MSWINDOWS}
  infoln('Todo: write me (CreateHomeStartLink)!', etDebug);
  {$ENDIF MSWINDOWS}
  {$IFDEF UNIX}
  //create dir if it doesn't exist
  ForceDirectories(ExtractFilePath(IncludeTrailingPathDelimiter(SafeExpandFileName('~'))+ShortcutName));
  ScriptText:=TStringList.Create;
  try
    // No quotes here, either, we're not in a shell, apparently...
    ScriptFile:=IncludeTrailingPathDelimiter(SafeExpandFileName('~'))+ShortcutName;
    SysUtils.DeleteFile(ScriptFile); //Get rid of any existing remnants
    ScriptText.Add('#!/bin/sh');
    ScriptText.Add('# '+BeginSnippet+' home startlink script');
    ScriptText.Add(Target+' '+TargetArguments);
    try
      ScriptText.SaveToFile(ScriptFile);
      FpChmod(ScriptFile, &755); //rwxr-xr-x
    except
      on E: Exception do
        infoln('CreateHomeStartLink: could not create link: '+E.Message,etWarning);
    end;
  finally
    ScriptText.Free;
  end;
  {$ENDIF UNIX}
end;

function GetFileNameFromURL(URL:string):string;
const
  URLMAGIC='/download';
var
  URI:TURI;
  aURL:string;
begin
  aURL:=URL;
  if AnsiEndsStr(URLMAGIC,URL) then SetLength(aURL,Length(URL)-Length(URLMAGIC));
  URI:=ParseURI(aURL);
  result:=URI.Document;
end;

function StripUrl(URL:string): string;
var
  URI:TURI;
begin
  URI:=ParseURI(URL);
  result:=URI.Host+URI.Path;
    end;

function GetCompilerVersion(CompilerPath: string): string;
var
  Output: string;
    begin
  Result:='0.0.0';
  if ((CompilerPath='') OR (NOT FileExists(CompilerPath))) then exit;
      try
    Output:='';
    // -iW does not work on older compilers : use -iV
    if (ExecuteCommand(CompilerPath+ ' -iV', Output, false)=0) then
    //-iVSPTPSOTO
    begin
      Output:=TrimRight(Output);
      if Length(Output)>0 then Result:=Output;
      end;
  except
  end;
end;

function GetLazbuildVersion(LazbuildPath: string): string;
var
  Output: string;
  OutputLines:TStringList;
begin
  Result:='0.0.0';
  if ((LazbuildPath='') OR (NOT FileExists(LazbuildPath))) then exit;
  try
    Output:='';
    // -iW does not work on older compilers : use -iV
    if (ExecuteCommand(LazbuildPath+ ' --version', Output, false)=0) then
    begin
      Output:=TrimRight(Output);
      if Length(Output)>0 then
      begin
        OutputLines:=TStringList.Create;
        try
          OutputLines.Text:=Output;
          if OutputLines.Count>0 then
          begin
            // lazbuild outputs version info as last line
            result:=OutputLines.Strings[OutputLines.Count-1];
          end;
        finally
          OutputLines.Free;
        end;
      end;
    end;
  except
  end;
end;

procedure GetVersionFromString(const VersionSnippet:string;var Major,Minor,Build: Integer);
var
  i,j:integer;
  found:boolean;
begin
  i:=1;

  // move towards first numerical
  while (Length(VersionSnippet)>=i) AND (NOT (VersionSnippet[i] in ['0'..'9'])) do Inc(i);
  // get major version
  j:=0;
  found:=false;
  while (Length(VersionSnippet)>=i) AND (VersionSnippet[i] in ['0'..'9']) do
  begin
    found:=true;
    j:=j*10+Ord(VersionSnippet[i])-$30;
    Inc(i);
  end;
  if found then Major:=j;

  // skip random symbols to move towards next digit
  //while (Length(VersionSnippet)>=i) AND (NOT (VersionSnippet[i] in ['0'..'9'])) do Inc(i);
  // skip a single random symbol to move towards next digit
  if (Length(VersionSnippet)>=i) then Inc(i);
  // get minor version
  j:=0;
  found:=false;
  while (Length(VersionSnippet)>=i) AND (VersionSnippet[i] in ['0'..'9']) do
  begin
    found:=true;
    j:=j*10+Ord(VersionSnippet[i])-$30;
    Inc(i);
  end;
  if found then Minor:=j;

  // skip random symbols to move towards next digit
  //while (Length(VersionSnippet)>=i) AND (NOT (VersionSnippet[i] in ['0'..'9'])) do Inc(i);
  // skip a single random symbol to move towards next digit
  if (Length(VersionSnippet)>=i) then Inc(i);
  // get build version
  j:=0;
  found:=false;
  while (Length(VersionSnippet)>=i) AND (VersionSnippet[i] in ['0'..'9']) do
  begin
    found:=true;
    j:=j*10+Ord(VersionSnippet[i])-$30;
    Inc(i);
  end;
  if found then Build:=j;
end;

function CalculateFullVersion(Major,Minor,Release:integer):dword;
begin
  result:=(Major *  100 + Minor) * 100 + Release;
end;

function GetNumericalVersion(VersionSnippet: string): word;
var
  Major,Minor,Build: Integer;
begin
  Major:=0;
  Minor:=0;
  Build:=0;
  GetVersionFromString(VersionSnippet,Major,Minor,Build);
  result:=CalculateFullVersion(Major,Minor,Build);
end;

function GetVersionFromUrl(URL:string): string;
var
  VersionSnippet:string;
  i:integer;
  VersionList : TStringList;
begin
  result:='0.0.0';

  if Pos('trunk',URL)>0 then result:='trunk' else
  if Pos('newpascal',URL)>0 then result:='trunk' else
  if Pos('freepascal.git',URL)>0 then result:='trunk' else
  if Pos('lazarus.git',URL)>0 then result:='trunk' else
  begin

    VersionSnippet := UpperCase(URL);
    i := Length(VersionSnippet);

    // remove trailing delimiter
    if (i>0) and CharInSet(VersionSnippet[i],['\','/']) then
    begin
      Dec(i);
      SetLength(VersionSnippet,i);
    end;

    // extract last part of URL, the part that should contain the version
    while (i > 0) and (not CharInSet(VersionSnippet[i],['\','/'])) do Dec(i);
    VersionSnippet := Copy(VersionSnippet, i + 1, MaxInt);

    // find first occurence of _ and delete everything before it
    // if url contains a version, this version always starts with first _
    i := Pos('_',VersionSnippet);
    if i>0 then
    begin
      Delete(VersionSnippet,1,i);
      // ignore release candidate numbering
      i := Pos('_RC',VersionSnippet);
      if i>0 then Delete(VersionSnippet,i,200);
      VersionSnippet:=StringReplace(VersionSnippet,'_',',',[rfReplaceAll]);
    end;

    if Length(VersionSnippet)>0 then
    begin
      VersionList := TStringList.Create;
      try
        VersionList.CommaText := VersionSnippet;
        if VersionList.Count>0 then
        begin
          result:=VersionList[0];
          if VersionList.Count>1 then result:=result+'.'+VersionList[1];
          if VersionList.Count>2 then result:=result+'.'+VersionList[2];
        end;
      finally
        VersionList.Free;
      end;
    end;
  end;
end;

function GetReleaseCandidateFromUrl(aURL:string): integer;
const
  RC_MAGIC='_RC';
var
  VersionSnippet:string;
  i:integer;
begin
  result:=-1;

  VersionSnippet := UpperCase(aURL);
  i := Length(VersionSnippet);

  // remove trailing delimiter
  if (i>0) and CharInSet(VersionSnippet[i],['\','/']) then
  begin
    Dec(i);
    SetLength(VersionSnippet,i);
  end;

  // find last occurence of _RC
  // if url contains a RC, this always starts with _RC
  i := RPos(RC_MAGIC,VersionSnippet);
  if i>0 then
  begin
    Delete(VersionSnippet,1,i+Length(RC_MAGIC)-1);
    result:=StrToIntDef(VersionSnippet,-1);
  end;
end;


{$IFDEF MSWINDOWS}
procedure DeleteDesktopShortcut(ShortcutName: string);
var
  PIDL: PItemIDList;
  InFolder: array[0..MAX_PATH] of Char;
  LinkName: WideString;
begin
  { Get the desktop location }
  SHGetSpecialFolderLocation(0, CSIDL_DESKTOPDIRECTORY, PIDL);
  SHGetPathFromIDList(PIDL, InFolder);
  LinkName := IncludeTrailingPathDelimiter(InFolder) + ShortcutName+'.lnk';
  SysUtils.DeleteFile(LinkName);
end;
{$ENDIF MSWINDOWS}

function DirCopy(SourcePath, DestPath: String): Boolean;
begin
  result:=FileUtil.CopyDirTree(SourcePath, DestPath,[cffOverwriteFile,cffCreateDestDirectory]);
end;

function DeleteDirectoryEx(DirectoryName: string): boolean;
// Lazarus fileutil.DeleteDirectory on steroids, works like
// deltree <directory>, rmdir /s /q <directory> or rm -rf <directory>
// - removes read-only files/directories (DeleteDirectory doesn't)
// - removes directory itself
// Adapted from fileutil.DeleteDirectory, thanks to Paweł Dmitruk
var
  FileInfo: TRawByteSearchRec;
  CurSrcDir: String;
  CurFilename: String;
begin
  Result:=false;
  CurSrcDir:=CleanAndExpandDirectory(DirectoryName);
  if SysUtils.FindFirst(CurSrcDir+GetAllFilesMask,faAnyFile{$ifdef unix} or faSymLink {$endif unix},FileInfo)=0 then
  begin
    repeat
      // Ignore directories and files without name:
      if (FileInfo.Name<>'.') and (FileInfo.Name<>'..') and (FileInfo.Name<>'') then
      begin
        // Look at all files and directories in this directory:
        CurFilename:=CurSrcDir+FileInfo.Name;
        // Remove read-only file attribute so we can delete it:
        if (FileInfo.Attr and faReadOnly)>0 then
          FileSetAttr(CurFilename, FileInfo.Attr-faReadOnly);
        if ((FileInfo.Attr and faDirectory)>0) {$ifdef unix} and ((FileInfo.Attr and faSymLink)=0) {$endif unix} then
        begin
          // Directory; exit with failure on error
          if not DeleteDirectoryEx(CurFilename) then
            begin
            SysUtils.FindClose(FileInfo);
            exit;
            end;
        end
        else
        begin
          // File; exit with failure on error
          if not SysUtils.DeleteFile(CurFilename) then
            begin
            SysUtils.FindClose(FileInfo);
            exit;
            end;
        end;
      end;
    until SysUtils.FindNext(FileInfo)<>0;
  end;
  SysUtils.FindClose(FileInfo);
  // Remove root directory; exit with failure on error:
  if (not RemoveDir(DirectoryName)) then exit;
  Result:=true;
end;

function DeleteFilesSubDirs(const DirectoryName: string;
  const Names: TStringList; const OnlyIfPathHas: string): boolean;
// Deletes all named files starting from DirectoryName and recursing down.
// If the Names are empty, all files will be deleted
// It only deletes files if any directory of the path contains OnlyIfPathHas,
// unless that is empty
// Will try to remove read-only files.
//todo: check how this works with case insensitive file system like Windows
var
  AllFiles: boolean;
  CurSrcDir: String;
  CurFilename: String;
  FileInfo: TRawByteSearchRec;
begin
  Result:=false;
  AllFiles:=(Names.Count=0);
  CurSrcDir:=CleanAndExpandDirectory(DirectoryName);
  if SysUtils.FindFirst(CurSrcDir+GetAllFilesMask,faAnyFile{$ifdef unix} or faSymLink {$endif unix},FileInfo)=0 then
  begin
    repeat
      // Ignore directories and files without name:
      if (FileInfo.Name<>'.') and (FileInfo.Name<>'..') and (FileInfo.Name<>'') then
      begin
        // Look at all files and directories in this directory:
        CurFilename:=CurSrcDir+FileInfo.Name;
        if ((FileInfo.Attr and faDirectory)>0) {$ifdef unix} and ((FileInfo.Attr and faSymLink)=0) {$endif unix} then
        begin
          // Directory; call recursively exit with failure on error
          if not DeleteFilesSubDirs(CurFilename,Names,OnlyIfPathHas) then
          begin
            SysUtils.FindClose(FileInfo);
            exit;
          end;
        end
        else
        begin
          // If we are in the right path:
          //todo: get utf8 replacement for ExtractFilePath
          if (OnlyIfPathHas='') or
            (pos(DirectorySeparator+OnlyIfPathHas+DirectorySeparator,ExtractFilePath(CurFileName))>0) then
          begin
            // Only delete if file name is right
            //todo: get utf8 extractfilename
            if AllFiles or (Names.IndexOf(ExtractFileName(FileInfo.Name))>=0) then
            begin
              // Remove read-only file attribute so we can delete it:
              if (FileInfo.Attr and faReadOnly)>0 then
                FileSetAttr(CurFilename, FileInfo.Attr-faReadOnly);
              if not SysUtils.DeleteFile(CurFilename) then
              begin
                SysUtils.FindClose(FileInfo);
                exit;
              end;
            end;
          end;
        end;
      end;
    until SysUtils.FindNext(FileInfo)<>0;
  end;
  SysUtils.FindClose(FileInfo);
  Result:=true;
end;

function DeleteFilesExtensionsSubdirs(const DirectoryName: string; const Extensions:TstringList; const OnlyIfPathHas: string): boolean;
// Deletes all files ending in one of the extensions, starting from
// DirectoryName and recursing down.
// It only deletes files if any directory of the path contains OnlyIfPathHas,
// unless that is empty
// Extensions can contain * to cover everything (other extensions will then be
// ignored), making it delete all files, but leaving the directories.
// Will try to remove read-only files.
//todo: check how this works with case insensitive file system like Windows
var
  AllFiles: boolean;
  CurSrcDir: String;
  CurFilename: String;
  FileInfo: TRawByteSearchRec;
  i: integer;
begin
  Result:=false;
  // Make sure we can compare extensions using ExtractFileExt
  for i:=0 to Extensions.Count-1 do
  begin
    if copy(Extensions[i],1,1)<>'.' then Extensions[i]:='.'+Extensions[i];
  end;
  AllFiles:=(Extensions.Count=0) or (Extensions.IndexOf('.*')>=0);
  CurSrcDir:=CleanAndExpandDirectory(DirectoryName);
  if SysUtils.FindFirst(CurSrcDir+GetAllFilesMask,faAnyFile{$ifdef unix} or faSymLink {$endif unix},FileInfo)=0 then
  begin
    repeat
      // Ignore directories and files without name:
      if (FileInfo.Name<>'.') and (FileInfo.Name<>'..') and (FileInfo.Name<>'') then
      begin
        // Look at all files and directories in this directory:
        CurFilename:=CurSrcDir+FileInfo.Name;
        if ((FileInfo.Attr and faDirectory)>0) {$ifdef unix} and ((FileInfo.Attr and faSymLink)=0) {$endif unix} then
        begin
          // Directory; call recursively exit with failure on error
          if not DeleteFilesExtensionsSubdirs(CurFilename, Extensions,OnlyIfPathHas) then
          begin
            SysUtils.FindClose(FileInfo);
            exit;
          end;
        end
        else
        begin
          // If we are in the right path:
          //todo: get utf8 replacement for ExtractFilePath
          if (OnlyIfPathHas='') or
            (pos(DirectorySeparator+OnlyIfPathHas+DirectorySeparator,ExtractFilePath(CurFileName))>0) then
          begin
            // Only delete if extension is right
            if AllFiles or (Extensions.IndexOf(ExtractFileExt(FileInfo.Name))>=0) then
            begin
              // Remove read-only file attribute so we can delete it:
              if (FileInfo.Attr and faReadOnly)>0 then
                FileSetAttr(CurFilename, FileInfo.Attr-faReadOnly);
              if not SysUtils.DeleteFile(CurFilename) then
              begin
                SysUtils.FindClose(FileInfo);
                exit;
              end;
            end;
          end;
        end;
      end;
    until SysUtils.FindNext(FileInfo)<>0;
  end;
  SysUtils.FindClose(FileInfo);
  Result:=true;
end;

function DeleteFilesNameSubdirs(const DirectoryName: string; const OnlyIfNameHas: string): boolean;
// Deletes all files containing OnlyIfNameHas
// DirectoryName and recursing down.
// Will try to remove read-only files.
//todo: check how this works with case insensitive file system like Windows
var
  AllFiles: boolean;
  CurSrcDir: String;
  CurFilename: String;
  FileInfo: TRawByteSearchRec;
  i: integer;
begin
  Result:=false;
  AllFiles:=(Length(OnlyIfNameHas)=0);

  // for now, exit when no filename data is given ... use DeleteDirectoryEx
  if AllFiles then exit;

  CurSrcDir:=CleanAndExpandDirectory(DirectoryName);
  if SysUtils.FindFirst(CurSrcDir+GetAllFilesMask,faAnyFile{$ifdef unix} or faSymLink {$endif unix},FileInfo)=0 then
  begin
    repeat
      // Ignore directories and files without name:
      if (FileInfo.Name<>'.') and (FileInfo.Name<>'..') and (FileInfo.Name<>'') then
      begin
        // Look at all files and directories in this directory:
        CurFilename:=CurSrcDir+FileInfo.Name;
        if ((FileInfo.Attr and faDirectory)>0) {$ifdef unix} and ((FileInfo.Attr and faSymLink)=0) {$endif unix} then
        begin
          // Directory; call recursively exit with failure on error
          if not DeleteFilesNameSubdirs(CurFilename, OnlyIfNameHas) then
          begin
            SysUtils.FindClose(FileInfo);
            exit;
          end;
        end
        else
        begin
          if AllFiles or (Pos(UpperCase(OnlyIfNameHas),UpperCase(FileInfo.Name))>0) then
          begin
            // Remove read-only file attribute so we can delete it:
            if (FileInfo.Attr and faReadOnly)>0 then
              FileSetAttr(CurFilename, FileInfo.Attr-faReadOnly);
            if not SysUtils.DeleteFile(CurFilename) then
            begin
              SysUtils.FindClose(FileInfo);
              exit;
            end;
          end;
        end;
      end;
    until SysUtils.FindNext(FileInfo)<>0;
  end;
  SysUtils.FindClose(FileInfo);
  Result:=true;
end;

function DownloadBase(aDownLoader:TBasicDownloader;URL, TargetFile: string; HTTPProxyHost: string=''; HTTPProxyPort: integer=0; HTTPProxyUser: string=''; HTTPProxyPassword: string=''): boolean;
begin
  result:=false;
  if Length(HTTPProxyHost)>0 then aDownLoader.setProxy(HTTPProxyHost,HTTPProxyPort,HTTPProxyUser,HTTPProxyPassword);
  result:=aDownLoader.getFile(URL,TargetFile);
  if (NOT result) then
  begin
    infoln('Error while trying to download '+URL+'. Trying again.',etDebug);
    SysUtils.DeleteFile(TargetFile); // delete stale targetfile
  end;
end;


function Download(UseWget:boolean; URL, TargetFile: string; HTTPProxyHost: string=''; HTTPProxyPort: integer=0; HTTPProxyUser: string=''; HTTPProxyPassword: string=''): boolean;
var
  aDownLoader:TBasicDownLoader;
begin
  result:=false;
  if UseWget
     then aDownLoader:=TWGetDownLoader.Create
     else aDownLoader:=TNativeDownLoader.Create;
  try
    result:=DownloadBase(aDownLoader,URL,TargetFile,HTTPProxyHost,HTTPProxyPort,HTTPProxyUser,HTTPProxyPassword);
  finally
    aDownLoader.Destroy;
  end;

  {$ifdef Windows}
  //Second resort: use Windows PowerShell
  if (NOT result) then
  begin
    SysUtils.Deletefile(TargetFile);
    result:=DownloadByPowerShell(URL,TargetFile);
  end;
  {$endif}

  //Final resort: use wget by force
  if (NOT result) AND (NOT UseWget) then
  begin
    SysUtils.Deletefile(TargetFile);
    aDownLoader:=TWGetDownLoader.Create;
    try
      result:=DownloadBase(aDownLoader,URL,TargetFile,HTTPProxyHost,HTTPProxyPort,HTTPProxyUser,HTTPProxyPassword);
    finally
      aDownLoader.Destroy;
    end;
end;

  if (NOT result) then SysUtils.Deletefile(TargetFile);
end;

function GetGitHubFileList(aURL:string;fileurllist:TStringList; HTTPProxyHost: string=''; HTTPProxyPort: integer=0; HTTPProxyUser: string=''; HTTPProxyPassword: string=''):boolean;
var
  {$ifdef Darwin}
  Http:TNSHTTPSendAndReceive;
  Ms: TMemoryStream;
  {$else}
  Http: TFPHTTPClient;
  {$endif}
  JSONFile:string;
  JSONFileList:TStringList;
  Content : string;
  Json : TJSONData;
  JsonObject : TJSONObject;
  JsonArray: TJSONArray;
  i:integer;
begin
  result:=false;
  Content:='';

  {$ifdef Darwin}
  // GitHub needs TLS 1.2 .... native FPC client does not support this (through OpenSSL)
  // So, use client by Phil, a Lazarus forum member
  // See: https://macpgmr.github.io/
  Http:=TNSHTTPSendAndReceive.Create;
  try
    Http.Address := aURL;
    Http.AddHeader('Content-Type', 'application/json');
    if Length(HTTPProxyHost)>0 then
    begin
      with Http do
      begin
        Proxy.Host:=HTTPProxyHost;
        Proxy.Port:=HTTPProxyPort;
        Proxy.UserName:=HTTPProxyUser;
        Proxy.Password:=HTTPProxyPassword;
      end;
    end;
    Ms := TMemoryStream.Create;
    try
      if Http.SendAndReceive(nil, Ms) then
      begin
        SetLength(Content, Ms.Size);
        if Ms.Size > 0 then
        begin
            Ms.Read(Content[1], Ms.Size);
          result:=true;
        end;
      end;
    finally
      Ms.Free;
    end;
  finally
    Http.Free;
  end;
  {$else}

  if (NOT result) then
  begin
    JSONFile := GetTempFileNameExt('','FPCUPTMP','tmp');

    result:=Download(
          False,
          aURL,
          JSONFile,
          HTTPProxyUser,
          HTTPProxyPort,
          HTTPProxyUser,
          HTTPProxyPassword);
    if result then
    begin
      JSONFileList:=TStringList.Create;
      try
        JSONFileList.LoadFromFile(JSONFile);
        Content:=JSONFileList.Text;
      finally
        JSONFileList.Free;
      end;
    end;
    SysUtils.Deletefile(JSONFile); //Get rid of temp file.
  end;

  if (NOT result) then
  begin
  Http:=TFPHTTPClient.Create(Nil);
  try
     Http.AddHeader('User-Agent',USERAGENT);
     Http.AddHeader('Content-Type', 'application/json');
     Http.IOTimeout:=5000;
     Http.AllowRedirect:=true;

    if Length(HTTPProxyHost)>0 then
    begin
      with Http do
      begin
        {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION > 30000)}
        Proxy.Host:=HTTPProxyHost;
        Proxy.Port:=HTTPProxyPort;
        Proxy.UserName:=HTTPProxyUser;
        Proxy.Password:=HTTPProxyPassword;
        {$endif}
      end;
    end;

     Content:=Http.Get(aURL);
  finally
    Http.Free;
  end;
  end;
  {$endif}

  if (Length(Content)=0) OR (NOT result) then exit;
  Json:=GetJSON(Content);
  try
    if Json=Nil then exit;
    JsonArray:=Json.FindPath('assets') as TJSONArray;
    i:=JsonArray.Count;
    while (i>0) do
    begin
      Dec(i);
      JsonObject := JsonArray.Objects[i];
      fileurllist.Add(JsonObject.Get('browser_download_url'));
    end;
  finally
    Json.Free;
  end;
end;

// returns file size in bytes or 0 if not found.
function FileSize(FileName: string) : Int64;
var
  sr : TRawByteSearchRec;
begin
{$ifdef unix}
  result:=filesize(FileName);
{$else}
  if SysUtils.FindFirst(FileName, faAnyFile, sr ) = 0 then
     result := Int64(sr.FindData.nFileSizeHigh) shl Int64(32) + Int64(sr.FindData.nFileSizeLow)
  else
     result := 0;
  SysUtils.FindClose(sr);
{$endif}
end;

function ParentDirectoryIsNotRoot(Dir: string): boolean;
var s:string;
begin
  result:=false;
  Dir:=ExcludeTrailingBackslash(Dir);
  s:=ExtractFileDir(Dir);
  if s<>Dir then //to avoid fe. c:\\\
    begin  // this is one level up
    Dir:=ExcludeTrailingBackslash(s);
    s:=ExtractFileDir(Dir);
    result:=s<>Dir; //to avoid fe. c:\\\
    end;
end;

{$IFDEF MSWINDOWS}
function CheckFileSignature(aFilePath: string): boolean;
var
  s:TFileStream;
  magic:word;
  offset:integer;
begin
  result:=true;
  if NOT FileExists(aFilePath) then exit;
  try
  s:=TFileStream.Create(aFilePath,fmOpenRead);
  try
    s.Position:=0;
    magic:=s.ReadWord;
    if magic<>$5A4D then exit;
    s.Seek(60,soBeginning);
    offset:=0;
    s.ReadBuffer(offset,4);
    s.Seek(offset,soBeginning);
    magic:=s.ReadWord;
    if magic<>$4550 then exit;
    s.Seek(offset+4,soBeginning);
    magic:=s.ReadWord;
  finally
    s.Free;
  end;
  {$ifdef win32}
  result:=(magic=$014C);
  {$endif}
  {$ifdef win64}
  result:=((magic=$0200) OR (magic=$8664));
  {$endif}
  except
    result:=true;
  end;
end;

function DownloadByPowerShell(URL, TargetFile: string): boolean;
const
  URLMAGIC='/download';
var
  Output : String;
  URI    : TURI;
  aURL,P : String;
begin
  aURL:=URL;
  if AnsiEndsStr(URLMAGIC,URL) then SetLength(aURL,Length(URL)-Length(URLMAGIC));
  URI:=ParseURI(aURL);
  P:=URI.Protocol;
  infoln('PowerShell downloader: Getting ' + URI.Document + ' from '+P+'://'+URI.Host+URI.Path,etDebug);
  result:=(ExecuteCommand('powershell -command "(new-object System.Net.WebClient).DownloadFile('''+URL+''','''+TargetFile+''')"', Output, False)=0);
  if result then
  begin
    result:=FileExists(TargetFile);
  end;
end;

function GetLocalAppDataPath: string;
var
  AppDataPath: array[0..MaxPathLen] of char; //Allocate memory
begin
  AppDataPath := '';
  SHGetSpecialFolderPath(0, AppDataPath, CSIDL_LOCAL_APPDATA, False);
  result:=AppDataPath;
end;
{$ENDIF MSWINDOWS}

procedure infoln(Message: string; const Level: TEventType=etInfo);
begin
{$IFNDEF NOCONSOLE}
  // Note: these strings should remain as is so any fpcupgui highlighter can pick it up
  if (Level<>etDebug) then
    begin
      if AnsiPos(LineEnding, Message)>0 then writeln(''); //Write an empty line before multiline messagse
      writeln(BeginSnippet+' '+Seriousness[Level]+' '+ Message); //we misuse this for info output
      //sleep(200); //hopefully allow output to be written without interfering with other output
      sleep(1);
    end
  else
    begin
    {$IFDEF DEBUG}
    {DEBUG conditional symbol is defined using
    Project Options/Other/Custom Options using -dDEBUG}
    if AnsiPos(LineEnding, Message)>0 then writeln(''); //Write an empty line before multiline messagse
    writeln(BeginSnippet+' '+Seriousness[Level]+' '+ Message); //we misuse this for info output
    //sleep(200); //hopefully allow output to be written without interfering with other output
    sleep(1);
    {$ENDIF}
    end;
{$ENDIF NOCONSOLE}
end;

Function GetTempFileNameExt(Const Dir,Prefix,Ext : String) : String;
Var
  I : Integer;
  Start,Extension : String;
begin
  if (Dir='') then
    Start:=GetTempDir
  else
    Start:=IncludeTrailingPathDelimiter(Dir);
  if (Prefix='') then
    Start:=Start+'TMP'
  else
    Start:=Start+Prefix;
  if (Ext='') then
    Extension:='tmp'
  else
    Extension:=Ext;
  i:=0;
  repeat
    Result:=Format('%s%.5d.'+Extension,[Start,i]);
    Inc(i);
  until not FileExists(Result);
end;


Function GetTempDirName(Const Dir,Prefix : String) : String;
Var
  I : Integer;
  Start,Extension : String;
begin
  if (Dir='') then
    Start:=GetTempDir
  else
    Start:=IncludeTrailingPathDelimiter(Dir);
  if (Prefix='') then
    Start:=Start+'TMP'
  else
    Start:=Start+Prefix;
  i:=0;
  repeat
    Result:=Format('%s%.5d',[Start,i]);
    Inc(i);
  until not DirectoryExists(Result);
end;


function MoveFile(const SrcFilename, DestFilename: string): boolean;
// We might (in theory) be moving files across partitions so we cannot use renamefile
begin
  try
    if FileExists(SrcFileName) then
    begin
      if FileUtil.CopyFile(SrcFilename, DestFileName) then SysUtils.DeleteFile(SrcFileName);
      result:=true;
    end
    else
    begin
      //Source file does not exist, so cannot move
      result:=false;
    end;
  except
    result:=false;
  end;
end;

function FileCorrectLineEndings(const SrcFilename, DestFilename: string): boolean;
var
  FileSL:TStringList;
begin
  result:=false;
  try
    if FileExists(SrcFileName) then
    begin
      FileSL:=TStringList.Create;
      try
        FileSL.LoadFromFile(SrcFileName);
        SysUtils.DeleteFile(DestFilename);
        FileSL.SaveToFile(DestFilename);
        result:=true;
      finally
        FileSL.Free;
      end;
    end;
  except
  end;
end;

function FixPath(const s:string):string;
var
  i : longint;
begin
  { Fix separator }
  result:=s;
  for i:=1 to length(s) do
   if s[i] in ['/','\'] then
    result[i]:=DirectorySeparator;
end;

function FileIsReadOnly(const s:string):boolean;
begin
  result:=((FileGetAttr(s) AND faReadOnly) > 0);
end;

function MaybeQuoted(const s:string):string;
const
  FORBIDDEN_CHARS_DOS = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
                     '{', '}', '''', '`', '~'];
  FORBIDDEN_CHARS_OTHER = ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')',
                     '{', '}', '''', ':', '\', '`', '~'];
var
  forbidden_chars: set of char;
  i  : integer;
  quote_char: ansichar;
  quoted : boolean;
begin
  {$ifdef Windows}
  forbidden_chars:=FORBIDDEN_CHARS_DOS;
  quote_char:='"';
  {$else}
  forbidden_chars:=FORBIDDEN_CHARS_OTHER;
  include(forbidden_chars,'"');
  quote_char:='''';
  {$endif}

  quoted:=false;
  result:=quote_char;
  for i:=1 to length(s) do
   begin
     if s[i]=quote_char then
       begin
         quoted:=true;
         result:=result+'\'+quote_char;
       end
     else case s[i] of
       '\':
         begin
           {$ifdef UNIX}
           result:=result+'\\';
           quoted:=true;
           {$else}
           result:=result+'\';
           {$endif}
         end;
       ' ',
       #128..#255 :
         begin
           quoted:=true;
           result:=result+s[i];
         end;
       else begin
         if s[i] in forbidden_chars then
           quoted:=True;
         result:=result+s[i];
       end;
     end;
   end;
  if quoted then
    result:=result+quote_char
  else
    result:=s;
end;



function StringListStartsWith(SearchIn:TStringList; SearchFor:string; StartIndex:integer; CS:boolean): integer;
var
  Found:boolean=false;
  i:integer;
begin
  for i:=StartIndex to SearchIn.Count-1 do
  begin
    if CS then
    begin
      if copy(Trim(SearchIn[i]),1,length(SearchFor))=SearchFor then
      begin
        Found:=true;
        break;
      end;
    end
    else
    begin
      if UpperCase(copy(Trim(SearchIn[i]),1,length(SearchFor)))=UpperCase(SearchFor) then
      begin
        Found:=true;
        break;
      end;
    end;
  end;
  if Found then
    result:=i
  else
    result:=-1;
end;

{$IFDEF UNIX}
function GetGCCDirectory:string;
var
  output,s1,s2:string;
  i,j:integer;
  ReturnCode: integer;
begin

  {$IF (defined(BSD)) and (not defined(Darwin))}
  result:='/usr/local/lib/gcc/';
  {$else}
  result:='/usr/lib/gcc/';
  {$endif}
  output:='';

  try
    ReturnCode:=ExecuteCommand('gcc -v', Output, false);

    if (ReturnCode=0) then
    begin
    s1:=' --libdir=';
    i:=Ansipos(s1, Output);
    if i > 0 then
    begin
      s2:=RightStr(Output,Length(Output)-(i+Length(s1)-1));
      // find space as delimiter
      i:=Ansipos(' ', s2);
      // find lf as delimiter
      j:=Ansipos(#10, s2);
      if (j>0) AND (j<i) then i:=j;
      // find cr as delimiter
      j:=Ansipos(#13, s2);
      if (j>0) AND (j<i) then i:=j;
      if i > 0 then delete(s2,i,MaxInt);
      result:=IncludeTrailingPathDelimiter(s2);
    end;

    i:=Ansipos('gcc', result);
    if i=0 then result:=result+'gcc'+DirectorySeparator;

    s1:=' --build=';
    i:=Ansipos(s1, Output);
    if i > 0 then
    begin
      s2:=RightStr(Output,Length(Output)-(i+Length(s1)-1));
      // find space as delimiter
      i:=Ansipos(' ', s2);
      // find lf as delimiter
      j:=Ansipos(#10, s2);
      if (j>0) AND (j<i) then i:=j;
      // find cr as delimiter
      j:=Ansipos(#13, s2);
      if (j>0) AND (j<i) then i:=j;
      if i > 0 then delete(s2,i,MaxInt);
      result:=result+s2+DirectorySeparator;
    end;
    s1:='gcc version ';
    i:=Ansipos(s1, Output);
    if i > 0 then
    begin
      s2:=RightStr(Output,Length(Output)-(i+Length(s1)-1));
      // find space as delimiter
      i:=Ansipos(' ', s2);
      // find lf as delimiter
      j:=Ansipos(#10, s2);
      if (j>0) AND (j<i) then i:=j;
      // find cr as delimiter
      j:=Ansipos(#13, s2);
      if (j>0) AND (j<i) then i:=j;
      if i > 0 then delete(s2,i,MaxInt);
      result:=result+s2;
    end;
    end;

  except
    // ignore errors
  end;

  if ReturnCode<>0 then
  begin
    output:=result+'/'+GetTargetCPUOS+'-gnu/7';
    if DirectoryExists(output) then result:=output else
    begin
      output:=result+'/'+GetTargetCPUOS+'-gnu/6';
      if DirectoryExists(output) then result:=output else
      begin
        output:=result+'/'+GetTargetCPUOS+'-gnu/5';
        if DirectoryExists(output) then result:=output else
        begin
          output:=result+'/'+GetTargetCPUOS+'-gnu/4';
          if DirectoryExists(output) then result:=output;
        end;
      end;
    end;
  end;

end;
{$ENDIF UNIX}

{$ifdef Darwin}
function GetSDKVersion(aSDK: string):string;
const
  SearchTarget='SDKVersion: ';
var
  Output,s:string;
  i,j:integer;
begin
  Output:='';
  s:='';
  j:=0;
  //if ExecuteCommand('xcodebuild -version -sdk '+aSDK, Output, False) <> 0 then
  ExecuteCommand('xcodebuild -version -sdk '+aSDK, Output, False);
  begin
    i:=Pos(SearchTarget,Output);
    if i>0 then
    begin
      i:=i+length(SearchTarget);
      while (Length(Output)>i) AND (Output[i] in ['0'..'9','.']) do
      begin
        s:=s+Output[i];
        Inc(i);
      end;
    end
    else
    begin
      //xcodebuild not working ... try something completely different ...
      if aSDK='macosx' then
      begin
        ExecuteCommand('sw_vers -productVersion', Output, False);
        if (Length(Output)>0) then
        begin
          i:=1;
          while (Length(Output)>i) AND (Output[i] in ['0'..'9','.']) do
          begin
            s:=s+Output[i];
            Inc(i);
          end;
    end;
  end;
end;
  end;
  result:=s;
end;
{$endif}

// 1on1 copy from unit cutils from the fpc compiler;
function CompareVersionStrings(s1,s2: string): longint;
var
  start1, start2,
  i1, i2,
  num1,num2,
  res,
  err: longint;
begin
  i1:=1;
  i2:=1;
  repeat
    start1:=i1;
    start2:=i2;
    while (i1<=length(s1)) and
          (s1[i1] in ['0'..'9']) do
       inc(i1);
    while (i2<=length(s2)) and
          (s2[i2] in ['0'..'9']) do
       inc(i2);
    { one of the strings misses digits -> other is the largest version }
    if i1=start1 then
      if i2=start2 then
        exit(0)
      else
        exit(-1)
    else if i2=start2 then
      exit(1);
    { get version number part }
    val(copy(s1,start1,i1-start1),num1,err);
    val(copy(s2,start2,i2-start2),num2,err);
    { different -> done }
    res:=num1-num2;
    if res<>0 then
      exit(res);
    { if one of the two is at the end while the other isn't, add a '.0' }
    if (i1>length(s1)) and
       (i2<=length(s2)) then
      s1:=s1+'.0'
    else if i2>length(s2) then
      s2:=s2+'.0';
    { compare non-numerical characters normally }
    while (i1<=length(s1)) and
          not(s1[i1] in ['0'..'9']) and
          (i2<=length(s2)) and
          not(s2[i2] in ['0'..'9']) do
      begin
        res:=ord(s1[i1])-ord(s2[i2]);
        if res<>0 then
          exit(res);
        inc(i1);
        inc(i2);
      end;
    { both should be digits again now, otherwise pick the one with the
      digits as the largest (it more likely means that the input was
      ill-formatted though) }
    if (i1<=length(s1)) and
       not(s1[i1] in ['0'..'9']) then
      exit(-1);
    if (i2<=length(s2)) and
       not(s2[i2] in ['0'..'9']) then
      exit(1);
  until false;
end;

function ExistWordInString(aString:pchar; aSearchString:string; aSearchOptions: TStringSearchOptions): Boolean;
var
  Size : Integer;
begin
  Size:=StrLen(aString);
  Result := SearchBuf(aString, Size, 0, 0, aSearchString, aSearchOptions)<>nil;
end;

function GetEnumNameSimple(aTypeInfo:PTypeInfo;const aEnum:integer):string;
begin
  begin
    if (aTypeInfo=nil) or (aTypeInfo^.Kind<>tkEnumeration) then
      result := '' else
      result := GetEnumName(aTypeInfo,aEnum);
  end;
end;

function Which(Executable: string): string;
var
  Output: string;
begin
  result:=FindDefaultExecutablePath(Executable);
  if (NOT FileIsExecutable(result)) then result:='';

  (*
  {$IFDEF UNIX}
  // Note: we're using external which because
  // FindDefaultExecutablePath
  // or
  // ExeSearch(Executable);
  // doesn't check if the user has execute permission
  // on the found file.
  // however
  // ExeSearch(Executable) ... if fpAccess (Executable,X_OK)=0 then ..... see http://www.freepascal.org/docs-html/rtl/baseunix/fpaccess.html
  ExecuteCommand('which '+Executable,Output,false);
  // Remove trailing LF(s) and other control codes:
  while (length(output)>0) and (ord(output[length(output)])<$20) do
    delete(output,length(output),1);
  {$ELSE}
  Output:=FindDefaultExecutablePath(Executable);
  {$ENDIF UNIX}
  // We could have checked for ExecuteCommandHidden exitcode, but why not
  // do file existence check instead:
  if (Output<>'') and fileexists(Output) then
  begin
    result:=Output;
  end
  else
  begin
    result:=''; //command failed
  end;
  *)
end;

function IsExecutable(Executable: string):boolean;
var
  aPath:string;
begin
  result:=false;
  //aPath:=FindDefaultExecutablePath(Executable);
  aPath:=Executable;
  if NOT FileExists(aPath) then exit;
  {$ifdef Windows}
  //if ExtractFileExt(aPath)='' then aPath:=aPath+'.exe';
  {$endif}
  if ExtractFileExt(aPath)=GetExeExt then
  begin
    {$ifdef Windows}
    result:=true;
    {$else}
    result:=(fpAccess(aPath,X_OK)=0);
    {$endif}
  end;
end;


{$IFDEF UNIX}
//Adapted from sysutils; Unix/Linux only
Function XdgConfigHome: String;
{ Follows base-dir spec,
  see [http://freedesktop.org/Standards/basedir-spec].
  Always ends with PathDelim. }
begin
  Result:=GetEnvironmentVariable('XDG_CONFIG_HOME');
  if (Result='') then
    Result:=IncludeTrailingPathDelimiter(SafeExpandFileName('~'))+'.config'+DirectorySeparator
  else
    Result:=IncludeTrailingPathDelimiter(Result);
end;
{$ENDIF UNIX}

function CheckExecutable(Executable, Parameters, ExpectOutput: string; Level: TEventType): boolean;
var
  ResultCode: longint;
  OperationSucceeded: boolean;
  ExeName: string;
  Output: string;
begin
  try
    Output:='';
    ExeName := ExtractFileName(Executable);
    {$IFDEF DEBUG}
    ResultCode := ExecuteCommand(Executable + ' ' + Parameters, Output, True);
    {$ELSE}
    ResultCode := ExecuteCommand(Executable + ' ' + Parameters, Output, False);
    {$ENDIF}
    {$IFDEF DEBUG}
    infoln(Executable + ': Result code was: ' + IntToStr(ResultCode),etDebug);
    {$ENDIF}
    if ResultCode >= 0 then //Not all non-0 result codes are errors. There's no way to tell, really
    begin
      if (ExpectOutput <> '') and (Ansipos(ExpectOutput, Output) = 0) then
      begin
        // This is not a warning/error message as sometimes we can use multiple different versions of executables
        if Level<>etCustom then infoln(Executable + ' is not a valid ' + ExeName + ' application. ' +
          ExeName + ' exists but shows no (' + ExpectOutput + ') in its output.',Level);
        OperationSucceeded := false;
      end
      else
      begin
        // We're not looking for any specific output so we're happy
        OperationSucceeded := true;
      end;
    end
    else
    begin
      {$IFDEF DEBUG}
      infoln(Executable + ' is not a valid ' + ExeName + ' application (' + ExeName + ' result code was: ' + IntToStr(ResultCode) + ')',etDebug);
      {$ELSE}
      // This is not a warning/error message as sometimes we can use multiple different versions of executables
      if Level<>etCustom then infoln(Executable + ' is not a valid ' + ExeName + ' application (' + ExeName + ' result code was: ' + IntToStr(ResultCode) + ')',Level);
      {$ENDIF}
      OperationSucceeded := false;
    end;
  except
    on E: Exception do
    begin
      // This is not a warning/error message as sometimes we can use multiple different versions of executables
      if Level<>etCustom then infoln(Executable + ' is not a valid ' + ExeName + ' application (' + 'Exception: ' + E.ClassName + '/' + E.Message + ')', Level);
      OperationSucceeded := false;
    end;
  end;
  if OperationSucceeded then
    infoln('Found valid ' + ExeName + ' application.',etDebug);
  Result := OperationSucceeded;
end;

function CheckExecutable(Executable, Parameters, ExpectOutput: string): boolean;
begin
  //result:=IsExecutable(Executable);
  //if result then
  result:=CheckExecutable(Executable, Parameters, ExpectOutput, etInfo);
end;

function GetJava: string;
var
  s:string;
  JavaFiles: TStringList;
begin
  {$ifdef Windows}
  result:='';

  s:=SysUtils.GetEnvironmentVariable('JAVA_HOME');
  if s<>'' then
  begin
    s:=IncludeTrailingPathDelimiter(s);
    JavaFiles := FindAllFiles(s, 'java.exe', true);
    try
      if JavaFiles.Count>0 then
      begin
        result:=JavaFiles[0];
      end;
    finally
      JavaFiles.Free;
    end;
  end;

  if result<>'' then exit;

  // When running a 32bit fpcupdeluxe the command below results in "C:\Program Files (x86)\"
  // When running a 64bit fpcupdeluxe the command below results in "C:\Program Files\"
  s:=GetWindowsSpecialDir(CSIDL_PROGRAM_FILES);

  //On Win32, first try to find the 64bit version of java in the standard 64bit program directory
  {$ifdef win32}
  if (IsWindows64) then
  begin
    s:=StringReplace(s,' (x86)','',[]);
  end;
  {$endif win32}
  s:=IncludeTrailingPathDelimiter(s)+'Java'+DirectorySeparator;
  JavaFiles := FindAllFiles(s, 'java.exe', true);
  try
    if JavaFiles.Count>0 then
    begin
      // Hack: get the latest java version ... ;-)
      result:=JavaFiles[JavaFiles.Count-1];
    end;
  finally
    JavaFiles.Free;
  end;

  if result<>'' then exit;

  {$ifdef win32}
  //On Win32, try to find the 32bit version of java in the standard 32bit program directory
  s:=GetWindowsSpecialDir(CSIDL_PROGRAM_FILES);
  s:=IncludeTrailingPathDelimiter(s)+'Java'+DirectorySeparator;
  JavaFiles := FindAllFiles(s, 'java.exe', true);
  try
    if JavaFiles.Count>0 then
    begin
      // Hack: get the latest java version ... ;-)
      result:=JavaFiles[JavaFiles.Count-1];
    end;
  finally
    JavaFiles.Free;
  end;
  {$endif win32}

  if result='' then result:=Which('java.exe');

  {$else Windows}
  result:=Which('java');
  {$endif Windows}
end;

function CheckJava: boolean;
begin
  {$ifdef Windows}
  result:=CheckExecutable(GetJava, '-version', '');
  {$else}
  result:=CheckExecutable('java', '-version', '', etInfo);
  {$endif}
end;


function ExtractFileNameOnly(const AFilename: string): string;
var
  StartPos: Integer;
  ExtPos: Integer;
begin
  StartPos:=length(AFilename)+1;
  while (StartPos>1)
  and not (AFilename[StartPos-1] in AllowDirectorySeparators)
  {$IFDEF Windows}and (AFilename[StartPos-1]<>':'){$ENDIF}
  do
    dec(StartPos);
  ExtPos:=length(AFilename);
  while (ExtPos>=StartPos) and (AFilename[ExtPos]<>'.') do
    dec(ExtPos);
  if (ExtPos<StartPos) then ExtPos:=length(AFilename)+1;
  Result:=copy(AFilename,StartPos,ExtPos-StartPos);
end;

function DoubleQuoteIfNeeded(s: string): string;
begin
  result:=Trim(s);
  if (Pos(' ',result)<>0) AND (Pos('"',result)=0) then result:='"'+result+'"';
end;

function UppercaseFirstChar(s: String): String;
var
  ch, rest: String;
  //first: String;
  i: integer;
begin
  i:=1;
  //while (Length(s)>=i) AND (NOT (s[i] in ['a'..'z'])) do inc(i);
  ch    := Copy(s, i, 1);
  //first := Copy(s, 1, i-1);
  rest  := Copy(s, Length(ch)+i, MaxInt);
  result := {LowerCase(first) + }UpperCase(ch) + LowerCase(rest);
end;

function DirectoryIsEmpty(Directory: string): Boolean;
var
  SR: TRawByteSearchRec;
  i: Integer;
begin
  Result:=(NOT DirectoryExists(Directory));
  if Result=true then exit;
  SysUtils.FindFirst(IncludeTrailingPathDelimiter(Directory) + '*', faAnyFile, SR);
  for i := 1 to 2 do
    if (SR.Name = '.') or (SR.Name = '..') then
      Result := SysUtils.FindNext(SR) <> 0;
  SysUtils.FindClose(SR);
end;

function GetTargetCPU:string;
begin
  result:=lowercase({$i %FPCTARGETCPU%});
end;

function GetTargetOS:string;
begin
  result:=lowercase({$i %FPCTARGETOS%});
end;

function GetDistro:string;
var
  Major,Minor,Build,i,j: Integer;
  AllOutput : TStringList;
  s,t:ansistring;
  success:boolean;
begin
  t:='unknown';
  success:=false;
  {$ifdef Unix}
    {$ifndef Darwin}
      s:='';
      if (ExecuteCommand('cat /etc/os-release',s,false)=0) then
      begin
        if Pos('No such file or directory',s)=0 then
        begin
          AllOutput:=TStringList.Create;
          try
            AllOutput.Text:=s;
            s:='';
            s:=AllOutput.Values['NAME'];
            if Length(s)=0 then s := AllOutput.Values['ID_LIKE'];
            if Length(s)=0 then s := AllOutput.Values['DISTRIB_ID'];
            if Length(s)=0 then s := AllOutput.Values['ID'];
            success:=(Length(s)>0);
          finally
            AllOutput.Free;
          end;
        end;
      end;
      if (NOT success) then
      begin
        s:='';
        if (ExecuteCommand('cat /etc/system-release',s,false)=0) then
        begin
          if Pos('No such file or directory',s)=0 then
          begin
            AllOutput:=TStringList.Create;
            try
              AllOutput.Text:=s;
              s:='';
              s:=AllOutput.Values['NAME'];
              if Length(s)=0 then s := AllOutput.Values['ID_LIKE'];
              if Length(s)=0 then s := AllOutput.Values['DISTRIB_ID'];
              if Length(s)=0 then s := AllOutput.Values['ID'];
              success:=(Length(s)>0);
            finally
              AllOutput.Free;
            end;
          end;
        end;
      end;
      if (NOT success) then
      begin
        s:='';
        if (ExecuteCommand('hostnamectl',s,false)=0) then
        begin
          AllOutput:=TStringList.Create;
          try
            AllOutput.NameValueSeparator:=':';
            AllOutput.Delimiter:=#10;
            AllOutput.StrictDelimiter:=true;
            AllOutput.DelimitedText:=s;
            s:='';
            for i:=0 to  AllOutput.Count-1 do
            begin
              j:=Pos('Operating System',AllOutput.Strings[i]);
              if j>0 then s:=s+Trim(AllOutput.Values[AllOutput.Names[i]]);
              j:=Pos('Kernel',AllOutput.Strings[i]);
              if j>0 then s:=s+' '+Trim(AllOutput.Values[AllOutput.Names[i]]);
            end;
            success:=(Length(s)>0);
          finally
            AllOutput.Free;
          end;
        end;
      end;
      if (NOT success) then t:='unknown' else
      begin
        s:=DelChars(s,'"');
        t:=Trim(s);
      end;
      {$ifdef BSD}
      if (t='unknown') then
      begin
        if (ExecuteCommand('uname -r',s,false)=0)
           then t := GetTargetOS+' '+lowercase(Trim(s));
      end;
      {$endif}

      if (t='unknown') then t := GetTargetOS;

      if (NOT success) then if (ExecuteCommand('uname -r',s,false)=0)
         then t := t+' '+lowercase(Trim(s));

    {$else Darwin}
      if (ExecuteCommand('sw_vers -productName', s, false)=0) then
      begin
        if Length(s)>0 then t:=Trim(s);
      end;
      if Length(s)=0 then t:=GetTargetOS;
      if (ExecuteCommand('sw_vers -productVersion', s, false)=0) then
      begin
        if Length(s)>0 then
        begin
          GetVersionFromString(s,Major,Minor,Build);
          t:=t+' '+InttoStr(Major)+'.'+InttoStr(Minor)+'.'+InttoStr(Build);
        end;
      end;
    {$endif Darwin}
  {$endif Unix}

  {$ifdef MSWindows}
    t:='Win';
    if IsWindows64
       then t:=t+'64'
       else t:=t+'32';
    if GetWin32Version(Major,Minor,Build)
       then t:=t+'-'+InttoStr(Major)+'.'+InttoStr(Minor)+'.'+InttoStr(Build);
  {$endif MSWindows}
  result:=t;
end;

function GetFreeBSDVersion:byte;
var
  s:string;
  i,j:integer;
begin
  result:=0;
  s:=GetDistro;
  if Length(s)>0 then
  begin
    i:=1;
    while (Length(s)>=i) AND (NOT (s[i] in ['0'..'9'])) do Inc(i);
    j:=0;
    while (Length(s)>=i) AND (s[i] in ['0'..'9']) do
    begin
      j:=j*10+Ord(s[i])-$30;
      Inc(i);
    end;
    result:=j;
  end;
end;

function GetTargetCPUOS:string;
begin
  result:=GetTargetCPU+'-'+GetTargetOS;
end;


function GetFPCTargetCPUOS(const aCPU,aOS:string;const Native:boolean=true): string;
var
  processorname, os: string;
begin
  os := GetTargetOS;
  processorname := GetTargetCPU;

  if not Native then
  begin
    if aCPU <> '' then
      processorname := aCPU;
    if aOS <> '' then
      os := aOS;
  end;
  Result := processorname + '-' + os;
end;

function checkGithubRelease(const aURL:string):string;
var
  s,aFile    : string;
  Json       : TJSONData;
  JsonObject : TJSONObject;
  Releases   : TJSONArray;
  NewVersion : boolean;
  i          : integer;
  JSONFile     : string;
  JSONFileList : TStringList;
  Content      : string;
  Success:boolean;

begin
  Success:=false;
  NewVersion:=false;
  result:='';
  if (Length(aURL)>0) then
  begin

    JSONFile := GetTempFileNameExt('','FPCUPTMP','tmp');

    Success:=Download(
             False,
             aURL,
             JSONFile);
    if Success then
    begin
      JSONFileList:=TStringList.Create;
    try
        JSONFileList.LoadFromFile(JSONFile);
        Content:=JSONFileList.Text;
      finally
        JSONFileList.Free;
        end;

      if (Length(Content)>0) then
        begin
        Json:=GetJSON(Content);
          try
            if JSON=Nil then exit;
          try
            JsonObject := TJSONObject(Json);
            // Example ---
            // tag_name: "1.6.2b"
            // name: "Release v1.6.2b of fpcupdeluxe"
            s:=JsonObject.Get('tag_name');
            if GetNumericalVersion(s)>GetNumericalVersion(DELUXEVERSION) then NewVersion:=True;
            if GetNumericalVersion(s)=GetNumericalVersion(DELUXEVERSION) then
            begin
              if Ord(s[Length(s)])>Ord(DELUXEVERSION[Length(DELUXEVERSION)]) then NewVersion:=True;
            end;
            if NewVersion then
            begin
              s:=JsonObject.Get('prerelease');//Should be False
              NewVersion:=(s='False');
            end;
            //YES !!!
            if NewVersion then
            begin
              //Assets is an array of binaries belonging to a release
              Releases:=JsonObject.Get('assets',TJSONArray(nil));
              for i:=0 to (Releases.Count-1) do
              begin
                JsonObject := TJSONObject(Releases[i]);
                // Example ---
                // browser_download_url: "https://github.com/newpascal/fpcupdeluxe/releases/download/1.6.2b/fpcupdeluxe-aarch64-linux"
                // name: "fpcupdeluxe-aarch64-linux"
                // created_at: "2018-10-14T06:58:44Z"
                s:=JsonObject.Get('name');

                aFile:='fpcupdeluxe-'+GetTargetCPUOS;
                {$ifdef Darwin}
                {$ifdef LCLCARBON}
                aFile:=aFile+'-carbon';
                {$endif}
                {$ifdef LCLCOCOA}
                aFile:=aFile+'-cocoa';
                {$endif}
                {$endif}
                {$if defined(LCLQT) or defined(LCLQT5)}
                aFile:=aFile+'-qt5';
                {$endif}

                if (Pos(aFile,s)=1) then
                begin
                  result:=JsonObject.Get('browser_download_url');
                  break;
                end;
              end;
            end;
          except
            //Swallow exceptions in case of failures: not important
          end;
          finally
            Json.Free;
          end;
        end;
      end;
    SysUtils.Deletefile(JSONFile); //Get rid of temp file.

  end;
end;

{$IF FPC_FULLVERSION < 30300}
Function Pos(Const Substr : RawByteString; Const Source : RawByteString; Offset : Sizeint = 1) : SizeInt;
var
  i,MaxLen : SizeInt;
  pc : PAnsiChar;
begin
  Pos:=0;
  if (Length(SubStr)>0) and (Offset>0) and (Offset<=Length(Source)) then
   begin
     MaxLen:=Length(source)-Length(SubStr);
     i:=Offset-1;
     pc:=@source[Offset];
     while (i<=MaxLen) do
      begin
        inc(i);
        if (SubStr[1]=pc^) and
           (CompareByte(Substr[1],pc^,Length(SubStr))=0) then
         begin
           Pos:=i;
           exit;
         end;
        inc(pc);
    end;
  end;
end;
{$ENDIF}

{TThreadedUnzipper}

procedure TThreadedUnzipper.DoOnZipProgress;
begin
  if Assigned(FOnZipProgress) then
    FOnZipProgress(Self, FPercent);
end;

procedure TThreadedUnzipper.DoOnZipFile;
begin
  if Assigned(FOnZipFile) then
    FOnZipFile(Self, FCurrentFile, FFileCount, FTotalFileCount);
end;

procedure TThreadedUnzipper.DoOnZipCompleted;
begin
  if Assigned(FOnZipCompleted) then
    FOnZipCompleted(Self);
end;

procedure TThreadedUnzipper.Execute;
var
  x:cardinal;
  s:string;
begin
  try
    FUnZipper.Examine;

    {$ifdef MSWINDOWS}
    // on windows, .files (hidden files) cannot be created !!??
    // still to check on non-windows
    if FFileList.Count=0 then
    begin
      for x:=0 to FUnZipper.Entries.Count-1 do
      begin
        { UTF8 features are only available in FPC >= 3.1 }
        {$IF FPC_FULLVERSION > 30100}
        if FUnZipper.UseUTF8
          then s:=FUnZipper.Entries.Entries[x].UTF8ArchiveFileName
          else
        {$endif}
          s:=FUnZipper.Entries.Entries[x].ArchiveFileName;

        if (Pos('/.',s)>0) OR (Pos('\.',s)>0) then continue;
        if (Length(s)>0) AND (s[1]='.') then continue;
        FFileList.Append(s);
      end;
    end;
    {$endif}

    if FFileList.Count=0
      then FTotalFileCount:=FUnZipper.Entries.Count
      else FTotalFileCount:=FFileList.Count;

    if FFileList.Count=0
      then FUnZipper.UnZipAllFiles
      else FUnZipper.UnZipFiles(FFileList);
  except
    on E: Exception do
    begin
      FErrMsg := E.Message;
      //Synchronize(@DoOnZipError);
    end;
  end;
  Synchronize(@DoOnZipCompleted);
end;

constructor TThreadedUnzipper.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FUnZipper := TUnZipper.Create;
  FFileList := TStringList.Create;
  FStarted := False;
end;

destructor TThreadedUnzipper.Destroy;
begin
  FFileList.Free;
  FUnZipper.Free;
  inherited Destroy;
end;


procedure TThreadedUnzipper.DoOnProgress(Sender : TObject; Const Pct : Double);
begin
  FPercent:=Pct;
  if FTotalFileCount<=100 then Synchronize(@DoOnZipProgress);
end;

procedure TThreadedUnzipper.DoOnFile(Sender : TObject; Const AFileName : String);
begin
  Inc(FFileCount);
  if FTotalFileCount>100
     then FCurrentFile:='files'
     else FCurrentFile:=ExtractFileName(AFileName);
  if FTotalFileCount>50000 then
  begin
    if (FFileCount MOD 1000)=0 then Synchronize(@DoOnZipFile);
  end
  else
  if FTotalFileCount>5000 then
  begin
    if (FFileCount MOD 100)=0 then Synchronize(@DoOnZipFile);
  end
  else
  if FTotalFileCount>500 then
  begin
    if (FFileCount MOD 10)=0 then Synchronize(@DoOnZipFile);
  end
  else
  if FTotalFileCount>100 then
  begin
    if (FFileCount MOD 2)=0 then Synchronize(@DoOnZipFile);
  end
  else
  Synchronize(@DoOnZipFile);
end;


procedure TThreadedUnzipper.DoUnZip(const ASrcFile, ADstDir: String; Files:array of string);
var
  i:word;
begin
  if FStarted then exit;
  infoln('TThreadedUnzipper: Going to extract files from ' + ASrcFile + ' into ' + ADstDir,etInfo);
  FUnZipper.Clear;
  FUnZipper.OnPercent:=10;
  FUnZipper.FileName := ASrcFile;
  FUnZipper.OutputPath := ADstDir;
  FUnZipper.OnProgress := @DoOnProgress;
  FUnZipper.OnStartFile:= @DoOnFile;
  FFileList.Clear;
  if Length(Files)>0 then
    for i := 0 to high(Files) do
      FFileList.Append(Files[i]);
  FPercent:=0;
  FFileCount:=0;
  FTotalFileCount:=0;
  FStarted := True;
  Start;
end;

{TNormalUnzipper}

procedure TNormalUnzipper.DoOnFile(Sender : TObject; Const AFileName : String);
begin
  Inc(FFileCnt);
  FCurrentFile:=ExtractFileName(AFileName);
  if FTotalFileCnt>50000 then
  begin
    if (FFileCnt MOD 5000)=0 then infoln('Extracted #'+InttoStr(FFileCnt)+' files out of #'+InttoStr(FTotalFileCnt),etInfo);
  end
  else
  if FTotalFileCnt>5000 then
  begin
    if (FFileCnt MOD 500)=0 then infoln('Extracted #'+InttoStr(FFileCnt)+' files out of #'+InttoStr(FTotalFileCnt),etInfo);
  end
  else
  if FTotalFileCnt>500 then
  begin
    if (FFileCnt MOD 50)=0 then infoln('Extracted #'+InttoStr(FFileCnt)+' files out of #'+InttoStr(FTotalFileCnt),etInfo);
  end
  else
  if FTotalFileCnt>50 then
  begin
    if (FFileCnt MOD 5)=0 then infoln('Extracted #'+InttoStr(FFileCnt)+' files out of #'+InttoStr(FTotalFileCnt),etInfo);
  end
  else
    infoln('Extracting '+FCurrentFile+'. #'+InttoStr(FFileCnt)+' out of #'+InttoStr(FTotalFileCnt),etInfo);
end;

function TNormalUnzipper.DoUnZip(const ASrcFile, ADstDir: String; Files:array of string):boolean;
var
  i:word;
  x:cardinal;
  s:string;
begin
  infoln('TNormalUnzipper: Going to extract files from ' + ASrcFile + ' into ' + ADstDir,etInfo);
  result:=false;
  FUnzipper := TUnzipper.Create;
  try
    FFileList := TStringList.Create;
  try
      FUnZipper.Clear;
      FUnZipper.OnPercent:=10;
      { Flat option only available in FPC >= 3.1 }
      {$IF FPC_FULLVERSION > 30100}
      FUnZipper.Flat:=Flat;
      {$ENDIF}
      FUnZipper.FileName := ASrcFile;
      FUnZipper.OutputPath := ADstDir;
      FUnZipper.OnStartFile:= @DoOnFile;
      FFileList.Clear;
      if Length(Files)>0 then
        for i := 0 to high(Files) do
          FFileList.Append(Files[i]);
      FFileCnt:=0;
      FTotalFileCnt:=0;

      FUnZipper.Examine;

      {$ifdef MSWINDOWS}
      // on windows, .files (hidden files) cannot be created !!??
      // still to check on non-windows
      if FFileList.Count=0 then
      begin
        for x:=0 to FUnZipper.Entries.Count-1 do
        begin
          { UTF8 features are only available in FPC >= 3.1 }
          {$IF FPC_FULLVERSION > 30100}
          if FUnZipper.UseUTF8
            then s:=FUnZipper.Entries.Entries[x].UTF8ArchiveFileName
            else
          {$endif}
            s:=FUnZipper.Entries.Entries[x].ArchiveFileName;

          if (Pos('/.',s)>0) OR (Pos('\.',s)>0) then continue;
          if (Length(s)>0) AND (s[1]='.') then continue;
          FFileList.Append(s);
        end;
      end;
      {$endif}

      if FFileList.Count=0
        then FTotalFileCnt:=FUnZipper.Entries.Count
        else FTotalFileCnt:=FFileList.Count;

      if FFileList.Count=0
        then FUnZipper.UnZipAllFiles
        else FUnZipper.UnZipFiles(FFileList);

      { Flat option only available in FPC >= 3.1 }
      {$IF FPC_FULLVERSION < 30100}
      if Flat then
      begin
        if FFileList.Count=0 then
        begin
          for x:=0 to FUnZipper.Entries.Count-1 do
          begin

            if FUnZipper.Entries.Entries[x].IsDirectory then continue;
            if FUnZipper.Entries.Entries[x].IsLink then continue;

            { UTF8 features are only available in FPC >= 3.1 }
            {$IF FPC_FULLVERSION > 30100}
            if FUnZipper.UseUTF8
               then s:=FUnZipper.Entries.Entries[x].UTF8ArchiveFileName
               else
            {$endif}
            s:=FUnZipper.Entries.Entries[x].ArchiveFileName;

            if (Pos('/.',s)>0) OR (Pos('\.',s)>0) then continue;
            if (Length(s)>0) AND (s[1]='.') then continue;

            FFileList.Append(s);
          end;
        end;

        for x:=0 to FFileList.Count-1 do
        begin
          s:=FFileList.Strings[x];
          if DirectorySeparator<>'/' then s:=StringReplace(s, '/', DirectorySeparator, [rfReplaceAll]);
          MoveFile(IncludeTrailingPathDelimiter(ADstDir)+s, IncludeTrailingPathDelimiter(ADstDir)+ExtractFileName(s));
        end;

        for x:=0 to FUnZipper.Entries.Count-1 do
        begin
          if FUnZipper.Entries.Entries[x].IsDirectory then
          begin
            { UTF8 features are only available in FPC >= 3.1 }
            {$IF FPC_FULLVERSION > 30100}
            if FUnZipper.UseUTF8
               then s:=FUnZipper.Entries.Entries[x].UTF8ArchiveFileName
               else
            {$endif}
            s:=FUnZipper.Entries.Entries[x].ArchiveFileName;
            if DirectorySeparator<>'/' then s:=StringReplace(s, '/', DirectorySeparator, [rfReplaceAll]);
            if (s='.') or (s=DirectorySeparator+'.') or (Pos('..',s)>0) then continue;
            DeleteDirectoryEx(IncludeTrailingPathDelimiter(ADstDir)+s);
          end;
        end;
      end;
      {$ENDIF}

    result:=true;

    finally
      FFileList.Free;
    end;

  finally
    FUnzipper.Free;
  end;
end;

{ TLogger }

function TLogger.GetLogFile: string;
begin
  result:=FLog.FileName;
end;

procedure TLogger.SetLogFile(AValue: string);
begin
  if AValue<>FLog.FileName then
  begin
    FLog.Active:=false;//save WriteLog output
    FLog.FileName:=AValue;
  end;
end;

procedure TLogger.WriteLog(Message: string; ToConsole: Boolean);
begin
  FLog.Info(Message);
  if ToConsole then infoln(Message,etInfo);
end;

procedure TLogger.WriteLog(EventType: TEventType;Message: string; ToConsole: Boolean);
begin
  FLog.Log(EventType, Message);
  if ToConsole then infoln(Message,EventType);
end;

constructor TLogger.Create;
begin
  FLog:=TEventLog.Create(nil);
  FLog.LogType:=ltFile;
  FLog.AppendContent:=true;
  FLog.RaiseExceptionOnError:=false; //Don't throw exceptions on log errors.
end;

destructor TLogger.Destroy;
begin
  FLog.Active:=false;//save WriteLog text
  FLog.Free;
  inherited Destroy;
end;

constructor TBasicDownLoader.Create;
begin
  Inherited Create(nil);
end;

constructor TBasicDownLoader.Create(AOwner: TComponent);
begin
  inherited;
  FMaxRetries:=MAXCONNECTIONRETRIES;
  FVerbose:=False;
  FUsername:='';
  FPassword:='';
  FHTTPProxyHost:='';
  FHTTPProxyPort:=0;
  FHTTPProxyUser:='';
  FHTTPProxyPassword:='';
end;

destructor TBasicDownLoader.Destroy;
begin
  inherited;
end;

procedure TBasicDownLoader.SetVerbose(aValue:boolean);
begin
  FVerbose:=aValue;
end;

procedure TBasicDownLoader.setCredentials(user,pass:string);
begin
  FUsername:=user;
  FPassword:=pass;
end;

procedure TBasicDownLoader.setProxy(host:string;port:integer;user,pass:string);
begin
  FHTTPProxyHost:=host;
  FHTTPProxyPort:=port;
  FHTTPProxyUser:=user;
  FHTTPProxyPassword:=pass;
end;

procedure TBasicDownLoader.parseFTPHTMLListing(F:TStream;filelist:TStringList);
var
  ADoc: THTMLDocument;
  HTMFiles : TDOMNodeList;
  HTMFile : TDOMNode;
  FilenameValid:boolean;
  i,j:integer;
  s:string;
begin
  F.Position:=0;
  try
    ReadHTMLFile(ADoc,F);
    // a bit rough, but it works
    HTMFiles:=ADoc.GetElementsByTagName('a');
    for i:=0 to HTMFiles.Count-1 do
    begin
      HtmFile:=HTMFiles.Item[i];
      s:=HtmFile.TextContent;
      if Length(s)>0 then
      begin
        // validate filename (also rough)
        FilenameValid:=True;
        for j:=1 to Length(s) do
        begin
          FilenameValid := (NOT SysUtils.CharInSet(s[j], [';', '=', '+', '<', '>', '|','"', '[', ']', '\', '/', '''']));
          if (NOT FilenameValid) then break;
        end;
        if FilenameValid then FilenameValid:=(Pos('..',s)=0);
        // restrict ourselves to zip and bz2 ... we only use this to retrieve lists of bootstrapper archives !
        if FilenameValid then FilenameValid:=((LowerCase(ExtractFileExt(s))='.zip') OR (LowerCase(ExtractFileExt(s))='.bz2'));
        // finally, add filename if all is ok !!
        if FilenameValid then filelist.Add(s);
      end;
    end;
  finally
    aDoc.Free;
  end;
end;

{$ifdef ENABLENATIVE}
constructor TUseNativeDownLoader.Create;
begin
  Inherited;
  FMaxRetries:=MAXCONNECTIONRETRIES;
  {$ifdef Darwin}
  // GitHub needs TLS 1.2 .... native FPC client does not support this (through OpenSSL)
  // So, use client by Phil, a Lazarus forum member
  // See: https://macpgmr.github.io/
  aFPHTTPClient:=TNSHTTPSendAndReceive.Create;
  with aFPHTTPClient do
  begin
    TimeOut:=10000;
  end;
  {$else}
  aFPHTTPClient:=TFPHTTPClient.Create(Nil);
  with aFPHTTPClient do
  begin
    AllowRedirect:=True;
    //ConnectTimeout:=10000;
    //RequestHeaders.Add('Connection: Close');
    // User-Agent needed for sourceforge and GitHub
    AddHeader('User-Agent',USERAGENT);
    OnPassword:=@DoPassword;
    if FVerbose then
    begin
      OnRedirect:=@ShowRedirect;
      OnDataReceived:=@DoProgress;
      OnHeaders:=@DoHeaders;
    end;
  end;
  {$endif}
end;

destructor TUseNativeDownLoader.Destroy;
begin
  FreeAndNil(aFPHTTPClient);
  inherited;
end;

procedure TUseNativeDownLoader.DoHeaders(Sender : TObject);
Var
  I : Integer;
begin
  writeln('Response headers received:');
  with (Sender as TFPHTTPClient) do
    for I:=0 to ResponseHeaders.Count-1 do
      writeln(ResponseHeaders[i]);
end;

procedure TUseNativeDownLoader.DoProgress(Sender: TObject; const ContentLength, CurrentPos: Int64);
begin
  If (ContentLength=0) then
    writeln('Reading headers : ',CurrentPos,' Bytes.')
  else If (ContentLength=-1) then
    writeln('Reading data (no length available) : ',CurrentPos,' Bytes.')
  else
    writeln('Reading data : ',CurrentPos,' Bytes of ',ContentLength);
end;

procedure TUseNativeDownLoader.DoOnWriteStream(Sender: TObject; APos: Int64);
//From the mORMot !!
function KB(bytes: Int64): string;
const
  _B: array[0..5] of string[3] = ('KB','MB','GB','TB','PB','EB');
var
  hi,rem,b: cardinal;
begin
  if bytes<1 shl 10-(1 shl 10) div 10 then begin
    result:=Format('%d Byte',[integer(bytes)]);
    exit;
  end;
  if bytes<1 shl 20-(1 shl 20) div 10 then begin
    b := 0;
    rem := bytes;
    hi := bytes shr 10;
  end else
  if bytes<1 shl 30-(1 shl 30) div 10 then begin
    b := 1;
    rem := bytes shr 10;
    hi := bytes shr 20;
  end else
  if bytes<Int64(1) shl 40-(Int64(1) shl 40) div 10 then begin
    b := 2;
    rem := bytes shr 20;
    hi := bytes shr 30;
  end else
  if bytes<Int64(1) shl 50-(Int64(1) shl 50) div 10 then begin
    b := 3;
    rem := bytes shr 30;
    hi := bytes shr 40;
  end else
  if bytes<Int64(1) shl 60-(Int64(1) shl 60) div 10 then begin
    b := 4;
    rem := bytes shr 40;
    hi := bytes shr 50;
  end else begin
    b := 5;
    rem := bytes shr 50;
    hi := bytes shr 60;
  end;
  rem := rem and 1023;
  if rem<>0 then
    rem := rem div 102;
  if rem=10 then begin
    rem := 0;
    inc(hi); // round up as expected by an human being
  end;
  if rem<>0 then
    result:=Format('%d.%d %s',[hi,rem,_B[b]]) else
    result:=Format('%d %s',[hi,_B[b]]);
end;
begin
  //Show progress only every 5 seconds
  if SysUtils.GetTickCount64>StoredTickCount+5000 then
  begin
    infoln('Downloading '+aFileName+': '+KB(APos),etInfo);
    StoredTickCount:=SysUtils.GetTickCount64;
  end;
end;

procedure TUseNativeDownLoader.DoPassword(Sender: TObject; var RepeatRequest: Boolean);
Var
  H,UN,PW : String;
  P : Integer;
begin
  if FUsername <> '' then
  begin
    TFPHTTPClient(Sender).UserName:=FUsername;
    TFPHTTPClient(Sender).Password:=FPassword;
  end
  else
  begin

    with TFPHTTPClient(Sender) do
    begin
      H:=GetHeader(ResponseHeaders,'WWW-Authenticate');
    end;
    P:=Pos('realm',LowerCase(H));
    if (P>0) then
    begin
      P:=Pos('"',H);
      Delete(H,1,P);
      P:=Pos('"',H);
      H:=Copy(H,1,Pos('"',H)-1);
    end;

    writeln('Authorization required !');
    if Length(H)>1 then
    begin
      writeln('Remote site says: ',H);
      writeln('Enter username (empty quits): ');
      readln(UN);
    RepeatRequest:=(UN<>'');
    if RepeatRequest then
    begin
        writeln('Enter password: ');
      readln(PW);
      TFPHTTPClient(Sender).UserName:=UN;
      TFPHTTPClient(Sender).Password:=PW;
    end;
    end;
  end;
end;

procedure TUseNativeDownLoader.ShowRedirect(ASender: TObject; const ASrc: String;
  var ADest: String);
begin
  writeln('Following redirect from ',ASrc,'  ==> ',ADest);
end;

procedure TUseNativeDownLoader.SetVerbose(aValue:boolean);
begin
  inherited;
  {$ifndef Darwin}
  with aFPHTTPClient do
  begin
    if FVerbose then
    begin
      OnRedirect:=@ShowRedirect;
      OnDataReceived:=@DoProgress;
      OnHeaders:=@DoHeaders;
    end
    else
    begin
      OnRedirect:=nil;
      OnDataReceived:=nil;
      OnHeaders:=nil;
    end;
  end;
  {$endif}
end;

procedure TUseNativeDownLoader.setProxy(host:string;port:integer;user,pass:string);
begin
  Inherited;// setProxy(host,port,user,pass);
  with aFPHTTPClient do
  begin
    {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION > 30000)}
    Proxy.Host:=FHTTPProxyHost;
    Proxy.Port:=FHTTPProxyPort;
    Proxy.UserName:=FHTTPProxyUser;
    Proxy.Password:=FHTTPProxyPassword;
    {$endif}
  end;
end;

function TUseNativeDownLoader.getFTPFileList(const URL:string; filelist:TStringList):boolean;
var
  i: Integer;
  s: string;
  URI : TURI;
  P : String;
begin
  result:=false;
  URI:=ParseURI(URL);
  P:=URI.Protocol;
  if CompareText(P,'ftp')=0 then
  begin
    with TFTPSend.Create do
    try
      if FUsername <> '' then
      begin
        Username := FUsername;
        Password := FPassword;
      end
      else
      begin
        if Pos('ftp.freepascal.org',URL)>0 then
        begin
          Username := 'anonymous';
          Password := 'fpc@example.com';
        end;
      end;
      if Length(HTTPProxyHost)>0 then
      begin
        Sock.HTTPTunnelIP:=HTTPProxyHost;
        Sock.HTTPTunnelPort:=InttoStr(HTTPProxyPort);
        Sock.HTTPTunnelUser:=HTTPProxyUser;
        Sock.HTTPTunnelPass:=HTTPProxyPassword;
      end;
      TargetHost := URI.Host;
      if not Login then exit;
      Result := List(URI.Path, False);
      Logout;

      for i := 0 to FtpList.Count -1 do
      begin
        s := FTPList[i].FileName;
        filelist.Add(s);
      end;

      if FTPList.Lines.Count>0 then
      begin
        // do we have a HTML lsiting (due to a proxy) ?
        if Pos('<!DOCTYPE HTML',UpperCase(FTPList.Lines.Strings[0]))=1 then
        begin
          parseFTPHTMLListing(DataStream,filelist);
        end;
      end;

    finally
      Free;
    end;
  end;
end;

function TUseNativeDownLoader.FTPDownload(Const URL : String; filename:string):boolean;
var
  URI : TURI;
  aPort:integer;
begin
  // we will use synapse TFTPSend ... FPHTTPClient does not support FTP (yet)
  aFileName:=ExtractFileName(filename);
  result:=false;
  URI:=ParseURI(URL);
  aPort:=URI.Port;
  if aPort=0 then aPort:=21;
  Result := False;
  with TFTPSend.Create do
  try
    TargetHost := URI.Host;
    TargetPort := InttoStr(aPort);
    if FUsername <> '' then
    begin
      Username := FUsername;
      Password := FPassword;
    end
    else
    begin
      if Pos('ftp.freepascal.org',URL)>0 then
      begin
        Username := 'anonymous';
        Password := 'fpc@example.com';
      end;
    end;
    if Length(HTTPProxyHost)>0 then
    begin
      Sock.HTTPTunnelIP:=HTTPProxyHost;
      Sock.HTTPTunnelPort:=InttoStr(HTTPProxyPort);
      Sock.HTTPTunnelUser:=HTTPProxyUser;
      Sock.HTTPTunnelPass:=HTTPProxyPassword;
    end;
    if Login then
    begin
      DirectFileName := filename;
      DirectFile:=True;
      Result := RetrieveFile(URI.Path+URI.Document, False);
      Logout;
    end;
  finally
    Free;
  end;
end;

function TUseNativeDownLoader.HTTPDownload(Const URL : String; filename:string):boolean;
var
  tries:byte;
  response: Integer;
  aStream:TDownloadStream;
begin
  aFileName:=ExtractFileName(filename);
  result:=false;
  tries:=0;
  SysUtils.DeleteFile(filename); // overwrite targetfile

  aStream := TDownloadStream.Create(TFileStream.Create(filename, fmCreate));
  aStream.FOnWriteStream:=@DoOnWriteStream;
  StoredTickCount:=SysUtils.GetTickCount64;

  try
  with aFPHTTPClient do
  begin
    repeat
      try
          aStream.Position:=0;
          aStream.Size:=0;
          Get(URL,aStream);
        response:=ResponseStatusCode;
        result:=(response=200);
        //result:=(response>=100) and (response<300);
        if (NOT result) then
        begin
          Inc(tries);
          if FVerbose then
            infoln('TFPHTTPClient retry #' +InttoStr(tries)+ ' of download from '+URL+' into '+filename+'.',etDebug);
        end;
      except
        tries:=(MaxRetries+1);
      end;
    until (result or (tries>MaxRetries));
  end;
  finally
    aStream.Free;
  end;
  if NOT result then SysUtils.DeleteFile(filename); // delete stray file in case of error
end;

function TUseNativeDownLoader.getFile(const URL,filename:string):boolean;
begin
  try
    result:=Download(URL,filename);
  except
    SysUtils.DeleteFile(filename);
  end;
end;

function TUseNativeDownLoader.checkURL(const URL:string):boolean;
const
  HTTPHEADER='Connection';
  HTTPHEADERVALUE='Close';
var
  tries:byte;
  response: Integer;
begin
  result:=false;
  tries:=0;
  with aFPHTTPClient do
  begin
    AddHeader(HTTPHEADER,HTTPHEADERVALUE);
    repeat
      try
        HTTPMethod('HEAD', URL, Nil, []);
        response:=ResponseStatusCode;
        // 404 Not Found
        // The requested resource could not be found but may be available in the future. Subsequent requests by the client are permissible.
        result:=(response<>404);
        if (NOT result) then
        begin
          Inc(tries);
          if FVerbose then
            infoln('TFPHTTPClient retry #' +InttoStr(tries)+ ' check of ' + URL + '.',etInfo);
        end;
      except
        tries:=(MaxRetries+1);
      end;
    until (result or (tries>MaxRetries));

    // remove additional header
    if GetHeader(HTTPHEADER)=HTTPHEADERVALUE then
    begin
      response:=IndexOfHeader(HTTPHEADER);
      if (response<>-1) then RequestHeaders.Delete(response);
    end;
  end;
end;

function TUseNativeDownLoader.Download(const URL: String; filename:string):boolean;
const
  URLMAGIC='/download';
Var
  URI : TURI;
  aURL,P : String;
begin
  result:=false;
  aURL:=URL;
  if AnsiEndsStr(URLMAGIC,URL) then SetLength(aURL,Length(URL)-Length(URLMAGIC));
  URI:=ParseURI(aURL);
  P:=URI.Protocol;
  infoln('Native downloader: Getting ' + URI.Document + ' from '+P+'://'+URI.Host+URI.Path,etDebug);
  If CompareText(P,'ftp')=0 then
    result:=FTPDownload(URL,filename)
  else if CompareText(P,'http')=0 then
    result:=HTTPDownload(URL,filename)
  else if CompareText(P,'https')=0 then
    result:=HTTPDownload(URL,filename);
end;
{$endif}


{$IFDEF ENABLEWGET}

// proxy still to do !!

constructor TUseWGetDownloader.Create;
begin
  Inherited;

  FCURLOk:=LoadCurlLibrary;

  if (Length(WGETBinary)=0) OR (NOT FileExists(WGETBinary)) then
  begin
    WGETBinary:='wget';
  end;

  FWGETOk:=CheckExecutable(WGETBinary, '-V', '', etCustom);

  {$ifdef MSWINDOWS}
  {$ifdef CPU64}
  if (NOT FWGETOk) then
  begin
    WGETBinary:='wget64.exe';
  FWGETOk:=CheckExecutable(WGETBinary, '-V', '', etCustom);
  end;
  {$endif}
  if (NOT FWGETOk) then
  begin
    WGETBinary:='wget.exe';
    FWGETOk:=CheckExecutable(WGETBinary, '-V', '', etCustom);
  end;
  {$endif MSWINDOWS}

  if (NOT FCURLOk) AND (NOT FWGETOk) then
  begin
    //infoln('Could not initialize either libcurl or wget: expect severe failures !',etError);
  end;
end;

constructor TUseWGetDownloader.Create(aWGETBinary:string);
begin
  WGETBinary:=aWGETBinary;
  inherited Create;
end;

function TUseWGetDownloader.WGetDownload(Const URL : String; Dest : TStream):boolean;
var
  Buffer : Array[0..4096] of byte;
  Count : Integer;
begin
  result:=false;
  if (NOT FWGETOk) then exit;

  With TProcess.Create(Self) do
  try
    CommandLine:=WGETBinary+' -q --no-check-certificate --user-agent="'+USERAGENT+'" --tries='+InttoStr(MaxRetries)+' --output-document=- '+URL;
    Options:=[poUsePipes,poNoConsole];
    Execute;
    while Running do
    begin
      Count:=Output.Read(Buffer,SizeOf(Buffer));
      if (Count>0) then Dest.WriteBuffer(Buffer,Count);
    end;
    result:=((ExitStatus=0) AND (Dest.Size>0));
  finally
    Free;
  end;
end;

function DoWrite(Ptr : Pointer; Size : size_t; nmemb: size_t; Data : Pointer) : size_t;cdecl;
begin
  if Data=nil then result:=0 else
  begin
    result:=TStream(Data).Write(Ptr^,Size*nmemb);
  end;
end;

function TUseWGetDownloader.LibCurlDownload(Const URL : String; Dest : TStream):boolean;
var
  hCurl : pCurl;
  res: CURLcode;
  UserPass:string;
  aBuffer:PChar;
  location:string;
  response:sizeint;
begin
  result:=false;
  if (NOT FCURLOk) then exit;

  if LoadCurlLibrary then
  begin

    curl_global_init(CURL_GLOBAL_ALL);

    try
      hCurl:= curl_easy_init();
      if Assigned(hCurl) then
      begin

        res:=CURLE_OK;

        UserPass:='';
        if FUsername <> '' then
        begin
          UserPass:=FUsername+':'+FPassword;
        end
        else
        begin
          if Pos('ftp.freepascal.org',URL)>0 then UserPass:='anonymous:fpc@example.com';
        end;
        if Length(UserPass)>0 then if res=CURLE_OK then res:=curl_easy_setopt(hCurl, CURLOPT_USERPWD, pointer(UserPass));

        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_TCP_KEEPALIVE,1);
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl, CURLOPT_FOLLOWLOCATION, 1);
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_MAXREDIRS,5);
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl, CURLOPT_NOPROGRESS,1);
        {$ifdef MSWINDOWS}
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_SSL_VERIFYPEER, 0);
        {$else}
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2TLS);
        {$endif}
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_URL,PChar(URL));
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_WRITEFUNCTION,@DoWrite);
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_WRITEDATA,Pointer(Dest));
        if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_USERAGENT,PChar(CURLUSERAGENT));

        if res=CURLE_OK then res := curl_easy_perform(hCurl);

        if res=CURLE_OK then
        begin
          while true do
          begin
            res:=curl_easy_getinfo(hCurl,CURLINFO_RESPONSE_CODE, @response);
            // not needed anymore ... we set CURLOPT_FOLLOWLOCATION !
            (*
            if ( (res=CURLE_OK) AND ((response DIV 100)=3) ) then // we have a redirect !!
            begin
              res:=curl_easy_getinfo(hCurl, CURLINFO_REDIRECT_URL, aBuffer);
              location:=GetStringFromBuffer(aBuffer);
              if ( (res=CURLE_OK) AND (Length(location)>0) ) then
              begin
                res:=curl_easy_setopt(hCurl,CURLOPT_URL,PChar(location));
                if res=CURLE_OK then
                begin
                  Dest.Position:=0;
                  res := curl_easy_perform(hCurl);
                end;
              end;
            end
            else
            *)
            break;
          end;
        end;

        result:=((res=CURLE_OK) AND (Dest.Size>0));

        curl_easy_cleanup(hCurl);
      end;
    except
      // swallow libcurl exceptions
    end;
  end;
end;


function TUseWGetDownloader.FTPDownload(Const URL : String; Dest : TStream):boolean;
begin
  result:=LibCurlDownload(URL,Dest);
  if (result) then infoln('LibCurl FTP file download success !!!', etDebug);
  if (NOT result) then
  begin
    result:=WGetDownload(URL,Dest);
    if (result) then infoln('Wget FTP file download success !', etDebug);
  end;
end;

function TUseWGetDownloader.HTTPDownload(Const URL : String; Dest : TStream):boolean;
begin
  result:=LibCurlDownload(URL,Dest);
  if (result) then infoln('LibCurl HTTP file download success !!!', etDebug);
  if (NOT result) then
  begin
    result:=WGetDownload(URL,Dest);
    if (result) then infoln('Wget HTTP file download success !', etDebug);
  end;
end;

function TUseWGetDownloader.WGetFTPFileList(const URL:string; filelist:TStringList):boolean;
const
  WGETFTPLISTFILE='.listing';
var
  aURL:string;
  aTFTPList:TFTPList;
  s:string;
  i:integer;
  URI : TURI;
  P : String;
begin
  result:=false;
  if (NOT FWGETOk) then exit;

  URI:=ParseURI(URL);
  P:=URI.Protocol;
  if CompareText(P,'ftp')=0 then
  begin
    aURL:=URL;
    if aURL[Length(aURL)]<>'/' then aURL:=aURL+'/';
    result:=(ExecuteCommand(WGETBinary+' -q --no-remove-listing --tries='+InttoStr(MaxRetries)+' --spider '+aURL,false)=0);
    if result then
    begin
      if FileExists(WGETFTPLISTFILE) then
      begin
        aTFTPList:=TFTPList.Create;
        try
          aTFTPList:=TFTPList.Create;
          aTFTPList.Lines.LoadFromFile(WGETFTPLISTFILE);
          aTFTPList.ParseLines;
          for i := 0 to aTFTPList.Count -1 do
          begin
            s := aTFTPList[i].FileName;
            filelist.Add(s);
          end;
          SysUtils.DeleteFile(WGETFTPLISTFILE);
        finally
          aTFTPList.Free;
        end;
      end;
    end;
  end;
end;

function TUseWGetDownloader.LibCurlFTPFileList(const URL:string; filelist:TStringList):boolean;
var
  hCurl : pCurl;
  res: CURLcode;
  URI : TURI;
  s : String;
  aTFTPList:TFTPList;
  F:TMemoryStream;
  i:integer;
  UserPass :string;
begin
  result:=false;
  if (NOT FCURLOk) then exit;

  URI:=ParseURI(URL);
  s:=URI.Protocol;
  if CompareText(s,'ftp')=0 then
  begin
    if LoadCurlLibrary then
    begin

      //curl_global_init(CURL_GLOBAL_ALL);

      try
        hCurl:= curl_easy_init();
        if Assigned(hCurl) then
        begin

          res:=CURLE_OK;

          F:=TMemoryStream.Create;
          try

            UserPass:='';
            if FUsername <> '' then
            begin
              UserPass:=FUsername+':'+FPassword;
            end
            else
            begin
              if Pos('ftp.freepascal.org',URL)>0 then UserPass:='anonymous:fpc@example.com';
            end;
            if Length(UserPass)>0 then if res=CURLE_OK then res:=curl_easy_setopt(hCurl, CURLOPT_USERPWD, pointer(UserPass));

            if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_URL,pointer(URL));
            if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_WRITEFUNCTION,@DoWrite);
            if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_WRITEDATA,Pointer(F));
            if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_USERAGENT,CURLUSERAGENT);
            {$ifdef MSWINDOWS}
            if res=CURLE_OK then res:=curl_easy_setopt(hCurl,CURLOPT_SSL_VERIFYPEER, 0);
            {$endif}

            if res=CURLE_OK then res:=curl_easy_perform(hCurl);

            result:=(res=CURLE_OK);

            curl_easy_cleanup(hCurl);

            // libcurl correct exit ?
            if result then
            begin
              // do we have data ?
              if (F.Size>0) then
              begin
                F.Position:=0;
                aTFTPList:=TFTPList.Create;
                try
                  aTFTPList:=TFTPList.Create;
                  aTFTPList.Lines.LoadFromStream(F);

                  if aTFTPList.Lines.Count>0 then
                  begin
                    // do we have a HTML listing (due to a proxy) ?
                    if Pos('<!DOCTYPE HTML',UpperCase(aTFTPList.Lines.Strings[0]))=1 then
                    begin
                      parseFTPHTMLListing(F,filelist);
                    end
                    else
                    begin
                      // parse the pure FTP response
                      aTFTPList.ParseLines;
                      for i := 0 to aTFTPList.Count -1 do
                      begin
                        s := aTFTPList[i].FileName;
                        filelist.Add(s);
                      end;
                    end;
                  end;
                finally
                  aTFTPList.Free;
                end;
              end;
            end;

          finally
            F.Free;
          end;

        end;
      except
        // swallow libcurl exceptions
      end;
    end;
  end;
end;

function TUseWGetDownloader.getFTPFileList(const URL:string; filelist:TStringList):boolean;
begin
  result:=LibCurlFTPFileList(URL,filelist);
  if (result) then infoln('LibCurl FTP filelist success !!!!', etDebug);
  if (NOT result) then
  begin
    result:=WGetFTPFileList(URL,filelist);
    if (result) then infoln('Wget FTP filelist success !!!!', etDebug);
  end;
end;

function TUseWGetDownloader.checkURL(const URL:string):boolean;
var
  Output:string;
begin
  result:=false;

  if (NOT FWGETOk) then
  begin
    infoln('No Wget binary found: download will fail !!', etDebug);
    exit;
  end;

  Output:='';
  result:=(ExecuteCommand(WGETBinary+' --no-check-certificate --user-agent="'+USERAGENT+'" --tries='+InttoStr(MaxRetries)+' --spider '+URL,Output,false)=0);
  if result then
  begin
    result:=(Pos('Remote file exists',Output)>0);
  end;
  if NOT result then
  begin
    // on github, we get a 403 forbidden for an existing file !!
    result:=(Pos('github',Output)>0) AND (Pos('403 Forbidden',Output)>0);
    if (NOT result) then result:=(Pos('https://',Output)>0) AND (Pos('401 Unauthorized',Output)>0)
  end;
end;

function TUseWGetDownloader.Download(const URL: String; Dest: TStream):boolean;
Var
  URI : TURI;
  P : String;
begin
  result:=false;
  URI:=ParseURI(URL);
  P:=URI.Protocol;
  infoln('Wget downloader: Getting ' + URI.Document + ' from '+P+'://'+URI.Host+URI.Path,etDebug);
  If CompareText(P,'ftp')=0 then
    result:=FTPDownload(URL,Dest)
  else if CompareText(P,'http')=0 then
    result:=HTTPDownload(URL,Dest)
  else if CompareText(P,'https')=0 then
    result:=HTTPDownload(URL,Dest);
end;

function TUseWGetDownloader.getFile(const URL,filename:string):boolean;
var
  F : TFileStream;
begin
  result:=false;
  try
    F:=TFileStream.Create(filename,fmCreate);
    try
      result:=Download(URL,F);
    finally
      F.Free;
    end;
  except
    result:=False;
    SysUtils.DeleteFile(filename);
  end;
end;


{$ENDIF ENABLEWGET}

{ TDownloadStream }
constructor TDownloadStream.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
  FStream.Position := 0;
end;

destructor TDownloadStream.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TDownloadStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  Result := FStream.Read(Buffer, Count);
end;

function TDownloadStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  Result := FStream.Write(Buffer, Count);
  DoProgress;
end;

function TDownloadStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
  Result := FStream.Seek(Offset, Origin);
end;

procedure TDownloadStream.DoProgress;
begin
  if Assigned(FOnWriteStream) then
    FOnWriteStream(Self, Self.Position);
end;


initialization
  resourcefiles:=TStringList.Create;
  DoEnumResources;

finalization
  resourcefiles.Free;

end.

