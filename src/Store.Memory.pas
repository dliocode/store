unit Store.Memory;

interface

uses
  Store.Intf, Store.Lib.Memory,
  System.Generics.Collections, System.SysUtils,
  System.DateUtils;

type
  TMemoryStore = class(TInterfacedObject, IStore)
  private
    FTimeout: Integer;
    FList: TMemoryDictionary<TMemory>;
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
  FList.Free;
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
  if not(FList.TryGetValue(AKey, LMemory)) then
  begin
    LMemory.Count := 0;
    LMemory.DateTime := IncSecond(Now(), FTimeout);

    FList.Add(AKey, LMemory);
  end;

  if not(ResetKey(LMemory.DateTime)) then
  begin
    Inc(LMemory.Count);
    FList.Remove(AKey);
    FList.Add(AKey, LMemory);
    Result.Current := LMemory.Count;
    Result.ResetTime := LMemory.DateTime - Now();
  end
  else
  begin
    FList.Remove(AKey);
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

  FList.AddOrSetValue(AKey, LMemory);

  if not(ResetKey(LMemory.DateTime)) then
  begin
    Dec(LMemory.Count);

    if (LMemory.Count < 0) then
      LMemory.Count := 0;

    FList.Remove(AKey);
    FList.Add(AKey, LMemory);
  end
  else
  begin
    FList.Remove(AKey);
    Decrement(AKey);
    CleanMemory;
  end;
end;

procedure TMemoryStore.ResetAll();
begin
  FList.Clear
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
      FList.Remove(LList.Key);
end;

end.
