unit uFileAttrTypes;

{ Data shared by the Set attributes dialog and the platform code that reads and
  writes the attributes of a local file. }

interface

type
  TFileAttrChoice = (facKeep, facSet, facClear);

  /// <summary>Local times; 0 = unknown (or, in the dialog state, differs
  /// between the selected items).</summary>
  TFileAttrTimes = record
    Created: TDateTime;
    Modified: TDateTime;
    Accessed: TDateTime;
  end;

  TFileAttrSnapshot = record
    ReadOnly: Boolean;
    Hidden: Boolean;
    System: Boolean;
    Archive: Boolean;
    Owner: string;
    Times: TFileAttrTimes;
  end;

  TFileAttrPlan = record
    ReadOnly: TFileAttrChoice;
    Hidden: TFileAttrChoice;
    System: TFileAttrChoice;
    Archive: TFileAttrChoice;
    ChangeOwner: Boolean;
    Owner: string;
    Recurse: Boolean;
    // Only the flagged times are written; the rest keep their value.
    SetCreated: Boolean;
    SetModified: Boolean;
    SetAccessed: Boolean;
    Times: TFileAttrTimes;
  end;

  TFileAttrDialogState = record
    Summary: string;
    Owner: string;
    OwnerMixed: Boolean;
    ReadOnly: TFileAttrChoice;
    Hidden: TFileAttrChoice;
    System: TFileAttrChoice;
    Archive: TFileAttrChoice;
    Times: TFileAttrTimes;
  end;

implementation

end.
