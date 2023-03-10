object frmMain: TfrmMain
  Left = 119
  Top = 120
  AutoSize = True
  BorderWidth = 5
  Caption = 'TMonitor VS TCriticalSection'
  ClientHeight = 257
  ClientWidth = 516
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Arial'
  Font.Style = []
  OnCreate = FormCreate
  TextHeight = 14
  object PaintBox1: TPaintBox
    Left = 0
    Top = 0
    Width = 512
    Height = 256
    Color = clBtnFace
    ParentColor = False
    OnClick = PaintBox1Click
    OnPaint = PaintBox1Paint
  end
end
