unit uElevatedVfs;

{ Local file operations with administrator rights (POSIX build). There is no
  helper process: reads go to the ordinary provider and every changing
  operation fails with "not supported". The Windows build lives in
  Platform\Windows; each project puts exactly one of the two directories on its
  unit search path. }

interface

uses
  System.SysUtils, System.Classes, uVfsTypes, uTextEncoding;

type
  TElevatedFileVfs = class(TInterfacedObject, IVirtualFileSystem)
  private
    FInner: IVirtualFileSystem;
    FOnActiveChanged: TProc<Boolean>;
  public
    constructor Create(const AInner: IVirtualFileSystem);
    /// <summary>True while a helper is running; never here.</summary>
    function IsActive: Boolean;
    procedure Shutdown;
    property OnActiveChanged: TProc<Boolean> read FOnActiveChanged
      write FOnActiveChanged;

    procedure ListDirectoryAsync(const AURI: string; ACancel: IJobCancelToken;
      AOnDone: TVfsListCallback);
    procedure DeleteAsync(const AURI: string; AMode: TVfsDeleteMode;
      ACancel: IJobCancelToken; AOnProgress: TVfsProgressCallback;
      AOnDone: TVfsBoolCallback);
    procedure CreateDirectoryAsync(const AURI: string; ACancel: IJobCancelToken;
      AOnDone: TVfsBoolCallback);
    procedure CopyAsync(const AFromURI, AToURI: string; ACancel: IJobCancelToken;
      AOnProgress: TVfsProgressCallback; AOnDone: TVfsBoolCallback;
      AOverwrite: Boolean = False; APreserveTimestamps: Boolean = False);
    procedure MoveAsync(const AFromURI, AToURI: string; ACancel: IJobCancelToken;
      AOnProgress: TVfsProgressCallback; AOnDone: TVfsBoolCallback;
      AOverwrite: Boolean = False; APreserveTimestamps: Boolean = False);
    procedure ReadTextAsync(const AURI: string; AMaxBytes: Int64;
      ACancel: IJobCancelToken; AOnDone: TVfsTextCallback);
    procedure ReadBytesAsync(const AURI: string; AMaxBytes: Int64;
      ACancel: IJobCancelToken; AOnDone: TVfsBytesCallback);
    procedure WriteTextAsync(const AURI, AText: string; AEncoding: TTextFileEncoding;
      ACancel: IJobCancelToken; AOnDone: TVfsBoolCallback);
    procedure ExistsAsync(const AURI: string; ACancel: IJobCancelToken;
      AOnDone: TVfsExistsCallback);
    procedure GetFreeSpaceAsync(const ARootURI: string; ACancel: IJobCancelToken;
      AOnDone: TVfsFreeSpaceCallback);
  end;

implementation

procedure Refuse(const AOnDone: TVfsBoolCallback; const AURI: string);
var
  Done: TVfsBoolCallback;
  Err: TVfsError;
begin
  Done := AOnDone;
  Err := TVfsError.Make(vecNotSupported,
    'Administrator operations are not available on this system', AURI);
  TThread.Queue(nil,
    procedure
    begin
      if Assigned(Done) then
        Done(False, Err);
    end);
end;

constructor TElevatedFileVfs.Create(const AInner: IVirtualFileSystem);
begin
  inherited Create;
  FInner := AInner;
end;

function TElevatedFileVfs.IsActive: Boolean;
begin
  Result := False;
end;

procedure TElevatedFileVfs.Shutdown;
begin
end;

procedure TElevatedFileVfs.ListDirectoryAsync(const AURI: string;
  ACancel: IJobCancelToken; AOnDone: TVfsListCallback);
begin
  FInner.ListDirectoryAsync(AURI, ACancel, AOnDone);
end;

procedure TElevatedFileVfs.DeleteAsync(const AURI: string; AMode: TVfsDeleteMode;
  ACancel: IJobCancelToken; AOnProgress: TVfsProgressCallback;
  AOnDone: TVfsBoolCallback);
begin
  Refuse(AOnDone, AURI);
end;

procedure TElevatedFileVfs.CreateDirectoryAsync(const AURI: string;
  ACancel: IJobCancelToken; AOnDone: TVfsBoolCallback);
begin
  Refuse(AOnDone, AURI);
end;

procedure TElevatedFileVfs.CopyAsync(const AFromURI, AToURI: string;
  ACancel: IJobCancelToken; AOnProgress: TVfsProgressCallback;
  AOnDone: TVfsBoolCallback; AOverwrite, APreserveTimestamps: Boolean);
begin
  Refuse(AOnDone, AFromURI);
end;

procedure TElevatedFileVfs.MoveAsync(const AFromURI, AToURI: string;
  ACancel: IJobCancelToken; AOnProgress: TVfsProgressCallback;
  AOnDone: TVfsBoolCallback; AOverwrite, APreserveTimestamps: Boolean);
begin
  Refuse(AOnDone, AFromURI);
end;

procedure TElevatedFileVfs.WriteTextAsync(const AURI, AText: string;
  AEncoding: TTextFileEncoding; ACancel: IJobCancelToken; AOnDone: TVfsBoolCallback);
begin
  Refuse(AOnDone, AURI);
end;

procedure TElevatedFileVfs.ReadTextAsync(const AURI: string; AMaxBytes: Int64;
  ACancel: IJobCancelToken; AOnDone: TVfsTextCallback);
begin
  FInner.ReadTextAsync(AURI, AMaxBytes, ACancel, AOnDone);
end;

procedure TElevatedFileVfs.ReadBytesAsync(const AURI: string; AMaxBytes: Int64;
  ACancel: IJobCancelToken; AOnDone: TVfsBytesCallback);
begin
  FInner.ReadBytesAsync(AURI, AMaxBytes, ACancel, AOnDone);
end;

procedure TElevatedFileVfs.ExistsAsync(const AURI: string; ACancel: IJobCancelToken;
  AOnDone: TVfsExistsCallback);
begin
  FInner.ExistsAsync(AURI, ACancel, AOnDone);
end;

procedure TElevatedFileVfs.GetFreeSpaceAsync(const ARootURI: string;
  ACancel: IJobCancelToken; AOnDone: TVfsFreeSpaceCallback);
begin
  FInner.GetFreeSpaceAsync(ARootURI, ACancel, AOnDone);
end;

end.
