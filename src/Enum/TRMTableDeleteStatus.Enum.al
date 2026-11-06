enum 70700 "TRM Table Delete Status"
{
    Extensible = false;
    Caption = 'Table Delete Status';

    value(0; Ready)
    {
        Caption = 'Ready';
    }
    value(1; Running)
    {
        Caption = 'Running';
    }
    value(2; "Partially Completed")
    {
        Caption = 'Partially Completed';
    }
    value(3; Completed)
    {
        Caption = 'Completed';
    }
    value(4; Failed)
    {
        Caption = 'Failed';
    }
    value(5; Cancelled)
    {
        Caption = 'Cancelled';
    }
    value(6; Skipped)
    {
        Caption = 'Skipped';
    }
    value(7; Unsupported)
    {
        Caption = 'Unsupported';
    }
}
