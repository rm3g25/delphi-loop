object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'DelphiLoop v0.1'
  ClientHeight = 620
  ClientWidth = 720
  Color = clBtnFace
  Constraints.MinHeight = 620
  Constraints.MinWidth = 720
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 17
  object pnlMain: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 620
    Align = alClient
    BevelOuter = bvNone
    Padding.Left = 10
    Padding.Top = 10
    Padding.Right = 10
    Padding.Bottom = 10
    TabOrder = 0
    DesignSize = (
      720
      620)
    object pnlContent: TPanel
      Left = 10
      Top = 10
      Width = 700
      Height = 600
      Anchors = [akLeft, akTop, akRight, akBottom]
      BevelOuter = bvNone
      TabOrder = 0
      object pnlAgents: TPanel
        Left = 0
        Top = 0
        Width = 700
        Height = 52
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        DesignSize = (
          700
          52)
        object lblExecutorTitle: TLabel
          Left = 0
          Top = 0
          Width = 53
          Height = 13
          Caption = 'EXECUTOR'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object lblReviewerTitle: TLabel
          Left = 360
          Top = 0
          Width = 53
          Height = 13
          Caption = 'REVIEWER'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object cmbExecutor: TComboBox
          Left = 0
          Top = 18
          Width = 340
          Height = 23
          Style = csDropDownList
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 0
        end
        object cmbReviewer: TComboBox
          Left = 360
          Top = 18
          Width = 260
          Height = 23
          Style = csDropDownList
          Anchors = [akLeft, akTop, akRight]
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 1
        end
        object btnSettings: TButton
          Left = 628
          Top = 16
          Width = 72
          Height = 26
          Anchors = [akTop, akRight]
          Caption = 'Settings'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 2
          OnClick = btnSettingsClick
        end
      end
      object pnlTaskHeader: TPanel
        Left = 0
        Top = 52
        Width = 700
        Height = 18
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 1
        object lblTaskTitle: TLabel
          Left = 0
          Top = 2
          Width = 23
          Height = 13
          Caption = 'TASK'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
      end
      object pnlTaskFooter: TPanel
        Left = 0
        Top = 70
        Width = 700
        Height = 28
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 2
        DesignSize = (
          700
          28)
        object lblIterStatus: TLabel
          Left = 0
          Top = 6
          Width = 32
          Height = 15
          Caption = 'Ready'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object pbProgress: TProgressBar
          Left = 198
          Top = 6
          Width = 390
          Height = 16
          Anchors = [akLeft, akTop, akRight]
          TabOrder = 0
        end
        object btnGenerate: TButton
          Left = 606
          Top = 0
          Width = 94
          Height = 28
          Anchors = [akTop, akRight]
          Caption = 'Generate'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          TabOrder = 1
          OnClick = btnGenerateClick
        end
      end
      object pnlStatus: TPanel
        Left = 0
        Top = 576
        Width = 700
        Height = 24
        Align = alBottom
        BevelOuter = bvNone
        TabOrder = 3
        DesignSize = (
          700
          24)
        object lblStatus: TLabel
          Left = 0
          Top = 4
          Width = 32
          Height = 15
          Caption = 'Ready'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object lblStats: TLabel
          Left = 544
          Top = 4
          Width = 156
          Height = 13
          Alignment = taRightJustify
          Anchors = [akTop, akRight]
          Caption = 'runs: 0  iter: 0  tokens: 0  $0.00'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -11
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
      end
      object pnlResizable: TPanel
        Left = 0
        Top = 98
        Width = 700
        Height = 478
        Align = alClient
        BevelOuter = bvNone
        TabOrder = 4
        object splTaskOutput: TSplitter
          Left = 0
          Top = 60
          Width = 700
          Height = 5
          Cursor = crVSplit
          Align = alTop
          MinSize = 120
          ResizeStyle = rsUpdate
        end
        object pnlTask: TPanel
          Left = 0
          Top = 0
          Width = 700
          Height = 60
          Align = alTop
          BevelOuter = bvNone
          Constraints.MinHeight = 40
          TabOrder = 0
          object memoTask: TMemo
            Left = 0
            Top = 0
            Width = 700
            Height = 60
            Align = alClient
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clWindowText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
            ScrollBars = ssVertical
            TabOrder = 0
            WantReturns = False
          end
        end
        object pcOutput: TPageControl
          Left = 0
          Top = 65
          Width = 700
          Height = 413
          ActivePage = tsLog
          Align = alClient
          TabOrder = 1
          object tsLog: TTabSheet
            Caption = 'Log'
            object btnClearLog: TButton
              Left = 0
              Top = 353
              Width = 692
              Height = 28
              Align = alBottom
              Caption = 'Clear log'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -12
              Font.Name = 'Segoe UI'
              Font.Style = []
              ParentFont = False
              TabOrder = 1
              OnClick = btnClearLogClick
            end
            object memoLog: TMemo
              Left = 0
              Top = 0
              Width = 692
              Height = 353
              Align = alClient
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Courier New'
              Font.Style = []
              ParentFont = False
              ReadOnly = True
              ScrollBars = ssBoth
              TabOrder = 0
            end
          end
          object tsResult: TTabSheet
            Caption = 'Result'
            object memoResult: TMemo
              Left = 0
              Top = 0
              Width = 692
              Height = 353
              Align = alClient
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -11
              Font.Name = 'Courier New'
              Font.Style = []
              ParentFont = False
              ReadOnly = True
              ScrollBars = ssBoth
              TabOrder = 0
            end
            object btnCopy: TButton
              Left = 0
              Top = 353
              Width = 692
              Height = 28
              Align = alBottom
              Caption = 'Copy to clipboard'
              Font.Charset = DEFAULT_CHARSET
              Font.Color = clWindowText
              Font.Height = -12
              Font.Name = 'Segoe UI'
              Font.Style = []
              ParentFont = False
              TabOrder = 1
              OnClick = btnCopyClick
            end
          end
        end
      end
    end
  end
end
