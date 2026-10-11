unit uDriveTypes;

{ Description of a volume as the Change Drive popup and the info panel show
  it. Filled by uPlatformDrives; uDriveInfo adds caching and formatting. }

interface

type
  TDriveInfo = record
    Letter: Char;        // single-character key of the volume; #0 when none
    RootPath: string;    // e.g. 'C:\' or '/home'
    KindLabel: string;   // Hard disk / Removable / Network / CD-ROM / RAM; '' unknown
    FsName: string;      // NTFS, FAT32, ext4, ...
    LabelOrPath: string; // volume label or UNC for network
    TotalBytes: Int64;
    FreeBytes: Int64;
    SerialNumber: Cardinal;
    VolumeFlags: Cardinal;
  end;

  TDriveInfoArray = TArray<TDriveInfo>;

implementation

end.
