unit Store.Config;

interface

uses
  Store.Intf,
  System.SysUtils, System.SyncObjs, System.Generics.Collections;

type
  TStoreConfig<T> = class
  private
    FCriticalSection: TCriticalSection;
    FDictionary: TDictionary<string, T>;
    FConfig: T;

    procedure SetConfig(const AId: string; const AConfig: T);

    class var FInstance: TStoreConfig<T>;
  public
    constructor Create();
    destructor Destroy; override;

    function GetDictionary: TDictionary<string, T>;
    procedure Save(const AId: string);

    property Config: T read FConfig write FConfig;

    class function New(const AId: string; const AConfig: T): TStoreConfig<T>;
    class destructor UnInitialize;
  end;

implementation

{ TStoreConfig }

constructor TStoreConfig<T>.Create();
begin
  if Assigned(FInstance) then
    raise Exception.Create('The TStoreConfig instance has already been created!');

  FCriticalSection := TCriticalSection.Create;
  FDictionary := TDictionary<string, T>.Create;
end;

destructor TStoreConfig<T>.Destroy;
begin
  FreeAndNil(FDictionary);
  FreeAndNil(FCriticalSection);
end;

class function TStoreConfig<T>.New(const AId: string; const AConfig: T): TStoreConfig<T>;
begin
  if not(Assigned(FInstance)) then
    FInstance := TStoreConfig<T>.Create();

  FInstance.SetConfig(AId, AConfig);

  Result := FInstance;
end;

class destructor TStoreConfig<T>.UnInitialize;
begin
  if Assigned(FInstance) then
    FreeAndNil(FInstance);
end;

procedure TStoreConfig<T>.Save(const AId: string);
begin
  FCriticalSection.Enter;
  try
    FDictionary.AddOrSetValue(AId, FConfig);
  finally
    FCriticalSection.Leave;
  end;
end;

function TStoreConfig<T>.GetDictionary: TDictionary<string, T>;
begin
  Result := FDictionary;
end;

procedure TStoreConfig<T>.SetConfig(const AId: string; const AConfig: T);
var
  LConfig: T;
begin
  FCriticalSection.Enter;
  try
    if not(FDictionary.TryGetValue(AId, LConfig)) then
    begin
      FDictionary.Add(AId, AConfig);
      LConfig := AConfig;
    end;
  finally
    FCriticalSection.Leave;
  end;

  FConfig := LConfig;
end;

end.
