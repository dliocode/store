unit Store.Intf;

interface

type
  TMemory = record
    Count: Integer;
    DateTime: TDateTime;
  end;

  TStoreCallback = record
    Current: Integer;
    ResetTime: TDateTime;
  end;

  IStore = interface
    ['{75A8E917-85D7-40D2-874A-70E86D3D5EF3}']
    function Incr(const AKey: string): TStoreCallback;
    procedure Decrement(const AKey: string);
    procedure ResetAll();
    procedure SetTimeout(const ATimeout: Integer);
  end;

implementation

end.
