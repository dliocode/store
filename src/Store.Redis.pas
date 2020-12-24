unit Store.Redis;


interface

uses
  Store.Intf,
  Redis.Client, Redis.Values, Redis.NetLib.INDY, Redis.Commons,
  System.SysUtils, System.DateUtils, System.SyncObjs;

type
  TRedisStore = class(TInterfacedObject, IStore)
  private
    FRedis: TRedisClient;
    FConnected: Boolean;
    FHost: string;
    FPort: Integer;
    FClientName: string;
    FTimeout: Integer;

    procedure Connect;
    procedure Disconnect;

    class var CriticalSection: TCriticalSection;
  public
    function Incr(const AKey: string): TStoreCallback;
    procedure Decrement(const AKey: string);
    procedure ResetAll();
    procedure SetTimeout(const ATimeout: Integer);

    constructor Create(const AHost: string = '127.0.0.1'; const APort: Integer = 6379; const AClientName: string = ''); overload;
    destructor Destroy; override;

    class function New(const AHost: string = '127.0.0.1'; const APort: Integer = 6379; const AClientName: string = ''): TRedisStore; overload;
  end;

implementation

{ TRedisStore }

constructor TRedisStore.Create(const AHost: string = '127.0.0.1'; const APort: Integer = 6379; const AClientName: string = '');
begin
  FConnected := False;
  FClientName := AClientName;
  FHost := AHost;
  FPort := APort;

  FRedis := TRedisClient.Create(AHost, APort);
end;

destructor TRedisStore.Destroy;
begin
  Disconnect;
  FreeAndNil(FRedis);
  inherited;
end;

class function TRedisStore.New(const AHost: string; const APort: Integer; const AClientName: string): TRedisStore;
begin
  Result := Create(AHost, APort, AClientName);
end;

function TRedisStore.Incr(const AKey: string): TStoreCallback;
var
  LINCR: Integer;
  LTTL: Integer;
begin
  CriticalSection.Enter;
  try
    Connect;

    LINCR := FRedis.Incr(AKey);
    LTTL := FRedis.TTL(AKey);

    if LTTL = -1 then
    begin
      FRedis.EXPIRE(AKey, FTimeout);
      LTTL := FRedis.TTL(AKey);
    end;
  finally
    CriticalSection.Leave;
  end;

  Result.Current := LINCR;
  Result.ResetTime := IncSecond(Now(), LTTL);
end;

procedure TRedisStore.Decrement(const AKey: string);
var
  LTTL: Integer;
begin
  CriticalSection.Enter;
  try
    Connect;

    FRedis.DECR(AKey);
    LTTL := FRedis.TTL(AKey);

    if LTTL = -1 then
      FRedis.EXPIRE(AKey, FTimeout);
  finally
    CriticalSection.Leave;
  end;
end;

procedure TRedisStore.ResetAll;
begin
  CriticalSection.Enter;
  try
    Connect;
    FRedis.FLUSHALL;
  finally
    CriticalSection.Leave;
  end;
end;

procedure TRedisStore.SetTimeout(const ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

procedure TRedisStore.Connect;
begin
  try
    if not FConnected then
    begin
      FRedis.Connect;

      if not FClientName.Trim.IsEmpty then
        FRedis.ClientSetName(FClientName);
    end;
  except
    on E: Exception do
    begin
      FConnected := False;
      raise Exception.Create('Erro: Connection in Redis. Message: ' + E.Message);
    end;
  end;

  FConnected := True;
end;

procedure TRedisStore.Disconnect;
begin
  try
    if FConnected then
      FRedis.Disconnect;
  except
    on E: Exception do
    begin
      FConnected := False;
      raise Exception.Create('Erro: Disconnect in Redis. Message: ' + E.Message);
    end;
  end;

  FConnected := False;
end;

initialization

TRedisStore.CriticalSection := TCriticalSection.Create;

finalization

FreeAndNil(TRedisStore.CriticalSection);

end.

