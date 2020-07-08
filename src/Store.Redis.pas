unit Store.Redis;

interface

uses
  Store.Intf,
  Redis.Client, Redis.Values, Redis.NetLib.INDY, Redis.Commons,
  System.SysUtils, System.DateUtils;

type
  TRedisStore = class(TInterfacedObject, IStore)
  private
    FRedis: TRedisClient;
    FTimeout: Integer;

    function ProcessExec(const ARA: TRedisArray): TRedisNullable<TRedisString>;
    function SetExpire(const AKey: string; const ARN: TRedisNullable<TRedisString>): Integer;
  public
    constructor Create(const AHost: string = '127.0.0.1'; const APort: Integer = 6379; const AClientName: string = ''); overload;
    destructor Destroy; override;

    function Incr(const AKey: string): TStoreCallback;
    procedure Decrement(const AKey: string);
    procedure ResetAll();
    procedure SetTimeout(const ATimeout: Integer);

    class function New(const AHost: string = '127.0.0.1'; const APort: Integer = 6379; const AClientName: string = ''): TRedisStore; overload;
  end;

implementation

{ TRedisStore }

constructor TRedisStore.Create(const AHost: string = '127.0.0.1'; const APort: Integer = 6379; const AClientName: string = '');
begin
  try
    FRedis := TRedisClient.Create(AHost, APort);
    if not(AClientName.Trim.IsEmpty) then
      FRedis.ClientSetName(AClientName);
    FRedis.Connect
  except
    raise Exception.Create('Connection error in Redis.');
  end;
end;

destructor TRedisStore.Destroy;
begin
  FRedis.Free;
  inherited;
end;

class function TRedisStore.New(const AHost: string; const APort: Integer; const AClientName: string): TRedisStore;
begin
  Result := Create(AHost, APort, AClientName);
end;

function TRedisStore.Incr(const AKey: string): TStoreCallback;
var
  LReturn: TRedisArray;
  LProcess: TRedisNullable<TRedisString>;
  LTTL: Integer;
begin
  LReturn := FRedis.MULTI(
    procedure(const Redis: IRedisClient)
    begin
      Redis.Incr(AKey);
      Redis.TTL(AKey);
    end);

  LProcess := ProcessExec(LReturn);

  LTTL := SetExpire(AKey, LProcess);

  Result.Current := StrToInt(LReturn.Value[0]);
  Result.ResetTime := IncSecond(Now(), LTTL);
end;

procedure TRedisStore.Decrement(const AKey: string);
var
  LReturn: TRedisArray;
  LProcess: TRedisNullable<TRedisString>;
begin
  LReturn := FRedis.MULTI(
    procedure(const Redis: IRedisClient)
    begin
      Redis.DECR(AKey);
      Redis.TTL(AKey);
    end);

  LProcess := ProcessExec(LReturn);
  SetExpire(AKey, LProcess);
end;

procedure TRedisStore.ResetAll;
begin
  FRedis.FLUSHALL;
end;

procedure TRedisStore.SetTimeout(const ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TRedisStore.ProcessExec(const ARA: TRedisArray): TRedisNullable<TRedisString>;
begin
  if (Length(ARA.Value) >= 2) then
    Result := ARA.Value[1]
  else
    Result := ARA.Value;
end;

function TRedisStore.SetExpire(const AKey: string; const ARN: TRedisNullable<TRedisString>): Integer;
begin
  if (ARN.Value.Value = '-1') then
  begin
    FRedis.EXPIRE(AKey, FTimeout);
    Result := FTimeout;
  end
  else
    Result := StrToInt(ARN.Value.Value);
end;

end.
