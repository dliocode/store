unit Store.Memory;

interface

uses
  Store.Intf, Store.Lib.Memory,
  System.Generics.Collections, System.SysUtils, System.DateUtils, System.SyncObjs;

type
  TMemoryStore = class(TInterfacedObject, IStore)
  private
    FTimeout: Integer;
    FList: TMemoryDictionary<TMemory>;

    class var CriticalSection: TCriticalSection;

    function ResetKey(ADateTime: TDateTime): Boolean;
    procedure CleanMemory;
  public
    constructor Create(const ATimeout: Integer);
    destructor Destroy; override;

    function Incr(const AKey: string): TStoreCallback;
    procedure Decrement(const AKey: string);
    procedure ResetAll();
    procedure SetTimeout(const ATimeout: Integer);

    class function New(const ATimeout: Integer): TMemoryStore; overload;
    class function New(): TMemoryStore; overload;
  end;

implementation

{ TMemoryStore }

constructor TMemoryStore.Create(const ATimeout: Integer);
begin
  FList := TMemoryDictionary<TMemory>.Create;
  FTimeout := ATimeout;
end;

destructor TMemoryStore.Destroy;
begin
  FreeAndNil(FList);
end;

class function TMemoryStore.New(const ATimeout: Integer): TMemoryStore;
begin
  Result := Create(ATimeout);
end;

class function TMemoryStore.New: TMemoryStore;
begin
  Result := Create(0);
end;

function TMemoryStore.Incr(const AKey: string): TStoreCallback;
var
  LMemory: TMemory;
begin
  CriticalSection.Enter;
  try
    if not(FList.TryGetValue(AKey, LMemory)) then
    begin
      LMemory.Count := 0;
      LMemory.DateTime := IncSecond(Now(), FTimeout);

      FList.Add(AKey, LMemory);
    end;
  finally
    CriticalSection.Leave;
  end;

  if not(ResetKey(LMemory.DateTime)) then
  begin
    Inc(LMemory.Count);

    CriticalSection.Enter;
    try
      FList.AddOrSetValue(AKey, LMemory);
    finally
      CriticalSection.Leave;
    end;

    Result.Current := LMemory.Count;
    Result.ResetTime := LMemory.DateTime - Now();
  end
  else
  begin
    CriticalSection.Enter;
    try
      FList.Remove(AKey);
    finally
      CriticalSection.Leave;
    end;

    Result := Incr(AKey);
    CleanMemory;
  end;
end;

procedure TMemoryStore.Decrement(const AKey: string);
var
  LMemory: TMemory;
begin
  LMemory.Count := 1;
  LMemory.DateTime := IncSecond(Now(), FTimeout);

  CriticalSection.Enter;
  try
    FList.AddOrSetValue(AKey, LMemory);
  finally
    CriticalSection.Leave;
  end;

  if not(ResetKey(LMemory.DateTime)) then
  begin
    Dec(LMemory.Count);

    if (LMemory.Count < 0) then
      LMemory.Count := 0;

    CriticalSection.Enter;
    try
      FList.AddOrSetValue(AKey, LMemory);
    finally
      CriticalSection.Leave;
    end;
  end
  else
  begin
    CriticalSection.Enter;
    try
      FList.Remove(AKey);
    finally
      CriticalSection.Leave;
    end;

    Decrement(AKey);
    CleanMemory;
  end;
end;

procedure TMemoryStore.ResetAll();
begin
  CriticalSection.Enter;
  try
    FList.Clear
  finally
    CriticalSection.Leave;
  end;
end;

procedure TMemoryStore.SetTimeout(const ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TMemoryStore.ResetKey(ADateTime: TDateTime): Boolean;
begin
  Result := Now() > ADateTime;
end;

procedure TMemoryStore.CleanMemory;
var
  LList: TPair<string, TMemory>;
begin
  for LList in FList.Get do
    if ResetKey(LList.Value.DateTime) then
    begin
      CriticalSection.Enter;
      try
        FList.Remove(LList.Key);
      finally
        CriticalSection.Leave;
      end;
    end;
end;

initialization

TMemoryStore.CriticalSection := TCriticalSection.Create;

finalization

FreeAndNil(TMemoryStore.CriticalSection);

end.
