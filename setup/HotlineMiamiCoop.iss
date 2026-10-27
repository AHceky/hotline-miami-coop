; Hotline Miami co-op mod - Windows installer (Inno Setup 6).
; Build: ISCC.exe installer\HotlineMiamiCoop.iss   ->   dist\HotlineMiami-Coop-Setup-v<ver>.exe
; It copies the mod (bundled Python, build tools, GML, hmnet.dll) to %LOCALAPPDATA%\HotlineMiamiCoop,
; asks for the game folder, name, other players' IPs and character, then runs
; tools\install.py --batch, which builds HotlineMiami_Coop.exe from the player's own game copy.

#define AppVer "1.0"

[Setup]
AppId={{27CF4983-360A-4E43-ABD7-2843BE075C18}
AppName=Hotline Miami Co-op
AppVersion={#AppVer}
AppVerName=Hotline Miami Co-op {#AppVer}
AppPublisher=AHceky, MoestroSWAGa
DefaultDirName={localappdata}\HotlineMiamiCoop
DisableDirPage=yes
DisableProgramGroupPage=yes
DisableReadyPage=no
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=HotlineMiami-Coop-Setup-v{#AppVer}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Hotline Miami Co-op {#AppVer}
ShowLanguageDialog=auto
SetupLogging=yes

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\dist\HotlineMiami-Coop\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion; Excludes: "__pycache__\*,hmcoop.txt,install.bat,uninstall.bat,hmnet_log.txt"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
Filename: "{code:GameDir}\HotlineMiami_Coop.exe"; WorkingDir: "{code:GameDir}"; Description: "{cm:RunGame}"; Flags: postinstall nowait skipifsilent unchecked; Check: BuildOk

[UninstallDelete]
Type: files; Name: "{userdesktop}\Hotline Miami Co-op.lnk"
Type: files; Name: "{userprograms}\Hotline Miami Co-op.lnk"
Type: files; Name: "{app}\installer.ini"
Type: files; Name: "{app}\install_log.txt"
Type: files; Name: "{app}\uninstall_log.txt"
Type: filesandordirs; Name: "{app}\tools\__pycache__"

[CustomMessages]
ru.GameTitle=Папка игры
ru.GameSub=Где установлена Hotline Miami?
ru.GameDesc=Установщик соберёт кооп-версию HotlineMiami_Coop.exe из твоей копии игры. Оригинальные файлы не меняются.%n%nПапка должна содержать HotlineMiami_Original.exe (Steam: ПКМ по игре -> Управление -> Просмотреть локальные файлы).
ru.GameNotFound=В этой папке нет HotlineMiami_Original.exe. Укажи папку hotline_miami из Steam.
ru.PlayerTitle=Ты и другие игроки
ru.PlayerSub=Имя над головой и адреса других игроков в Radmin VPN
ru.PlayerDesc=До 4 игроков. IP - адрес вида 26.x.x.x рядом с ником в Radmin VPN; достаточно вписать одного игрока, остальных игра найдёт сама. Код комнаты - одно слово, одинаковое у всех: без него к вам может подключиться любой, кто найдёт ваш адрес. С запущенным Steam игра сама находит игроков с тем же кодом комнаты, Radmin не нужен (или друг заходит через Steam: «Присоединиться к игре»). Всё это можно поменять и в меню игры (N, I, K, F).
ru.NameLabel=Твоё имя (латиницей, до 15 символов):
ru.PeerLabel=IP других игроков (через запятую):
ru.RoomLabel=Код комнаты (латиница и цифры, одинаковый у всех; можно пусто):
ru.BadName=Имя: только латинские буквы, цифры, пробел, точка, дефис и подчёркивание.
ru.CharTitle=Персонаж
ru.CharSub=Кем ты будешь играть
ru.CharLabel=Персонаж (из HM2 — нужна Hotline Miami 2 в Steam; менять можно в меню игры клавишей C):
ru.Windowed=Запускать в окне, а не на весь экран
ru.Building=Собираю HotlineMiami_Coop.exe из твоей копии игры (около минуты)...
ru.BuildFailed=Не получилось собрать кооп-версию игры. Оригинальные файлы не тронуты.%n%nЖурнал: %1%n%n%2
ru.RunGame=Запустить Hotline Miami Co-op
ru.Chars=Джекет|Борода (HM2)|Рихтер (HM2)|Кори (HM2)|Джейк (HM2)|Сын (HM2)|Писатель (HM2)|Пардо (HM2)|Хенчмен (HM2)|Случайно (с шансом — персонаж HM2)
en.GameTitle=Game folder
en.GameSub=Where is Hotline Miami installed?
en.GameDesc=The installer builds the co-op HotlineMiami_Coop.exe from your own game copy. The original files are not changed.%n%nThe folder must contain HotlineMiami_Original.exe (Steam: right-click the game -> Manage -> Browse local files).
en.GameNotFound=This folder has no HotlineMiami_Original.exe. Choose the hotline_miami folder from Steam.
en.PlayerTitle=You and the other players
en.PlayerSub=Name above your head and the other players' Radmin VPN addresses
en.PlayerDesc=Up to 4 players. The IP is the 26.x.x.x address next to the nickname in Radmin VPN; one player is enough, the game finds the others. The room code is one word, the same for everyone: without it anybody who finds your address can join. With Steam running, the game finds the players with the same room code by itself, no Radmin needed (or a friend joins from Steam: Join Game). All of this can be changed in the game menu too (N, I, K, F).
en.NameLabel=Your name (latin letters, up to 15):
en.PeerLabel=Other players' IPs (comma separated):
en.RoomLabel=Room code (latin letters and digits, the same for everyone; may be empty):
en.BadName=Name: latin letters, digits, space, dot, dash and underscore only.
en.CharTitle=Character
en.CharSub=Who you play as
en.CharLabel=Character (HM2 ones need Hotline Miami 2 on Steam; change it in the game menu with C):
en.Windowed=Run in a window instead of full screen
en.Building=Building HotlineMiami_Coop.exe from your game copy (about a minute)...
en.BuildFailed=Could not build the co-op game. The original files are untouched.%n%nLog: %1%n%n%2
en.RunGame=Start Hotline Miami Co-op
en.Chars=Jacket|Beard (HM2)|Richter (HM2)|Corey (HM2)|Jake (HM2)|Son (HM2)|Writer (HM2)|Pardo (HM2)|Henchman (HM2)|Random (chance of an HM2 character)

[Code]
const
  SkinIds = 'jacket|beard|richter|corey|jake|son|writer|pardo|henchman|random';

var
  GamePage: TInputDirWizardPage;
  PlayerPage: TInputQueryWizardPage;
  CharPage: TWizardPage;
  CharCombo: TNewComboBox;
  WindowedBox: TNewCheckBox;
  Prefilled: String;
  BuildResult: Integer;

function SplitPart(S: String; Index: Integer): String;
var
  i, p: Integer;
begin
  for i := 1 to Index do begin
    p := Pos('|', S);
    if p = 0 then begin Result := ''; exit; end;
    S := Copy(S, p + 1, Length(S));
  end;
  p := Pos('|', S);
  if p = 0 then Result := S else Result := Copy(S, 1, p - 1);
end;

function TryGame(Lib: String): String;
begin
  Result := '';
  Lib := AddBackslash(Lib) + 'steamapps\common\hotline_miami';
  if FileExists(Lib + '\HotlineMiami_Original.exe') then Result := Lib;
end;

function DetectGame(): String;
var
  SteamPath, Line, P: String;
  Lines: TArrayOfString;
  i, q: Integer;
begin
  Result := '';
  if not RegQueryStringValue(HKCU, 'Software\Valve\Steam', 'SteamPath', SteamPath) then
    SteamPath := ExpandConstant('{commonpf32}\Steam');
  StringChangeEx(SteamPath, '/', '\', True);
  Result := TryGame(SteamPath);
  if Result <> '' then exit;
  if LoadStringsFromFile(AddBackslash(SteamPath) + 'steamapps\libraryfolders.vdf', Lines) then
    for i := 0 to GetArrayLength(Lines) - 1 do begin
      Line := Trim(Lines[i]);
      if Pos('"path"', Lowercase(Line)) = 1 then begin
        P := Trim(Copy(Line, 7, Length(Line)));
        q := Length(P);
        if (q > 2) and (P[1] = '"') and (P[q] = '"') then begin
          P := Copy(P, 2, q - 2);
          StringChangeEx(P, '\\', '\', True);
          Result := TryGame(P);
          if Result <> '' then exit;
        end;
      end;
    end;
  Result := TryGame(ExpandConstant('{commonpf32}\Steam'));
end;

function GameDir(Param: String): String;
begin
  Result := RemoveBackslashUnlessRoot(GamePage.Values[0]);
end;

function BuildOk(): Boolean;
begin
  Result := BuildResult = 0;
end;

procedure InitializeWizard();
var
  i: Integer;
  Lbl: TNewStaticText;
begin
  BuildResult := -1;
  GamePage := CreateInputDirPage(wpWelcome, CustomMessage('GameTitle'), CustomMessage('GameSub'),
    CustomMessage('GameDesc'), False, '');
  GamePage.Add('');
  GamePage.Values[0] := DetectGame();

  PlayerPage := CreateInputQueryPage(GamePage.ID, CustomMessage('PlayerTitle'), CustomMessage('PlayerSub'),
    CustomMessage('PlayerDesc'));
  PlayerPage.Add(CustomMessage('NameLabel'), False);
  PlayerPage.Add(CustomMessage('PeerLabel'), False);
  PlayerPage.Add(CustomMessage('RoomLabel'), False);
  PlayerPage.Values[0] := 'PLAYER';
  PlayerPage.Values[1] := '26.';
  PlayerPage.Values[2] := '';

  CharPage := CreateCustomPage(PlayerPage.ID, CustomMessage('CharTitle'), CustomMessage('CharSub'));
  Lbl := TNewStaticText.Create(CharPage);
  Lbl.Parent := CharPage.Surface;
  Lbl.Caption := CustomMessage('CharLabel');
  Lbl.AutoSize := False;
  Lbl.WordWrap := True;
  Lbl.Width := CharPage.SurfaceWidth;
  Lbl.Height := ScaleY(32);
  CharCombo := TNewComboBox.Create(CharPage);
  CharCombo.Parent := CharPage.Surface;
  CharCombo.Style := csDropDownList;
  CharCombo.Top := Lbl.Top + Lbl.Height + ScaleY(6);
  CharCombo.Width := ScaleX(260);
  for i := 0 to 9 do CharCombo.Items.Add(SplitPart(CustomMessage('Chars'), i));
  CharCombo.ItemIndex := 0;
  WindowedBox := TNewCheckBox.Create(CharPage);
  WindowedBox.Parent := CharPage.Surface;
  WindowedBox.Top := CharCombo.Top + CharCombo.Height + ScaleY(18);
  WindowedBox.Width := CharPage.SurfaceWidth;
  WindowedBox.Caption := CustomMessage('Windowed');
end;

// settings of an earlier install in this game folder become the defaults
procedure Prefill(Game: String);
var
  Lines: TArrayOfString;
  i, k: Integer;
  L: String;
begin
  if Prefilled = Game then exit;
  Prefilled := Game;
  if not LoadStringsFromFile(AddBackslash(Game) + 'hmcoop.txt', Lines) then exit;
  for i := 0 to GetArrayLength(Lines) - 1 do begin
    L := Trim(Lines[i]);
    if Pos('name=', L) = 1 then PlayerPage.Values[0] := Copy(L, 6, Length(L));
    if Pos('peer=', L) = 1 then PlayerPage.Values[1] := Copy(L, 6, Length(L));
    if Pos('room=', L) = 1 then PlayerPage.Values[2] := Copy(L, 6, Length(L));
    if Pos('skin=', L) = 1 then
      for k := 0 to 9 do
        if SplitPart(SkinIds, k) = Lowercase(Copy(L, 6, Length(L))) then CharCombo.ItemIndex := k;
  end;
end;

function NameOk(S: String): Boolean;
var
  i: Integer;
begin
  Result := (Length(S) > 0) and (Length(S) <= 15);
  for i := 1 to Length(S) do
    if Pos(S[i], 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ._-') = 0 then Result := False;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = GamePage.ID then begin
    if not FileExists(AddBackslash(GameDir('')) + 'HotlineMiami_Original.exe') then begin
      MsgBox(CustomMessage('GameNotFound'), mbError, MB_OK);
      Result := False;
    end else
      Prefill(GameDir(''));
  end else if CurPageID = PlayerPage.ID then begin
    PlayerPage.Values[0] := Trim(PlayerPage.Values[0]);
    if not NameOk(PlayerPage.Values[0]) then begin
      MsgBox(CustomMessage('BadName'), mbError, MB_OK);
      Result := False;
    end;
  end;
end;

function Quote(S: String): String;
begin
  Result := '"' + S + '"';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Params, Log, LogText: String;
  Peer, Room: String;
  LogLines: TArrayOfString;
  i, n: Integer;
  Target: String;
begin
  if CurStep <> ssPostInstall then exit;
  Log := ExpandConstant('{app}\install_log.txt');
  // quotes would break the command line (install.py filters everything else)
  Peer := Trim(PlayerPage.Values[1]);
  StringChangeEx(Peer, '"', '', True);
  if Peer = '26.' then Peer := '';
  Room := Trim(PlayerPage.Values[2]);
  StringChangeEx(Room, '"', '', True);
  Params := Quote(ExpandConstant('{app}\tools\install.py')) + ' ' + Quote(GameDir('')) +
    ' --batch --name ' + Quote(PlayerPage.Values[0]) + ' --peer ' + Quote(Peer) + ' --room ' + Quote(Room) +
    ' --skin ' + SplitPart(SkinIds, CharCombo.ItemIndex) + ' --log ' + Quote(Log);
  if WindowedBox.Checked then Params := Params + ' --windowed';
  SetIniString('install', 'game', GameDir(''), ExpandConstant('{app}\installer.ini'));
  WizardForm.StatusLabel.Caption := CustomMessage('Building');
  WizardForm.ProgressGauge.Style := npbstMarquee;
  if not Exec(ExpandConstant('{app}\python\python.exe'), Params, ExpandConstant('{app}'), SW_HIDE,
              ewWaitUntilTerminated, BuildResult) then
    BuildResult := -2;
  WizardForm.ProgressGauge.Style := npbstNormal;
  if BuildResult <> 0 then begin
    LogText := '';
    // install.py writes the log as UTF-8 with a BOM, which LoadStringsFromFile understands
    if LoadStringsFromFile(Log, LogLines) then begin
      n := GetArrayLength(LogLines);
      for i := n - 15 to n - 1 do
        if i >= 0 then LogText := LogText + LogLines[i] + #13#10;
    end;
    MsgBox(FmtMessage(CustomMessage('BuildFailed'), [Log, LogText]), mbError, MB_OK);
  end else begin
    // shortcuts to the co-op game (its own icon), only when it was built
    Target := AddBackslash(GameDir('')) + 'HotlineMiami_Coop.exe';
    CreateShellLink(ExpandConstant('{userprograms}\Hotline Miami Co-op.lnk'), 'Hotline Miami Co-op', Target, '',
      GameDir(''), Target, 0, SW_SHOWNORMAL);
    if WizardIsTaskSelected('desktopicon') then
      CreateShellLink(ExpandConstant('{userdesktop}\Hotline Miami Co-op.lnk'), 'Hotline Miami Co-op', Target, '',
        GameDir(''), Target, 0, SW_SHOWNORMAL);
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Game: String;
  Code: Integer;
begin
  if CurUninstallStep <> usUninstall then exit;
  Game := GetIniString('install', 'game', '', ExpandConstant('{app}\installer.ini'));
  if Game = '' then exit;
  Exec(ExpandConstant('{app}\python\python.exe'),
       Quote(ExpandConstant('{app}\tools\install.py')) + ' ' + Quote(Game) + ' --uninstall --batch --log ' +
       Quote(ExpandConstant('{app}\uninstall_log.txt')), ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, Code);
end;
