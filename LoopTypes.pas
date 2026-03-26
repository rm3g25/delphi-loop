unit LoopTypes;

interface

type
  TProviderType = (ptOllama, ptOpenAI, ptCustom);

  TProviderConfig = record
    Name        :string;
    BaseURL     :string;
    APIKey      :string;
    Kind        :TProviderType;
  end;

  TModelConfig = record
    DisplayName :string;
    ModelID     :string;
    ProviderIdx :Integer;
  end;

implementation

end.
