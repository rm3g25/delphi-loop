unit Engine.Types;

{
  Shared data types for the DelphiLoop engine.
  Passive records only - no behavior, no dependencies. Every other unit in
  src/Engine may depend on this one; this one depends on nothing.
}

interface

type
  TProviderType = (ptOllama, ptOpenAI, ptCustom);

  TProviderConfig = record
    Name: string;
    BaseUrl: string;
    ApiKey: string;
    Kind: TProviderType;
  end;

  TModelConfig = record
    DisplayName: string;
    ModelId: string;
    ProviderIndex: Integer;
  end;

  TLoopSettings = record
    MaxIterations: Integer;
    ExecutorIndex: Integer;
    ReviewerIndex: Integer;
  end;

implementation

end.
