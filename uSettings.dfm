object frmSettings: TfrmSettings
  Left = 0
  Top = 0
  BorderStyle = bsDialog
  Caption = 'Settings'
  ClientHeight = 420
  ClientWidth = 560
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poOwnerFormCenter
  TextHeight = 17
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 560
    Height = 360
    Align = alTop
    BevelOuter = bvNone
    Padding.Left = 16
    Padding.Top = 16
    Padding.Right = 16
    Padding.Bottom = 8
    TabOrder = 0
    object pnlProviders: TPanel
      Left = 16
      Top = 16
      Width = 254
      Height = 336
      BevelOuter = bvNone
      TabOrder = 0
      object lblProvidersTitle: TLabel
        Left = 0
        Top = 0
        Width = 59
        Height = 13
        Caption = 'PROVIDERS'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGray
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object lbProviders: TListBox
        Left = 0
        Top = 20
        Width = 254
        Height = 286
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ItemHeight = 15
        ParentFont = False
        TabOrder = 0
        OnDblClick = lbProvidersDblClick
      end
      object pnlProviderBtns: TPanel
        Left = 0
        Top = 310
        Width = 254
        Height = 26
        BevelOuter = bvNone
        TabOrder = 1
        object btnAddProvider: TButton
          Left = 0
          Top = 0
          Width = 70
          Height = 26
          Caption = '+ add'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 0
          OnClick = btnAddProviderClick
        end
        object btnEditProvider: TButton
          Left = 78
          Top = 0
          Width = 70
          Height = 26
          Caption = 'edit'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 1
          OnClick = btnEditProviderClick
        end
        object btnRemoveProvider: TButton
          Left = 156
          Top = 0
          Width = 70
          Height = 26
          Caption = 'remove'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 2
          OnClick = btnRemoveProviderClick
        end
      end
    end
    object pnlModels: TPanel
      Left = 290
      Top = 16
      Width = 254
      Height = 336
      BevelOuter = bvNone
      TabOrder = 1
      object lblModelsTitle: TLabel
        Left = 0
        Top = 0
        Width = 44
        Height = 13
        Caption = 'MODELS'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGray
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object lbModels: TListBox
        Left = 0
        Top = 20
        Width = 254
        Height = 286
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ItemHeight = 15
        ParentFont = False
        TabOrder = 0
        OnDblClick = lbModelsDblClick
      end
      object pnlModelBtns: TPanel
        Left = 0
        Top = 310
        Width = 254
        Height = 26
        BevelOuter = bvNone
        TabOrder = 1
        object btnAddModel: TButton
          Left = 0
          Top = 0
          Width = 70
          Height = 26
          Caption = '+ add'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 0
          OnClick = btnAddModelClick
        end
        object btnEditModel: TButton
          Left = 78
          Top = 0
          Width = 70
          Height = 26
          Caption = 'edit'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 1
          OnClick = btnEditModelClick
        end
        object btnRemoveModel: TButton
          Left = 156
          Top = 0
          Width = 70
          Height = 26
          Caption = 'remove'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 2
          OnClick = btnRemoveModelClick
        end
      end
    end
  end
  object pnlGeneral: TPanel
    Left = 0
    Top = 360
    Width = 560
    Height = 60
    Align = alBottom
    BevelOuter = bvNone
    Padding.Left = 16
    Padding.Right = 16
    TabOrder = 1
    object lblMaxIter: TLabel
      Left = 16
      Top = 20
      Width = 74
      Height = 15
      Caption = 'Max iterations'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object spnMaxIter: TSpinEdit
      Left = 110
      Top = 16
      Width = 60
      Height = 27
      MaxValue = 10
      MinValue = 1
      TabOrder = 0
      Value = 4
    end
    object btnClose: TButton
      Left = 468
      Top = 16
      Width = 75
      Height = 26
      Caption = 'Close'
      Default = True
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 1
      OnClick = btnCloseClick
    end
  end
end
