{$I jvcl.inc}
unit GenerateUtils;

interface

uses
  Classes;

type
  TGenerateCallback = procedure (const msg : string);

// YOU MUST CALL THIS PROCEDURE BEFORE ANY OTHER IN THIS FILE
// AND EVERYTIME YOU CHANGE THE MODEL NAME
// (except Generate as it will call it automatically)
function LoadConfig(const XmlFileName : string; const ModelName : string; var ErrMsg : string) : Boolean;

function Generate(packages : TStrings;
                   targets : TStrings;
                   callback : TGenerateCallback;
                   const XmlFileName : string;
                   const ModelName : string;
                   var ErrMsg : string;
                   makeDof : Boolean = False;
                   path : string = '';
                   prefix : string = '';
                   format : string = '';
                   incFileName : string = ''
                  ) : Boolean;

procedure EnumerateTargets(targets : TStrings);

procedure EnumeratePackages(const Path : string; packages : TStrings);

procedure ExpandTargets(targets : TStrings);

procedure ExpandTargetsNoPerso(targets : TStrings);

function PackagesLocation : string;

var
  StartupDir : string;

implementation

uses
  Windows, SysUtils, ShellApi, Contnrs, FileUtils,
  {$IFDEF NO_JCL}
  UtilsJcl,
  {$ELSE}
  JclDateTime, JclStrings, JclFileUtils, JclSysUtils, JclLogic,
  {$ENDIF NO_JCL}
  JvSimpleXml;


type
  TTarget = class (TObject)
  private
    FName   : string;
    FDir    : string;
    FPName  : string;
    FPDir   : string;
    FEnv    : string;
    FVer    : string;
    FDefines: TStringList;
    FPathSep: string;
    function GetDir: string;
    function GetEnv: string;
    function GetPDir: string;
    function GetVer: string;
  public
    constructor Create(Node : TJvSimpleXmlElem); overload;
    destructor Destroy; override;

    property Name   : string read FName;
    property Dir    : string read GetDir;
    property PName  : string read FPName;
    property PDir   : string read GetPDir;
    property Env    : string read GetEnv;
    property Ver    : string read GetVer;
    property Defines: TStringList read FDefines;
    property PathSep: string read FPathSep;
  end;

  TTargetList = class (TObjectList)
  private
    function GetItemsByName(name: string): TTarget;
    function GetItems(index: integer): TTarget;
    procedure SetItems(index: integer; const Value: TTarget);
  public
    constructor Create(Node : TJvSimpleXmlElem); overload;

    property Items[index : integer] : TTarget read GetItems write SetItems;
    property ItemsByName[name : string] : TTarget read GetItemsByName; default;
  end;

  TAlias = class (TObject)
  private
    FValue: string;
    FName: string;
    FValueAsTStrings : TStringList;
    function GetValueAsTStrings: TStrings;
  public
    constructor Create(Node : TJvSimpleXmlElem); overload;
    destructor Destroy; override;

    property Name  : string read FName;
    property Value : string read FValue;
    property ValueAsTStrings : TStrings read GetValueAsTStrings;
  end;

  TAliasList = class (TObjectList)
  private
    function GetItemsByName(name: string): TAlias;
    function GetItems(index: integer): TAlias;
    procedure SetItems(index: integer; const Value: TAlias);
  public
    constructor Create(Node : TJvSimpleXmlElem); overload;

    property Items[index : integer] : TAlias read GetItems write SetItems;
    property ItemsByName[name : string] : TAlias read GetItemsByName; default;
  end;

  TDefine = class (TObject)
  private
    FName: string;
    FIfDefs: TStringList;
  public
    constructor Create(const Name : string; IfDefs : TStringList);
    destructor Destroy; override;

    property Name : string read FName write FName;
    property IfDefs : TStringList read FIfDefs;
  end;

  TDefinesList = class (TObjectList)
  private
    function GetItems(index: integer): TDefine;
    procedure SetItems(index: integer; const Value: TDefine);
  public
    constructor Create(incfile : TStringList); overload;
    function IsDefined(const Condition, Target : string; DefineLimit : Integer = -1): Boolean;

    property Items[index : integer] : TDefine read GetItems write SetItems; default;
  end;

var
  GCallBack         : TGenerateCallBack;
  GPackagesLocation : string;
  GIncFileName      : string;
  GPrefix           : string;
  GFormat           : string;
  TargetList        : TTargetList;
  AliasList         : TAliasList;
  DefinesList       : TDefinesList;
  IsBinaryCache     : TStringList;

function PackagesLocation : string;
begin
  Result := GPackagesLocation;
end;

function IsTrimmedStartsWith(const SubStr, TrimStr: string): Boolean;
var
  l, r, Len, SLen, i: Integer;
begin
  Result := False;

  l := 1;
  r := Length(TrimStr);
  while (l < r) and (TrimStr[l] <= #32) do
    Inc(l);
  while (r > l) and (TrimStr[r] <= #32) do
    Dec(r);
  if r > l then
  begin
    Len := r - l + 1;
    SLen := Length(SubStr);
    if Len >= SLen then
    begin
      Dec(l);
      for i := 1 to SLen do
        if SubStr[i] <> TrimStr[l + i] then
          Exit;
      Result := True;
    end;
  end;
end;

function IsTrimmedString(const TrimStr, S: string): Boolean;
var
  l, r, Len, SLen, i: Integer;
begin
  Result := False;

  l := 1;
  r := Length(TrimStr);
  while (l < r) and (TrimStr[l] <= #32) do
    Inc(l);
  while (r > l) and (TrimStr[r] <= #32) do
    Dec(r);
  if r > l then
  begin
    Len := r - l + 1;
    SLen := Length(S);
    if Len = SLen then
    begin
      Dec(l);
      for i := 1 to SLen do
        if S[i] <> TrimStr[l + i] then
          Exit;
      Result := True;
    end;
  end;
end;

function StartsWidth(const SubStr, S: string): Boolean;
var
  i, Len: Integer;
begin
  Result := False;
  len := Length(SubStr);
  if Len <= Length(S) then
  begin
    for i := 1 to Len do
      if SubStr[i] <> S[i] then
        Exit;
    Result := True;
  end;
end;

procedure StrReplaceLines(Lines: TStrings; const Search, Replace: AnsiString);
var
  i: Integer;
  S: string;
begin
  for i := 0 to Lines.Count - 1 do
  begin
    S := Lines[i];
    if Pos(Search, S) > 0 then
    begin
      StrReplace(S, Search, Replace, [rfReplaceAll]);
      Lines[i] := S;
    end;
  end;
end;


procedure SendMsg(const Msg : string);
begin
  if Assigned(GCallBack) then
    GCallBack(Msg);
end;

function VerifyModelNode(Node : TJvSimpleXmlElem; var ErrMsg : string) : Boolean;
begin
  // a valid model node must exist
  if not Assigned(Node) then
  begin
    Result := False;
    ErrMsg := 'No ''model'' node found in the ''models'' node.';
    Exit;
  end;

  // it must have a Name property
  if not Assigned(Node.Properties.ItemNamed['name']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must have a ''name'' property.';
    Exit;
  end;

  // it must have a prefix property
  if not Assigned(Node.Properties.ItemNamed['prefix']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must have a ''prefix'' property.';
    Exit;
  end;

  // it must have a format property
  if not Assigned(Node.Properties.ItemNamed['format']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must have a ''format'' property.';
    Exit;
  end;

  // it must have a packages property
  if not Assigned(Node.Properties.ItemNamed['packages']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must have a ''packages'' property.';
    Exit;
  end;

  // it must have a incfile property
  if not Assigned(Node.Properties.ItemNamed['incfile']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must have a ''incfile'' property.';
    Exit;
  end;

  // it must contain Targets
  if not Assigned(Node.Items.ItemNamed['targets']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must contain a ''targets'' node.';
    Exit;
  end;

  // it must contain Aliases
  if not Assigned(Node.Items.ItemNamed['aliases']) then
  begin
    Result := False;
    ErrMsg := 'A ''model'' node must contain a ''aliases'' node.';
    Exit;
  end;

  // if all went ok, then the node is deemed to be valid
  Result := True;
end;

function LoadConfig(const XmlFileName : string; const ModelName : string;
  var ErrMsg : string) : Boolean;
var
  xml : TJvSimpleXml;
  Node : TJvSimpleXmlElem;
  i : integer;
  all : string;
  target : TTarget;
begin
  Result := true;
  FreeAndNil(TargetList);
  FreeAndNil(AliasList);

  // Ensure the xml file exists
  if not FileExists(XmlFileName) then
  begin
    ErrMsg := Format('%s does not exist.', [XmlFileName]);
    Result := False;
    Exit;
  end;

  try
    // read the xml config file
    xml := TJvSimpleXml.Create(nil);
    try
      xml.LoadFromFile(XmlFileName);

      // The xml file must contain the models node
      if not Assigned(xml.Root.Items.itemNamed['models']) then
      begin
        Result := False;
        ErrMsg := 'The root node of the xml file must contain '+
                  'a node called ''models''.'; 
        Exit;
      end;

      Node := xml.root.Items.itemNamed['models'].items[0];
      if not VerifyModelNode(Node, ErrMsg) then
      begin
        Result := False;
        Exit;
      end;
      
      for i := 0 to xml.root.Items.itemNamed['models'].items.count - 1 do
        if xml.root.Items.itemNamed['models'].items[i].Properties.ItemNamed['Name'].value = ModelName then
          Node := xml.root.Items.itemNamed['models'].items[i];

      if not VerifyModelNode(Node, ErrMsg) then
      begin
        Result := False;
        Exit;
      end;

      TargetList := TTargetList.Create(Node.Items.ItemNamed['targets']);
      AliasList  := TAliasList.Create(Node.Items.ItemNamed['aliases']);

      GIncFileName      := Node.Properties.ItemNamed['IncFile'].Value;
      GPackagesLocation := Node.Properties.ItemNamed['packages'].Value;
      GFormat           := Node.Properties.ItemNamed['format'].Value;
      GPrefix           := Node.Properties.ItemNamed['prefix'].Value;

      // create the 'all' alias
      all := '';
      for i := 0 to TargetList.Count-1 do
      begin
        Target := TargetList.Items[i];
        all := all + Target.Name + ',';
        if Target.PName <> '' then
          all := all + Target.PName + ',';
      end;
      SetLength(all, Length(all) - 1);

      Node := TJvSimpleXmlElemClassic.Create(nil);
      try
        Node.Properties.Add('name', 'all');
        Node.Properties.Add('value', all);
        AliasList.Add(TAlias.Create(Node));
      finally
        Node.Free;
      end;
    finally
      xml.Free;
    end;
  except
    on E: Exception do
    begin
      Result := False;
      ErrMsg := E.Message;
    end;
  end;
end;

function GetPersoTarget(const Target : string) : string;
begin
  if TargetList[Target] <> nil then
    Result := TargetList[Target].PName
  else
    Result := Target;
end;

function GetNonPersoTarget(const PersoTarget : string) : string;
var
  i : integer;
  Target : TTarget;
begin
  Result := PersoTarget;
  for i := 0 to TargetList.Count - 1 do
  begin
    Target := TargetList.Items[i];
    if SameText(Target.PName, PersoTarget) then
    begin
      Result := Target.Name;
      Break;
    end;
  end;
end;

function DirToTarget(const dir : string) : string;
var
  i : integer;
  Target : TTarget;
begin
  Result := '';
  for i := 0 to TargetList.Count - 1 do
  begin
    Target := TargetList.Items[i];
    if Target.Dir = dir then
    begin
      Result := Target.Name;
      Break;
    end
    else if Target.PDir = dir then
    begin
      Result := Target.Name;
      Break;
    end;
  end;
end;

function TargetToDir(const target : string) : string;
begin
  if Assigned(TargetList[target]) then
    Result := TargetList[target].Dir
  else if Assigned(TargetList[GetNonPersoTarget(target)]) then
    Result := TargetList[GetNonPersoTarget(target)].PDir
  else
    raise Exception.CreateFmt('Target "%s" not found.', [target]);
end;

function ExpandPackageName(Name: string; const target, prefix, format : string) : string;
var
  Env : string;
  Ver : string;
  Typ : string;
  formatGeneral : string;
  formatNoLibsuffix : string;
  ps: Integer;
begin
  // split the format string if there are two formats
  // this is done because Delphi 5 and under don't support
  // the LIBSUFFIX compilation directive. If such a target
  // is built, the second format will be used instead of
  // the first, thus allowing a different naming scheme
  formatGeneral := Format;
  ps := Pos(',', formatGeneral);
  if ps > 0 then
  begin
    formatNoLibsuffix := Copy(formatGeneral, ps+1, length(formatGeneral));
    Delete(formatGeneral, ps, MaxInt);
  end
  else
    formatNoLibsuffix := formatGeneral;

  Env := TargetList[GetNonPersoTarget(target)].Env;
  Ver := TargetList[GetNonPersoTarget(target)].Ver;
  Typ := Copy(Name, Length(Name), 1);
  Name := Copy(Name, Length(Prefix)+1, Pos('-', Name)-Length(Prefix)-1);

  if ((AnsiLowerCase(Env) = 'd') or (AnsiLowerCase(Env) = 'c')) and (Ver < '6') then
    Result := FormatNoLibSuffix
  else
    Result := FormatGeneral;

  if Pos('%', Result) > 0 then
  begin
    StrReplace(Result, '%p', Prefix, [rfReplaceAll]);
    StrReplace(Result, '%n', Name, [rfReplaceAll]);
    StrReplace(Result, '%e', Env, [rfReplaceAll]);
    StrReplace(Result, '%v', Ver, [rfReplaceAll]);
    StrReplace(Result, '%t', Typ, [rfReplaceAll]);
  end;
end;

function BuildPackageName(packageNode : TJvSimpleXmlElem;
  const target, prefix, Format : string) : string;
var
  Name : string;
begin
  Name := packageNode.Properties.ItemNamed['Name'].Value;
  if StartsWidth(Prefix, Name) and (Pos('-', Name) <> 0) then
  begin
    Result := ExpandPackageName(Name, target, prefix, Format);
  end
  else
  begin
    Result := Name;
  end;
end;

function IsNotInPerso(Node : TJvSimpleXmlElem; const target : string) : Boolean;
var
  persoTarget : string;
  targets : TStringList;
begin
  persoTarget := GetPersoTarget(target);
  if persoTarget = '' then
    Result := False
  else
  begin
    targets := TStringList.Create;
    try
      StrToStrings(Node.Properties.ItemNamed['Targets'].Value,
                   ',',
                   targets);
      Result := (targets.IndexOf(persoTarget) = -1) and
                (targets.IndexOf(target) > -1);
    finally
      targets.Free;
    end;
  end;
end;

function IsOnlyInPerso(Node : TJvSimpleXmlElem; const target : string) : Boolean;
var
  persoTarget : string;
  targets : TStringList;
begin
  persoTarget := GetPersoTarget(target);
  if persoTarget = '' then
    Result := False
  else
  begin
    targets := TStringList.Create;
    try
      StrToStrings(Node.Properties.ItemNamed['Targets'].Value,
                   ',',
                   targets);
      Result := (targets.IndexOf(persoTarget) > -1) and
                (targets.IndexOf(target) = -1);
    finally
      targets.Free;
    end;
  end;
end;

procedure EnsureCondition(lines: TStrings; Node : TJvSimpleXmlElem;
  const target : string);
var
  Condition : string;
begin
  Condition := Node.Properties.ItemNamed['Condition'].Value;
  // if there is a condition
  if (Condition <> '') then
  begin
    if Condition[1] <> '!' then
    begin
      // Only Delphi targets directly support conditions
      if (SameText(TargetList[GetNonPersoTarget(target)].Env, 'D')) then
      begin
        lines.Insert(0, '{$IFDEF ' + Condition + '}');
        lines.Add('{$ENDIF}');
      end
      // if we have a C++ Builder target, the only way to enforce the
      // condition is by looking for it in the DefinesList. If it
      // is there, the line is left untouched. If not, the line
      // is emptied, thus enforcing the absence of the condition
      else if (SameText(TargetList[GetNonPersoTarget(target)].Env, 'C')) then
      begin
        if not DefinesList.IsDefined(Condition, target) then
          lines.Clear;
      end;
      // The last possibility is a Kylix target and we are yet to decide
      // what to do with that. For now, don't touch the line
    end
    else
    begin
      // "not" condition
      Delete(Condition, 1, 1);

      // Only Delphi targets directly support conditions
      if (SameText(TargetList[GetNonPersoTarget(target)].Env, 'D')) then
      begin
        lines.Insert(0, '{$IFNDEF ' + Condition + '}');
        lines.Add('{$ENDIF}');
      end
      // if we have a C++ Builder target, the only way to enforce the
      // condition is by looking for it in the DefinesList. If it
      // is there, the line is left untouched. If not, the line
      // is emptied, thus enforcing the absence of the condition
      else if (SameText(TargetList[GetNonPersoTarget(target)].Env, 'C')) then
      begin
        if DefinesList.IsDefined(Condition, target) then
          lines.Clear;
      end;
      // The last possibility is a Kylix target and we are yet to decide
      // what to do with that. For now, don't touch the line
    end;
  end;
end;

function EnsurePFlagsCondition(const pflags, Target: string): string;
var
  PFlagsList : TStringList;
  I : Integer;
  CurPFlag : string;
  Condition : string;
  ParensPos : Integer;
begin
  // If any of the PFLAGS is followed by a string between parenthesis
  // then this is considered to be a condition.
  // If the condition is not in the Defines list, then the
  // corresponding PFLAG is discarded. This has been done mostly for
  // packages that have extended functionnality when USEJVCL is
  // activated and as such require the JCL dcp file.
  PFlagsList := TStringList.Create;
  Result := pflags;
  try
    StrToStrings(pflags, ' ', PFlagsList, False);
    for I := 0 to PFlagsList.Count-1 do
    begin
      CurPFlag := PFlagsList[I];
      ParensPos := Pos('(', CurPFlag);
      if ParensPos <> 0 then
      begin
        Condition := Copy(CurPFlag, ParensPos+1, Length(CurPFlag) - ParensPos -1);
        if not DefinesList.IsDefined(Condition, target)  then
          PFlagsList[I] := ''
        else
          PFlagsList[I] := Copy(CurPFlag, 1, ParensPos-1);
      end;
    end;
    Result := StringsToStr(PFlagsList, ' ', False);
  finally
    PFlagsList.Free;
  end;
end;

function GetUnitName(const FileName : string) : string;
begin
  Result := PathExtractFileNameNoExt(FileName);
end;

procedure EnsureProperSeparator(var Name : string; const target : string);
begin
  // ensure that the path separator stored in the xml file is
  // replaced by the one for the system we are targeting

  // first ensure we only have backslashes
  StrReplace(Name, '/', '\', [rfReplaceAll]);

  // and replace all them by the path separator for the target
  StrReplace(Name, '\', TargetList[GetNonPersoTarget(target)].PathSep, [rfReplaceAll]);
end;

procedure ApplyFormName(fileNode : TJvSimpleXmlElem; Lines : TStrings;
  const target : string);
var
  formName : string;
  formType : string;
  formNameAndType : string;
  incFileName : string;
  openPos : Integer;
  closePos : Integer;
  unitname : string;
  punitname : string;
  formpathname : string;
  S: string;
  ps: Integer;
begin
  formNameAndType := fileNode.Properties.ItemNamed['FormName'].Value;
  incFileName := fileNode.Properties.ItemNamed['Name'].Value;

  unitname := GetUnitName(incFileName);
  punitname := AnsiLowerCase(unitname);
  punitname[1] := CharUpper(punitname[1]);
  formpathname := StrEnsureSuffix(PathSeparator, ExtractFilePath(incFileName))+GetUnitName(incFileName);

  EnsureProperSeparator(formpathname, target);
  EnsureProperSeparator(incfilename, target);

  ps := Pos(':', formNameAndType);
  if ps = 0 then
  begin
    formName := formNameAndType;
    formType := '';
  end
  else
  begin
    formName := Copy(formNameAndType, 1, ps-1);
    formType := Copy(formNameAndType, ps+2, MaxInt);
  end;

  StrReplaceLines(Lines, '%FILENAME%', incFileName);
  StrReplaceLines(Lines, '%UNITNAME%', unitname);
  StrReplaceLines(Lines, '%Unitname%', punitname);

  if (formType = '') or (formName = '') then
  begin
    S := Lines.Text;
    openPos := Pos('/*', S);
    if openPos > 0 then
    begin
      closePos := Pos('*/', S);
      Delete(S, openPos, closepos + 2 - openPos);
      Lines.Text := S;
    end;
  end;

  if formName = '' then
  begin
    S := Lines.Text;
    openPos := Pos('{', S);
    if openPos > 0 then
    begin
      closePos := Pos('}', S);
      Delete(S, openPos, closePos + 1 - openPos);
      Lines.Text := S;
    end;
    StrReplaceLines(Lines, '%FORMNAME%', '');
    StrReplaceLines(Lines, '%FORMTYPE%', '');
    StrReplaceLines(Lines, '%FORMNAMEANDTYPE%', '');
    StrReplaceLines(Lines, '%FORMPATHNAME%', '');
  end
  else
  begin
    StrReplaceLines(Lines, '%FORMNAME%', formName);
    StrReplaceLines(Lines, '%FORMTYPE%', formType);
    StrReplaceLines(Lines, '%FORMNAMEANDTYPE%', formNameAndType);
    StrReplaceLines(Lines, '%FORMPATHNAME%', formpathname);
  end;
end;

procedure ExpandTargets(targets : TStrings);
var
  expandedTargets : TStringList;
  i : Integer;
  Alias : TAlias;
begin
  expandedTargets := TStringList.Create;
  try
    // ensure uniqueness in expanded list
    expandedTargets.Sorted := True;
// CaseSensitive doesn't exist in D5 and the default is False anyway
//    expandedTargets.CaseSensitive := False;
    expandedTargets.Duplicates := dupIgnore;

    for i := 0 to targets.Count - 1 do
    begin
      Alias := AliasList[targets[i]];
      if Assigned(Alias) then
        expandedTargets.AddStrings(Alias.ValueAsTStrings)
      else
        expandedTargets.Add(trim(targets[i]));
    end;

    // assign the values back into the caller
    targets.Clear;
    targets.Assign(expandedTargets);
  finally
    expandedTargets.Free;
  end;
end;

procedure ExpandTargetsNoPerso(targets : TStrings);
var
  i : integer;
begin
  ExpandTargets(targets);
  // now remove "perso" targets
  for i := targets.Count - 1 downto 0 do
  begin
    if not Assigned(TargetList.ItemsByName[targets[i]]) then
      targets.Delete(i);
  end;
end;

function IsIncluded(Node : TJvSimpleXmlElem; const target : string) : Boolean;
var
  targets : TStringList;
begin
  targets := TStringList.Create;
  try
    StrToStrings(Node.Properties.ItemNamed['Targets'].Value,
                 ',', targets);
    ExpandTargets(targets);
// CaseSensitive doesn't exist in D5 and the default is False anyway
//    targets.CaseSensitive := False;
    Result := (targets.IndexOf(target) > -1);
  finally
    targets.Free;
  end;
end;

function NowUTC : TDateTime;
var
  sysTime : TSystemTime;
  fileTime : TFileTime;
begin
  Windows.GetSystemTime(sysTime);
  Windows.SystemTimeToFileTime(sysTime, fileTime);
  Result := FileTimeToDateTime(fileTime);
end;

function FilesEqual(const FileName1, FileName2: string): Boolean;
const
  MaxBufSize = 65535;
var
  Stream1, Stream2: TFileStream;
  Buffer1, Buffer2: array[0..MaxBufSize - 1] of Byte;
  BufSize: Integer;
  Size: Integer;
begin
  Result := True;

  Stream1 := nil;
  Stream2 := nil;
  try
    Stream1 := TFileStream.Create(FileName1, fmOpenRead or fmShareDenyWrite);
    Stream2 := TFileStream.Create(FileName2, fmOpenRead or fmShareDenyWrite);

    Size := Stream1.Size;
    if Size <> Stream2.Size then
    begin
      Result := False;
      Exit;     // Note: the finally clause WILL be executed
    end;

    BufSize := MaxBufSize;
    while Size > 0 do
    begin
      if BufSize > Size then
        BufSize := Size;
      Dec(Size, BufSize);

      Stream1.Read(Buffer1[0], BufSize);
      Stream2.Read(Buffer2[0], BufSize);

      Result := CompareMem(@Buffer1[0], @Buffer2[0], BufSize);
      if not Result then
        Exit;    // Note: the finally clause WILL be executed
    end;
  finally
    Stream1.Free;
    Stream2.Free;
  end;
end;

function HasFileChanged(const OutFileName, TemplateFileName: string;
  OutLines: TStrings; TimeStampLine: Integer): Boolean;
var
  CurLines: TStrings;
begin
  Result := True;
  if not FileExists(OutFileName) then
    Exit;

  if OutLines.Count = 0 then
  begin
    // binary file -> compare files
    Result := not FilesEqual(OutFileName, TemplateFileName);
  end
  else
  begin
    // text file -> compare lines
    CurLines := TStringList.Create;
    try
      CurLines.LoadFromFile(OutFileName);

      if CurLines.Count <> OutLines.Count then
      begin
        Result := True;
        Exit;
      end;

      // Replace the time stamp line by the new one to ensure that this
      // won't break the comparison.
      if TimeStampLine > -1 then
        CurLines[TimeStampLine] := OutLines[TimeStampLine];

      Result := not CurLines.Equals(OutLines);
    finally
      CurLines.Free;
    end;
  end;
end;

{$IFNDEF COMPILER6_UP}
function FileSetDate(const Filename: string; FileAge:Integer):Integer;
var
   Handle: Integer;
begin
   Handle := FileOpen(Filename, fmOpenReadWrite);
   try
     Result := SysUtils.FileSetDate(Handle, FileAge);
   finally
     FileClose(Handle);
   end;
end;
{$ENDIF !COMPILER6_UP}

procedure AdjustEndingSemicolon(Lines: TStrings);
var
  S: string;
  Len: Integer;
begin
  if Lines.Count > 0 then
  begin
    S := Lines[Lines.Count - 1];
    Len := Length(S);
    if Len > 0 then
    begin
      if S[Len] = ',' then
      begin
        Delete(S, Len, 1);
        Lines[Lines.Count - 1] := S;
        //Lines.Add('');
      end;
    end;
  end;
end;

function ApplyTemplateAndSave(const path, target, package, extension,
  prefix, format : string; template : TStrings; xml : TJvSimpleXml;
  const templateName, xmlName : string; const mostRecentFileDate : TDateTime) : string;
var
  OutFileName : string;
  oneLetterType : string;
  reqPackName : string;
  incFileName : string;
  rootNode : TJvSimpleXmlElemClassic;
  requiredNode : TJvSimpleXmlElem;
  packageNode : TJvSimpleXmlElem;
  containsNode : TJvSimpleXmlElem;
  fileNode : TJvSimpleXmlElem;
  outFile : TStringList;
  curLine, curLineTrim : string;
  tmpLines, repeatLines : TStrings;
  I : Integer;
  j : Integer;
  tmpStr : string;
  bcbId : string;
  bcblibs : string;
  bcblibsList : TStringList;
  TimeStampLine : Integer;
  containsSomething : Boolean; // true if package will contain something
  repeatSectionUsed : Boolean; // true if at least one repeat section was used
begin
  outFile := TStringList.Create;
  bcblibsList := TStringList.Create;
  Result := '';
  containsSomething := False;
  repeatSectionUsed := False;

  repeatLines := TStringList.Create;
  tmpLines := TStringList.Create;
  try
    // read the xml file
    rootNode := xml.Root;
    OutFileName := rootNode.Properties.ItemNamed['Name'].Value;
    if rootNode.Properties.ItemNamed['Design'].BoolValue then
    begin
      OutFileName := OutFileName + '-D';
      oneLetterType := 'd';
    end
    else
    begin
      OutFileName := OutFileName + '-R';
      oneLetterType := 'r';
    end;

    OutFileName := path + TargetToDir(target) + PathSeparator +
                   ExpandPackageName(OutFileName, target, prefix, format)+
                   Extension;

    // The time stamp hasn't been found yet
    TimeStampLine := -1;

    // get the nodes
    requiredNode := rootNode.Items.ItemNamed['requires'];
    containsNode := rootNode.Items.ItemNamed['contains'];

    // read the lines of the templates and do some replacements
    i := 0;
    while i < template.Count do
    begin
      curLine := template[i];
      if IsTrimmedStartsWith('<%%% ', curLine) then
      begin
        curLineTrim := Trim(curLine);
        if curLine = '<%%% START REQUIRES %%%>' then
        begin
          Inc(i);
          repeatSectionUsed := True;
          repeatLines.Clear;
          while (i < template.count) and
                not IsTrimmedString(template[i], '<%%% END REQUIRES %%%>') do
          begin
            repeatLines.Add(template[i]);
            Inc(i);
          end;
          for j := 0 to requiredNode.Items.Count -1 do
          begin
            packageNode := requiredNode.Items[j];
            // if this required package is to be included for this target
            if IsIncluded(packageNode, target) then
            begin
              tmpLines.Assign(repeatLines);
              reqPackName := BuildPackageName(packageNode, target, prefix, format);
              StrReplaceLines(tmpLines, '%NAME%', reqPackName);
              // We do not say that the package contains something because
              // a package is only interesting if it contains files for
              // the given target
              // containsSomething := True;
              EnsureCondition(tmpLines, packageNode, target);
              outFile.AddStrings(tmpLines);
            end;
          end;

          // if the last character in the output file is
          // a comma, then remove it. This possible comma will
          // be followed by a carriage return so we look
          // at the third character starting from the end
          AdjustEndingSemicolon(outFile);
        end
        else if curLineTrim = '<%%% START FILES %%%>' then
        begin
          Inc(i);
          repeatSectionUsed := True;
          repeatLines.Clear;
          while (i < template.count) and
                not IsTrimmedString(template[i], '<%%% END FILES %%%>') do
          begin
            repeatLines.Add(template[i]);
            Inc(i);
          end;

          for j := 0 to containsNode.Items.Count -1 do
          begin
            fileNode := containsNode.Items[j];
            // if this included file is to be included for this target
            if IsIncluded(fileNode, target) then
            begin
              tmpLines.Assign(repeatLines);
              incFileName := fileNode.Properties.ItemNamed['Name'].Value;
              ApplyFormName(fileNode, tmpLines, target);
              containsSomething := True;
              EnsureCondition(tmpLines, fileNode, target);
              outFile.AddStrings(tmpLines)
            end;
          end;

          // if the last character in the output file is
          // a comma, then remove it. This possible comma will
          // be followed by a carriage return so we look
          // at the third character starting from the end
          AdjustEndingSemicolon(outFile);
        end
        else if curLine = '<%%% START FORMS %%%>' then
        begin
          Inc(i);
          repeatSectionUsed := True;
          repeatLines.Clear;
          while (i < template.count) and
                not IsTrimmedString(template[i], '<%%% END FORMS %%%>') do
          begin
            repeatLines.Add(template[i]);
            Inc(i);
          end;

          for j := 0 to containsNode.Items.Count -1 do
          begin
            fileNode := containsNode.Items[j];
            // if this included file is to be included for this target
            // and there is a form associated to the file
            if IsIncluded(fileNode, target) then
            begin
              containsSomething := True;
              if (fileNode.Properties.ItemNamed['FormName'].Value <> '') then
              begin
                tmpLines.Assign(repeatLines);
                ApplyFormName(fileNode, tmpLines, target);
                EnsureCondition(tmpLines, fileNode, target);
                outFile.AddStrings(tmpLines);
              end;
            end;

            // if this included file is not in the associated 'perso'
            // target or only in the 'perso' target then return the
            // 'perso' target name. 
            if IsNotInPerso(fileNode, target) or
               IsOnlyInPerso(fileNode, target) then
              Result := GetPersoTarget(target);
          end;
        end
        else if curLine = '<%%% START LIBS %%%>' then
        begin
          Inc(i);
          repeatLines.Clear;
          while (i < template.count) and
                not IsTrimmedString(template[i], '<%%% END LIBS %%%>') do
          begin
            repeatLines.Add(template[i]);
            Inc(i);
          end;

          // read libs as a string of comma separated value
          bcbId := TargetList[GetNonPersoTarget(target)].Env+TargetList[GetNonPersoTarget(target)].Ver;
          bcblibs :=  rootNode.Items.ItemNamed[bcbId+'Libs'].Value;
          if bcblibs <> '' then
          begin
            StrToStrings(bcblibs, ',', bcblibsList);
            for j := 0 to bcbLibsList.Count - 1 do
            begin
              tmpLines.Assign(repeatLines);
              StrReplaceLines(tmpLines, '%FILENAME%', bcblibsList[j]);
              StrReplaceLines(tmpLines, '%UNITNAME%', GetUnitName(bcblibsList[j]));
              outFile.AddStrings(tmpLines);
            end;
          end;
        end
      end
      else
      begin
        if Pos('%', curLine) > 0 then
        begin
          if Pos('%DATETIME%', curLine) > 0 then
            TimeStampLine := I;

          StrReplace(curLine, '%NAME%',
                     PathExtractFileNameNoExt(OutFileName),
                     [rfReplaceAll]);
          StrReplace(curLine, '%XMLNAME%',
                     ExtractFileName(xmlName),
                     [rfReplaceAll]);
          StrReplace(curLine, '%DESCRIPTION%',
                     rootNode.Items.ItemNamed['Description'].Value,
                     [rfReplaceAll]);
          StrReplace(curLine, '%C5PFLAGS%',
                     EnsurePFlagsCondition(
                       rootNode.Items.ItemNamed['C5PFlags'].Value, target
                       ),
                     [rfReplaceAll]);
          StrReplace(curLine, '%C6PFLAGS%',
                     EnsurePFlagsCondition(
                       rootNode.Items.ItemNamed['C6PFlags'].Value, target
                       ),
                     [rfReplaceAll]);
          StrReplace(curLine, '%TYPE%',
                     Iff(rootNode.Properties.ItemNamed['Design'].BoolValue,
                        'DESIGN', 'RUN'),
                     [rfReplaceAll]);
          StrReplace(curLine, '%DATETIME%',
                      FormatDateTime('dd-mm-yyyy  hh:nn:ss', NowUTC) + ' UTC',
                      [rfReplaceAll]);
          StrReplace(curLine, '%type%', OneLetterType, [rfReplaceAll]);
        end;
        outFile.Add(curLine);
      end;
      Inc(i);
    end;

    // test if there are required packages and/or contained files
    // that make the package require a different version for a
    // perso target. This is determined like that:
    // if a file is not in the associated 'perso'
    // target or only in the 'perso' target then return the
    // 'perso' target name.
    for j := 0 to requiredNode.Items.Count -1 do
    begin
      packageNode := requiredNode.Items[j];
      if IsNotInPerso(packageNode, target) or
         IsOnlyInPerso(packageNode, target) then
        Result := GetPersoTarget(target);
    end;
    for j := 0 to containsNode.Items.Count -1 do
    begin
      fileNode := containsNode.Items[j];
      if IsNotInPerso(fileNode, target) or
         IsOnlyInPerso(fileNode, target) then
        Result := GetPersoTarget(target);
    end;

    // if no repeat section was used, we must check manually
    // that at least one file is to be used by the given target.
    // This will then force the generation of the output file
    // (Useful for cfg templates for instance).
    // We do not check for the use of "required" packages because
    // a package is only interesting if it contains files for
    // the given target
    if not repeatSectionUsed then
    begin
      for j := 0 to containsNode.Items.Count -1 do
        if IsIncluded(containsNode.Items[j], target) then
        begin
          containsSomething := True;
          Break;
        end;
    end;

    // Save the file, if it contains something, and it
    // has changed when compared with the existing one
    if containsSomething and
       (HasFileChanged(OutFileName, templateName, outFile, TimeStampLine)) then
    begin
      tmpStr := ExtractFilePath(templateName);
      if tmpStr[length(tmpStr)] = PathSeparator then
        SetLength(tmpStr, length(tmpStr)-1);
      if ExtractFileName(tmpStr) = TargetList[GetNonPersoTarget(target)].PDir then
        SendMsg(SysUtils.Format(#9#9'Writing %s for %s (%s template used)', [ExtractFileName(OutFileName), target, target]))
      else
        SendMsg(SysUtils.Format(#9#9'Writing %s for %s', [ExtractFileName(OutFileName), target]));

      // if outfile contains line, save it.
      // else, it's because the template file was a binary file, so simply
      // copy it to the destination name
      if outFile.count > 0 then
        outFile.SaveToFile(OutFileName)
      else
      begin
        CopyFile(PChar(templateName), PChar(OutFileName), False);
        FileSetDate(OutFileName, DateTimeToFileDate(Now)); // adjust file time
      end;
    end;
  finally
    tmpLines.Free;
    repeatLines.Free;
    bcblibsList.Free;
    outFile.Free;
  end;
end;

function Max(d1, d2 : TDateTime): TDateTime;
begin
  if d1 > d2 then
    Result := d1
  else
    Result := d2;
end;

function IsBinaryFile(const Filename: string): Boolean;
const
  BufferSize = 50;
  BinaryPercent = 10;
var
  F : TFileStream;
  Buffer : array[0..BufferSize] of Char;
  I : Integer;
  BinaryCount : Integer;
begin
  Result := False;
  // If the cache contains information on that file, get the result
  // from it and skip the real test
  if IsBinaryCache.IndexOf(FileName) > -1 then
  begin
    Result := Boolean(IsBinaryCache.Objects[IsBinaryCache.IndexOf(FileName)]);
    Exit;
  end;

  // Read the first characters of the file and if enough of them
  // are not text characters, then consider the file to be binary
  if FileExists(FileName) then
  begin
    F := TFileStream.Create(FileName, fmOpenRead);
    try
      F.Read(Buffer, BufferSize+1);
      BinaryCount := 0;
      for I := 0 to BufferSize do
        if not (Buffer[I] in [#9, #13, #10, #32..#127]) then
          Inc(BinaryCount);

      Result := BinaryCount > BufferSize * BinaryPercent div 100;
    finally
      F.Free;
    end;
  end;

  // save the result in the cache
  IsBinaryCache.AddObject(FileName, TObject(Result));
end;

function Generate(packages : TStrings;
                   targets : TStrings;
                   callback : TGenerateCallback;
                   const XmlFileName : string;
                   const ModelName : string;
                   var ErrMsg : string;
                   makeDof : Boolean = False;
                   path : string = '';
                   prefix : string = '';
                   format : string = '';
                   incfileName : string = ''
                  ) : Boolean;
var
  rec : TSearchRec;
  i : Integer;
  j : Integer;
  templateName : string;
  xml : TJvSimpleXml;
  xmlName : string;
  template : TStringList;
  persoTarget : string;
  target : string;

  mostRecentFileDate : TDateTime;

  incfile : TStringList;

  XmlFileCache: TObjectList;

  function GetXmlFile(const xmlName: string): TJvSimpleXML;
  var
    i: Integer;
  begin
    for i := 0 to XmlFileCache.Count - 1 do
    begin
      Result := TJvSimpleXML(XmlFileCache[i]);
      if Result.FileName = xmlName then
        Exit;
    end;
    Result := TJvSimpleXML.Create(nil);
    XmlFileCache.Add(Result);

    Result.Options := [sxoAutoCreate];
    Result.Filename := xmlName; // load file
  end;

begin
  mostRecentFileDate := 0;
  Result := True;
  if not LoadConfig(XmlFileName, ModelName, ErrMsg) then
  begin
    Result := False;
    Exit;
  end;

  // Empty the binary file cache
  IsBinaryCache.Clear;

  FreeAndNil(DefinesList);
  if incFileName = '' then
    incFileName := GIncFileName;
  // read the include file
  incfile := TStringList.Create;
  try
    if FileExists(IncFileName) then
    begin
      incfile.LoadFromFile(IncFileName);
      mostRecentFileDate := FileDateToDateTime(FileAge(IncFileName));
    end;
    DefinesList := TDefinesList.Create(incfile);
  finally
    incfile.free;
  end;

  GCallBack := CallBack;

  if path = '' then
  begin
    if PathIsAbsolute(PackagesLocation) then
      path := PackagesLocation
    else
      path := PathNoInsideRelative(StrEnsureSuffix(PathSeparator, StartupDir) + PackagesLocation);
  end;

  path := StrEnsureSuffix(PathSeparator, path);

  if prefix = '' then
    Prefix := GPrefix;
  if format = '' then
    Format := GFormat;

  XmlFileCache := TObjectList.Create;
  try
    // for all targets
    for i := 0 to targets.Count - 1 do
    begin
      target := targets[i];
      SendMsg(SysUtils.Format('Generating packages for %s', [target]));
      // find all template files for that target
      if FindFirst(path+TargetToDir(target)+PathSeparator+'template.*', 0, rec) = 0 then
      begin
        repeat
          template := TStringList.Create;
          try
            SendMsg(SysUtils.Format(#9'Loaded %s', [rec.Name]));
            // apply the template for all packages
            for j := 0 to packages.Count-1 do
            begin
              templateName := path+TargetToDir(target)+PathSeparator+rec.Name;
              if IsBinaryFile(templateName) then
                template.Clear
              else
                template.LoadFromFile(templateName);
              mostRecentFileDate := Max(mostRecentFileDate, FileDateToDateTime(FileAge(templateName)));

             // load (buffered) xml file 
              xmlName := path+'xml'+PathSeparator+packages[j]+'.xml';
              xml := GetXmlFile(xmlName);

              mostRecentFileDate := Max(mostRecentFileDate, FileDateToDateTime(FileAge(xmlName)));
              persoTarget := ApplyTemplateAndSave(
                                   path,
                                   target,
                                   packages[j],
                                   ExtractFileExt(rec.Name),
                                   prefix,
                                   Format,
                                   template,
                                   xml,
                                   templateName,
                                   xmlName,
                                   mostRecentFileDate);

              // if the generation requested a perso target to be done
              // then generate it now. If we find a template file
              // named the same as the current one in the perso
              // directory then use it instead
              if (persoTarget <> '') and
                 DirectoryExists(path+TargetToDir(persoTarget)) then
              begin
                if FileExists(path+TargetToDir(persoTarget)+PathSeparator+rec.Name) then
                begin
                  templateName := path+TargetToDir(persoTarget)+PathSeparator+rec.Name;
                  if IsBinaryFile(templateName) then
                    template.Clear
                  else
                    template.LoadFromFile(templateName);
                  mostRecentFileDate := Max(mostRecentFileDate, FileDateToDateTime(FileAge(templateName)));
                end;

                ApplyTemplateAndSave(
                   path,
                   persoTarget,
                   packages[j],
                   ExtractFileExt(rec.Name),
                   prefix,
                   Format,
                   template,
                   xml,
                   templateName,
                   xmlName,
                   mostRecentFileDate);
              end;
            end;
          finally
            template.Free;
          end;
        until FindNext(rec) <> 0;
      end
      else
        SendMsg(SysUtils.Format(#9'No template found for %s' , [target]));
      FindClose(rec);
    end;
  finally
    XmlFileCache.Free;
  end;

  if makeDof then
  begin
    SendMsg('Calling MakeDofs.bat');
    ShellExecute(0,
                '',
                PChar(StrEnsureSuffix(PathSeparator, ExtractFilePath(ParamStr(0))) + 'MakeDofs.bat'),
                '',
                PChar(ExtractFilePath(ParamStr(0))),
                SW_SHOW);
  end;
end;

procedure EnumerateTargets(targets : TStrings);
var
  i : integer;
begin
  targets.clear;
  for i := 0 to TargetList.Count - 1 do
  begin
    targets.Add(TargetList.Items[I].Name);
  end;
end;

procedure EnumeratePackages(const Path : string; packages : TStrings);
var
  rec : TSearchRec;
begin
  packages.Clear;
  if FindFirst(StrEnsureSuffix(PathSeparator, path) +'xml'+PathSeparator+'*.xml', 0, rec) = 0 then
  begin
    repeat
      packages.Add(PathExtractFileNameNoExt(rec.Name));
    until FindNext(rec) <> 0;
  end;
  FindClose(rec);
end;

{ TTarget }

constructor TTarget.Create(Node: TJvSimpleXmlElem);
begin
  inherited Create;
  FName := AnsiLowerCase(Node.Properties.ItemNamed['name'].Value);
  if Assigned(Node.Properties.ItemNamed['dir']) then
    FDir := Node.Properties.ItemNamed['dir'].Value;
  if Assigned(Node.Properties.ItemNamed['pname']) then
    FPName := AnsiLowerCase(Node.Properties.ItemNamed['pname'].Value);
  if Assigned(Node.Properties.ItemNamed['pdir']) then
    FPDir := Node.Properties.ItemNamed['pdir'].Value;
  if Assigned(Node.Properties.ItemNamed['env']) then
    FEnv := AnsiUpperCase(Node.Properties.ItemNamed['env'].Value)[1];
  if Assigned(Node.Properties.ItemNamed['ver']) then
    FVer := AnsiLowerCase(Node.Properties.ItemNamed['ver'].Value)[1];

  FDefines := TStringList.Create;
  if Assigned(Node.Properties.ItemNamed['defines']) then
    StrToStrings(Node.Properties.ItemNamed['defines'].Value,
                 ',',
                 FDefines,
                 False);

  FPathSep := '\';
  if Assigned(Node.Properties.ItemNamed['pathsep']) then
    FPathSep := Node.Properties.ItemNamed['pathsep'].Value;
end;

destructor TTarget.Destroy;
begin
  FDefines.Free;
  inherited Destroy;
end;

function TTarget.GetDir: string;
begin
  if FDir <> '' then
    Result := FDir
  else
    Result := Name;
end;

function TTarget.GetEnv: string;
begin
  if FEnv <> '' then
    Result := FEnv
  else
    Result := AnsiUpperCase(Name[1]);
end;

function TTarget.GetPDir: string;
begin
  if FPDir <> '' then
    Result := FPDir
  else
    Result := FPName;
end;

function TTarget.GetVer: string;
begin
  if FVer <> '' then
    Result := FVer
  else if Length(Name)>1 then
    Result := AnsiLowerCase(Name[2])
  else
    Result := '';
end;

{ TTargetList }

constructor TTargetList.Create(Node: TJvSimpleXmlElem);
var
  i : integer;
begin
  inherited Create(True);
  if Assigned(Node) then
    for i := 0 to Node.Items.Count - 1 do
    begin
      Add(TTarget.Create(Node.Items[i]));
    end;
end;

function TTargetList.GetItems(index: integer): TTarget;
begin
  Result := TTarget(inherited Items[index]);
end;

function TTargetList.GetItemsByName(name: string): TTarget;
var
  i : integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if SameText(TTarget(Items[i]).Name, name) then
    begin
      Result := TTarget(Items[i]);
      Break;
    end;
end;

procedure TTargetList.SetItems(index: integer; const Value: TTarget);
begin
  inherited Items[index] := Value;
end;

{ TAlias }

constructor TAlias.Create(Node: TJvSimpleXmlElem);
begin
  inherited Create;
  FName := AnsiLowerCase(Node.Properties.ItemNamed['name'].Value);
  FValue := AnsiLowerCase(Node.Properties.ItemNamed['value'].Value);
  FValueAsTStrings := nil;
end;

destructor TAlias.Destroy;
begin
  FValueAsTStrings.Free;
  inherited Destroy;
end;

function TAlias.GetValueAsTStrings: TStrings;
begin
  if not Assigned(FValueAsTStrings) then
    FValueAsTStrings := TStringList.Create;

  StrToStrings(Value, ',', FValueAsTStrings, false);
  Result := FValueAsTStrings;
end;

{ TAliasList }

constructor TAliasList.Create(Node: TJvSimpleXmlElem);
var
  i : integer;
begin
  inherited Create(True);
  if Assigned(Node) then
    for i := 0 to Node.Items.Count - 1 do
    begin
      Add(TAlias.Create(Node.Items[i]));
    end;
end;

function TAliasList.GetItems(index: integer): TAlias;
begin
  Result := TAlias(inherited Items[index]);
end;

function TAliasList.GetItemsByName(name: string): TAlias;
var
  i : integer;
begin
  Result := nil;
  for i := 0 to Count - 1 do
    if SameText(TAlias(Items[i]).Name, name) then
    begin
      Result := TAlias(Items[i]);
      Break;
    end;
end;

procedure TAliasList.SetItems(index: integer; const Value: TAlias);
begin
  inherited Items[index] := Value;
end;

{ TDefine }

constructor TDefine.Create(const Name : string; IfDefs : TStringList);
begin
  inherited Create;

  FName := Name;
  FIfDefs := TStringList.Create;
  FIfDefs.Assign(IfDefs);
end;

destructor TDefine.Destroy;
begin
  FIfDefs.Free;
  
  inherited Destroy;
end;

{ TDefinesList }

constructor TDefinesList.Create(incfile: TStringList);
const
  IfDefMarker  : string = '{$IFDEF';
  IfNDefMarker : string = '{$IFNDEF';
  EndIfMarker  : string = '{$ENDIF';
  ElseMarker   : string = '{$ELSE';
  DefineMarker : string = '{$DEFINE';
var
  i: Integer;
  curLine: string;
  IfDefs : TStringList;
begin
  inherited Create(True);

  IfDefs := TStringList.Create;
  try
    if Assigned(incfile) then
      for i := 0 to incfile.Count - 1 do
      begin
        curLine := Trim(incfile[i]);

        if StrHasPrefix(curLine, [IfDefMarker]) then
          IfDefs.AddObject(Copy(curLine, Length(IfDefMarker)+2, Length(curLine)-Length(IfDefMarker)-2), TObject(True))
        else if StrHasPrefix(curLine, [IfNDefMarker]) then
          IfDefs.AddObject(Copy(curLine, Length(IfNDefMarker)+2, Length(curLine)-Length(IfNDefMarker)-2), TObject(False))
        else if StrHasPrefix(curLine, [ElseMarker]) then
          IfDefs.Objects[IfDefs.Count-1] := TObject(not Boolean(IfDefs.Objects[IfDefs.Count-1]))
        else if StrHasPrefix(curLine, [EndIfMarker]) then
          IfDefs.Delete(IfDefs.Count-1)
        else if StrHasPrefix(curLine, [DefineMarker]) then
          Add(TDefine.Create(Copy(curLine, Length(DefineMarker)+2, Length(curLine)-Length(DefineMarker)-2), IfDefs));
      end;
  finally
    IfDefs.Free;
  end;
end;

function TDefinesList.GetItems(index: integer): TDefine;
begin
  Result := TDefine(inherited Items[index]);
end;

function TDefinesList.IsDefined(const Condition, Target : string;
  DefineLimit : Integer = -1): Boolean;
var
  I : Integer;
  Define : TDefine;
begin
  if DefineLimit = -1 then
    DefineLimit := Count
  else
  if DefineLimit > Count then
    DefineLimit := Count;

  Result := False;
  Define := nil;
  for i := 0 to DefineLimit - 1 do
  begin
    if CompareText(Items[I].Name, Condition) = 0 then
    begin
      Result := True;
      Define := Items[I];
      Break;
    end;
  end;

  // If the condition is not defined by its name, maybe it
  // is as a consequence of the target we use
  if not Result then
    Result := TargetList[GetNonPersoTarget(Target)].Defines.IndexOf(Condition) > -1;

  // If the condition is defined, then all the IfDefs in which
  // it is enclosed must also be defined but only before the
  // current define
  if Result and Assigned(Define) then
    for I := 0 to Define.IfDefs.Count - 1 do
    begin
      if Boolean(Define.IfDefs.Objects[I]) then
        Result := Result and IsDefined(Define.IfDefs[I], Target, IndexOf(Define))
      else
        Result := Result and not IsDefined(Define.IfDefs[I], Target, IndexOf(Define));
    end
end;

procedure TDefinesList.SetItems(index: integer; const Value: TDefine);
begin
  inherited Items[index] := Value;
end;

initialization
  StartupDir := GetCurrentDir;

  IsBinaryCache := TStringList.Create;

// ensure the lists are not assigned
  TargetList := nil;
  AliasList := nil;
  DefinesList := nil;

finalization
  TargetList.Free;
  AliasList.Free;
  DefinesList.Free;
  IsBinaryCache.Free;

end.
