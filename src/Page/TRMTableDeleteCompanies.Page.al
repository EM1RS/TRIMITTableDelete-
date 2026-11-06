page 70703 "TRM Table Delete Companies"
{
    ApplicationArea = All;
    Caption = 'Table Delete Companies';
    PageType = List;
    SourceTable = "TRM Table Delete Company";
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Companies)
            {
                field(Selected; Rec.Selected)
                {
                    ApplicationArea = All;
                    ToolTip = 'Select the companies where table data should be deleted.';
                }
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Company name.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshCompanies)
            {
                ApplicationArea = All;
                Caption = 'Refresh Companies';
                Image = Refresh;
                ToolTip = 'Synchronize this list with all companies in the environment.';

                trigger OnAction()
                var
                    Mgt: Codeunit "TRM Table Delete Mgt.";
                begin
                    Mgt.SyncCompanySelection();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnOpenPage()
    var
        Mgt: Codeunit "TRM Table Delete Mgt.";
    begin
        Mgt.SyncCompanySelection();
    end;
}
