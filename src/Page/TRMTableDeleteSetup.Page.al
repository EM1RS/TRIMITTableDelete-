page 70700 "TRM Table Delete Setup"
{
    ApplicationArea = All;
    Caption = 'Table Delete Setup';
    PageType = Card;
    SourceTable = "TRM Table Delete Setup";
    UsageCategory = Administration;
    DeleteAllowed = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General';

                field(Enabled; Rec.Enabled)
                {
                    ApplicationArea = All;
                    ToolTip = 'Enable or disable the table delete functionality.';
                }
                field("Require Confirmation"; Rec."Require Confirmation")
                {
                    ApplicationArea = All;
                    ToolTip = 'If enabled, each table deletion requires individual confirmation.';
                }
            }
            group(Companies)
            {
                Caption = 'Companies';
                InstructionalText = 'Choose which companies to delete from using Manage Companies.';
            }
            group(Defaults)
            {
                Caption = 'Defaults for New Lines';

                field("Default Batch Size"; Rec."Default Batch Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Default number of records to delete per batch when new lines are added. Valid range: 1-5000. Zero means 500.';
                }

            }
            group(Status)
            {
                Caption = 'Last Run';

                field("Last Run Date"; Rec."Last Run Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time of the last deletion run.';
                }
                field("Last Run By"; Rec."Last Run By")
                {
                    ApplicationArea = All;
                    ToolTip = 'User who performed the last deletion run.';
                }
            }
            group(Warning)
            {
                Caption = 'WARNING';
                InstructionalText = 'This app deletes data permanently. Ensure you have a backup before running. In Production you will be asked for extra confirmation.';
            }
            part(Lines; "TRM Table Delete Lines")
            {
                ApplicationArea = All;
                Caption = 'Tables to Delete';
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ManageCompanies)
            {
                ApplicationArea = All;
                Caption = 'Manage Companies';
                Image = Company;
                ToolTip = 'Select the companies where table data should be deleted.';

                trigger OnAction()
                var
                    CompaniesPage: Page "TRM Table Delete Companies";
                begin
                    CompaniesPage.RunModal();
                end;
            }
            action(RunDeleteAll)
            {
                ApplicationArea = All;
                Caption = 'Run Delete All';
                Image = Delete;
                ToolTip = 'Delete data from all active tables in the list.';

                trigger OnAction()
                var
                    Mgt: Codeunit "TRM Table Delete Mgt.";
                begin
                    Mgt.RunDeleteAll();
                    CurrPage.Lines.Page.Update(false);
                end;
            }
        }
        area(Promoted)
        {
            actionref(RunDeleteAll_Promoted; RunDeleteAll) { }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
