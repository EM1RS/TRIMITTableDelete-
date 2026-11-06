table 70702 "TRM Media Analysis Result"
{
    Caption = 'Media Analysis Result';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(5; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
        }
        field(10; "Table No."; Integer)
        {
            Caption = 'Table No.';
        }
        field(20; "Table Name"; Text[250])
        {
            Caption = 'Table Name';
        }
        field(30; "Field No."; Integer)
        {
            Caption = 'Field No.';
        }
        field(40; "Field Name"; Text[80])
        {
            Caption = 'Field Name';
        }
        field(50; "Field Type"; Text[30])
        {
            Caption = 'Field Type';
        }
        field(60; "Records With Media"; Integer)
        {
            Caption = 'Records With Media';
        }
        field(70; "Empty Records"; Integer)
        {
            Caption = 'Empty Records';
        }
        field(80; "Total Records"; Integer)
        {
            Caption = 'Total Records';
        }
        field(85; "Total Media References"; Integer)
        {
            Caption = 'Total Media References';
        }
        field(90; "Analysis Duration (ms)"; Integer)
        {
            Caption = 'Analysis Duration (ms)';
        }
        field(100; Status; Enum "TRM Table Delete Status")
        {
            Caption = 'Status';
        }
        field(110; "Last Error"; Text[2048])
        {
            Caption = 'Last Error';
        }
        field(120; "Analysis Start"; DateTime)
        {
            Caption = 'Analysis Start';
        }
        field(130; "Analysis End"; DateTime)
        {
            Caption = 'Analysis End';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(TableField; "Company Name", "Table No.", "Field No.") { }
        key(MediaRefs; "Total Media References") { }
        key(WithMedia; "Records With Media") { }
    }
}
