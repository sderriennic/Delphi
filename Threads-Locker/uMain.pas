unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, System.SyncObjs;

type
  TfrmMain = class(TForm)
    PaintBox1: TPaintBox;
    procedure FormCreate(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure PaintBox1Click(Sender: TObject);
  private
    Procedure InitialiseProcessus;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

const
  LARGEUR   = 2;
  NBTHREADS = 8;
  BLOCS     = 512;
  SAMPLES   = 1024;
  NB        = BLOCS * SAMPLES;
  HAUTEUR   = NBTHREADS * 2;
  ESPACE    = HAUTEUR div 2;

type
  TData = array[0..BLOCS - 1, 0..NBTHREADS - 1] of Word;
  PData = ^TData;

  TTestThread = class(TThread)
    Data: PData;
    N: Integer;
    procedure Execute; override;
    procedure LockRead; virtual; abstract;
    procedure UnLockRead; virtual; abstract;
    procedure LockWrite; virtual; abstract;
    procedure UnLockWrite; virtual; abstract;
  end;

  TCSThread = class (TTestThread)
    procedure LockRead; override;
    procedure UnLockRead; override;
    procedure LockWrite; override;
    procedure UnLockWrite; override;
  end;

  TMonitorThread = class (TTestThread)
    procedure LockRead; override;
    procedure UnLockRead; override;
    procedure LockWrite; override;
    procedure UnLockWrite; override;
  end;

  TMREWThread = class (TTestThread)
    procedure LockRead; override;
    procedure UnLockRead; override;
    procedure LockWrite; override;
    procedure UnLockWrite; override;
  end;

  TLighthread = class (TTestThread)
    procedure LockRead; override;
    procedure UnLockRead; override;
    procedure LockWrite; override;
    procedure UnLockWrite; override;
  end;

var
  vcs: TRTLCriticalSection;
  MREW: TMREWSync;
  LightMREW: TLightweightMREW;
  vCounter: Cardinal;
  vDataCS, vDataMon, vDataMREW, vDataLight: TData;

//
// Execute
//
procedure TTestThread.Execute;
begin
  while not Terminated do
  begin
    LockWrite;
    try
      Inc(vCounter);
    finally
      UnlockWrite;
    end;

    LockRead;
    try
      if vCounter >= NB then
        Terminate
      else
        Inc(Data[vCounter div SAMPLES, N]);
    finally
      UnLockRead;
    end;
  end;
end;

procedure TCSThread.LockRead;
begin
  EnterCriticalSection(vcs);
end;

procedure TCSThread.UnLockRead;
begin
  LeaveCriticalSection(vcs);
end;

procedure TCSThread.LockWrite;
begin
  EnterCriticalSection(vcs);
end;

procedure TCSThread.UnLockWrite;
begin
  LeaveCriticalSection(vcs);
end;


procedure TMonitorThread.LockRead;
begin
  System.TMonitor.Enter(frmMain);
end;

procedure TMonitorThread.UnLockRead;
begin
  System.TMonitor.Exit(frmMain);
end;

procedure TMonitorThread.LockWrite;
begin
  System.TMonitor.Enter(frmMain);
end;

procedure TMonitorThread.UnLockWrite;
begin
  System.TMonitor.Exit(frmMain);
end;


procedure TMREWThread.LockRead;
begin
  MREW.BeginRead;
end;

procedure TMREWThread.UnLockRead;
begin
  MREW.EndRead;
end;

procedure TMREWThread.LockWrite;
begin
  MREW.BeginWrite;
end;

procedure TMREWThread.UnLockWrite;
begin
  MREW.EndWrite;
end;


procedure TLighthread.LockRead;
begin
  LightMREW.BeginRead;
end;

procedure TLighthread.UnLockRead;
begin
  LightMREW.EndRead;
end;

procedure TLighthread.LockWrite;
begin
  LightMREW.BeginWrite;
end;

procedure TLighthread.UnLockWrite;
begin
  LightMREW.EndWrite;
end;

//
// FormCreate
//
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  PaintBox1.Hint := 'Left-Click: restart' + #13#10 + #13#10 +
                    'Gray: TCriticalSection' + #13#10 +
                    'Red: TMonitor' + #13#10 +
                    'Green: TMREWSync' + #13#10 +
                    'Blue: TLightweightMREW';

  PaintBox1.ShowHint := True;

  PaintBox1.Width  := (ESPACE * 2) + (LARGEUR * BLOCS);
  PaintBox1.Height := (ESPACE * 5) + ((HAUTEUR * NBTHREADS) * 4);

  InitialiseProcessus;
end;

procedure TfrmMain.InitialiseProcessus;
var
  qs, qe, qf: Int64;
  i: Byte;
  threads: array [0..NBTHREADS - 1] of TTestThread;
begin
  SetProcessAffinityMask(GetCurrentProcess, Cardinal(-1));

  InitializeCriticalSection(vcs);

  MREW := TMREWSync.Create;

  Caption := 'CPU: ' + IntToStr(NBTHREADS);

  // CriticalSection
  QueryPerformanceFrequency(qf);

  FillChar(vDataCS, SizeOf(vDataCS), 0);

  QueryPerformanceCounter(qs);

  vCounter := 0;

  for i := 0 to High(threads) do
  begin
    threads[i]      := TCSThread.Create;
    threads[i].N    := i;
    threads[i].Data := @vDataCS;
  end;

  for i := 0 to High(threads) do
  begin
    threads[i].WaitFor;
    threads[i].Free;
  end;

  QueryPerformanceCounter(qe);

  Caption := Caption + Format(', TCriticalSection: %.5f s', [(qe-qs)/qf]);

  // Monitor
  QueryPerformanceFrequency(qf);

  FillChar(vDataMon, SizeOf(vDataMon), 0);

  QueryPerformanceCounter(qs);

  vCounter := 0;

  for i := 0 to High(threads) do
  begin
    threads[i]      := TMonitorThread.Create;
    threads[i].N    := i;
    threads[i].Data := @vDataMon;
  end;

  for i := 0 to High(threads) do
  begin
    threads[i].WaitFor;
    threads[i].Free;
  end;

  QueryPerformanceCounter(qe);

  Caption := Caption + Format(', TMonitor: %.5f s', [(qe-qs)/qf]);

  // MREW
  QueryPerformanceFrequency(qf);

  FillChar(vDataMREW, SizeOf(vDataMREW), 0);

  QueryPerformanceCounter(qs);

  vCounter := 0;

  for i := 0 to High(threads) do
  begin
    threads[i]      := TMREWThread.Create;
    threads[i].N    := i;
    threads[i].Data := @vDataMREW;
  end;

  for i := 0 to High(threads) do
  begin
    threads[i].WaitFor;
    threads[i].Free;
  end;

  QueryPerformanceCounter(qe);

  Caption := Caption + Format(', TMREWSync: %.5f s', [(qe-qs)/qf]);

  // LightMREW
  QueryPerformanceFrequency(qf);

  FillChar(vDataLight, SizeOf(vDataLight), 0);

  QueryPerformanceCounter(qs);

  vCounter := 0;

  for i := 0 to High(threads) do
  begin
    threads[i]      := TLighthread.Create;
    threads[i].N    := i;
    threads[i].Data := @vDataLight;
  end;

  for i := 0 to High(threads) do
  begin
    threads[i].WaitFor;
    threads[i].Free;
  end;

  QueryPerformanceCounter(qe);

  Caption := Caption + Format(', TLightweightMREW: %.5f s', [(qe-qs)/qf]);

  MREW.Free;

  DeleteCriticalSection(vcs);

  PaintBox1.Invalidate;
end;

procedure TfrmMain.PaintBox1Click(Sender: TObject);
begin
  InitialiseProcessus;
end;

procedure TfrmMain.PaintBox1Paint(Sender: TObject);
var
  i, j, k: Word;
  r: TRect;
  canvas: TCanvas;
begin
  canvas := PaintBox1.Canvas;

  canvas.Brush.Style := bsSolid;
  canvas.Brush.Color := clWhite;

  canvas.FillRect(PaintBox1.ClientRect);

  for i := 0 to (BLOCS - 1) do
  begin
    r.Left  := ESPACE + (LARGEUR * i);
    r.Right := r.Left + LARGEUR;

    for j := 0 to (NBTHREADS - 1) do
    begin
      // Critical Section
      r.Top    := ESPACE + (j * HAUTEUR);
      r.Bottom := r.Top + HAUTEUR;
      k        := vDataCS[i, j] * 255 div SAMPLES;

      canvas.Brush.Color := RGB(k, k, k);
      canvas.FillRect(r);

      // Monitor
      r.Top    := (ESPACE * 2) + ((j + NBTHREADS) * HAUTEUR);
      r.Bottom := r.Top + HAUTEUR;
      k        := vDataMon[i, j] * 255 div SAMPLES;

      canvas.Brush.Color := RGB(k, 0, 0);
      canvas.FillRect(r);

      // MREW
      r.Top    := (ESPACE * 3) + ((j + (NBTHREADS * 2)) * HAUTEUR);
      r.Bottom := r.Top + HAUTEUR;
      k        := vDataMREW[i, j] * 255 div SAMPLES;

      canvas.Brush.Color := RGB(0, k, 0);
      canvas.FillRect(r);

      // LightMREW
      r.Top    := (ESPACE * 4) + ((j + (NBTHREADS * 3)) * HAUTEUR);
      r.Bottom := r.Top + HAUTEUR;
      k        := vDataLight[i, j] * 255 div SAMPLES;

      canvas.Brush.Color := RGB(0, 0, k);
      canvas.FillRect(r);
    end;
  end;
end;

end.
