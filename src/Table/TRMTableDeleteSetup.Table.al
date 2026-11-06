table 70700 "TRM Table Delete Setup"
{
    Caption = 'Table Delete Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; Enabled; Boolean)
        {
            Caption = 'Enabled';
        }
        field(20; "Require Confirmation"; Boolean)
        {
            Caption = 'Require Confirmation Per Table';
            InitValue = true;
        }
        field(25; "All Companies"; Boolean)
        {
            Caption = 'Delete From All Companies';
            ObsoleteState = Pending;
            ObsoleteReason = 'Replaced by explicit company selection in Manage Companies.';
            ObsoleteTag = '26.1.0.0';
        }
        field(30; "Last Run Date"; DateTime)
        {
            Caption = 'Last Run Date';
            Editable = false;
        }
        field(40; "Last Run By"; Code[50])
        {
            Caption = 'Last Run By';
            Editable = false;
        }
        field(50; "Default Batch Size"; Integer)
        {
            Caption = 'Default Batch Size';
            InitValue = 500;
            MinValue = 0;
            MaxValue = 5000;
        }
        field(60; "Default Run Delete Trigger"; Boolean)
        {
            Caption = 'Default Run Delete Trigger';
            InitValue = false;
            ObsoleteState = Pending;
            ObsoleteReason = 'Always raw delete. Field kept for upgrade compatibility.';
            ObsoleteTag = '26.1.0.0';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetSetup()
    begin
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Default Batch Size" := 500;
            Rec."Require Confirmation" := true;
            Rec.Insert();
        end;
    end;
}
