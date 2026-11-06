table 70701 "TRM Table Delete Line"
{
    Caption = 'Table Delete Line';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Line No."; Integer)
        {
            Caption = 'Line No.';
            AutoIncrement = true;
        }
        field(10; "Table ID"; Integer)
        {
            Caption = 'Table ID';
            TableRelation = AllObjWithCaption."Object ID" where("Object Type" = const(Table));

            trigger OnValidate()
            var
                AllObj: Record AllObjWithCaption;
            begin
                if "Table ID" = 0 then begin
                    "Table Name" := '';
                    exit;
                end;
                AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                AllObj.SetRange("Object ID", "Table ID");
                if AllObj.FindFirst() then
                    "Table Name" := CopyStr(AllObj."Object Name", 1, MaxStrLen("Table Name"));
            end;
        }
        field(20; "Table Name"; Text[250])
        {
            Caption = 'Table Name';
            Editable = false;
        }
        field(21; "Table Caption"; Text[250])
        {
            Editable = false;
        }
        field(30; "Use Filters"; Boolean)
        {
            Caption = 'Use Filters';
        }
        field(40; "Table Filters"; Text[2048])
        {
            Caption = 'Table Filters (View)';
        }
        field(50; "Delete Count"; Integer)
        {
            Caption = 'Records Deleted';
            Editable = false;
        }
        field(60; "Last Run Date"; DateTime)
        {
            Caption = 'Last Run Date';
            Editable = false;
        }
        field(70; Active; Boolean)
        {
            Caption = 'Active';
            InitValue = true;
        }
        field(80; "Record Count"; Integer)
        {
            Caption = 'Record Count';
            Editable = false;
        }
        field(90; Excluded; Boolean)
        {
            Caption = 'Excluded';
        }
        field(100; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
            Editable = false;
        }
        field(110; "Batch Size"; Integer)
        {
            Caption = 'Batch Size';
            InitValue = 500;
            MinValue = 0;
            MaxValue = 5000;

            trigger OnValidate()
            begin
                if "Batch Size" < 0 then
                    "Batch Size" := 0;
                if "Batch Size" > 5000 then
                    "Batch Size" := 5000;
            end;
        }
        field(120; "Run Delete Trigger"; Boolean)
        {
            Caption = 'Run Delete Trigger';
            InitValue = false;
        }
        field(180; "Delete Older Than"; Enum "TRM Delete Older Than")
        {
            Caption = 'Delete Older Than';
        }
        field(190; "Date Field No."; Integer)
        {
            Caption = 'Date Field No.';
            TableRelation = Field."No." where(TableNo = field("Table ID"), Type = filter(Date | DateTime), Class = const(Normal));

            trigger OnValidate()
            var
                Fld: Record Field;
            begin
                if "Date Field No." = 0 then begin
                    "Date Field Name" := '';
                    exit;
                end;
                Fld.Get("Table ID", "Date Field No.");
                "Date Field Name" := Fld.FieldName;
            end;
        }
        field(200; "Date Field Name"; Text[80])
        {
            Caption = 'Date Field Name';
            Editable = false;
        }
        field(130; Status; Enum "TRM Table Delete Status")
        {
            Caption = 'Status';
            Editable = false;
        }
        field(140; "Records Remaining"; Integer)
        {
            Caption = 'Records Remaining';
            Editable = false;
        }
        field(150; "Started Date/Time"; DateTime)
        {
            Caption = 'Started Date/Time';
            Editable = false;
        }
        field(160; "Completed Date/Time"; DateTime)
        {
            Caption = 'Completed Date/Time';
            Editable = false;
        }
        field(170; "Media Table"; Boolean)
        {
            Caption = 'Media Table';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Line No.")
        {
            Clustered = true;
        }
        key(TableID; "Table ID") { }
        key(RecCount; "Record Count") { }
    }

    procedure GetEffectiveBatchSize(): Integer
    begin
        if "Batch Size" <= 0 then
            exit(500);
        exit("Batch Size");
    end;

    procedure GetCutoffDate(): Date
    begin
        case "Delete Older Than" of
            "Delete Older Than"::" ":
                exit(0D);
            "Delete Older Than"::"1 Week":
                exit(CalcDate('<-1W>', Today));
            "Delete Older Than"::"1 Month":
                exit(CalcDate('<-1M>', Today));
            "Delete Older Than"::"2 Months":
                exit(CalcDate('<-2M>', Today));
            "Delete Older Than"::"3 Months":
                exit(CalcDate('<-3M>', Today));
            "Delete Older Than"::"6 Months":
                exit(CalcDate('<-6M>', Today));
            "Delete Older Than"::"1 Year":
                exit(CalcDate('<-1Y>', Today));
        end;
    end;

    procedure HasDateFilter(): Boolean
    begin
        exit(("Delete Older Than" <> "Delete Older Than"::" ") and ("Date Field No." <> 0));
    end;

    procedure ResetStatus()
    begin
        Status := Status::Ready;
        "Delete Count" := 0;
        "Records Remaining" := 0;
        "Last Error" := '';
        "Started Date/Time" := 0DT;
        "Completed Date/Time" := 0DT;
        Modify();
    end;
}
