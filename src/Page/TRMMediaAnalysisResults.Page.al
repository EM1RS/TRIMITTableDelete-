page 70702 "TRM Media Analysis Results"
{
    ApplicationArea = All;
    Caption = 'Media Analysis Results';
    PageType = List;
    SourceTable = "TRM Media Analysis Result";
    SourceTableView = sorting("Total Media References") order(descending);
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = true;
    ModifyAllowed = false;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'The company analyzed.';
                }
                field("Table No."; Rec."Table No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID of the analyzed table.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the analyzed table.';
                }
                field("Field No."; Rec."Field No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Field number of the Media or MediaSet field.';
                }
                field("Field Name"; Rec."Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the Media or MediaSet field.';
                }
                field("Field Type"; Rec."Field Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Media or MediaSet.';
                }
                field("Total Records"; Rec."Total Records")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total records scanned in the table.';
                }
                field("Records With Media"; Rec."Records With Media")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of records that have a media reference in this field.';
                    Style = Attention;
                    StyleExpr = Rec."Records With Media" > 0;
                }
                field("Empty Records"; Rec."Empty Records")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of records with no media in this field.';
                }
                field("Total Media References"; Rec."Total Media References")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total media references found. For Media fields: equals Records With Media. For MediaSet fields: counted as 1 per non-empty record (exact item count not available via FieldRef).';
                    Style = Strong;
                    StyleExpr = Rec."Total Media References" > 0;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Status of the analysis for this entry.';
                    StyleExpr = StatusStyle;
                }
                field("Analysis Duration (ms)"; Rec."Analysis Duration (ms)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Time taken to analyze this field in milliseconds.';
                }
                field("Last Error"; Rec."Last Error")
                {
                    ApplicationArea = All;
                    ToolTip = 'Error message if analysis was skipped or failed.';
                    Style = Unfavorable;
                }
                field("Analysis Start"; Rec."Analysis Start")
                {
                    ApplicationArea = All;
                    ToolTip = 'When analysis started for this entry.';
                    Visible = false;
                }
                field("Analysis End"; Rec."Analysis End")
                {
                    ApplicationArea = All;
                    ToolTip = 'When analysis completed for this entry.';
                    Visible = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ClearResults)
            {
                ApplicationArea = All;
                Caption = 'Clear All Results';
                Image = ClearLog;
                ToolTip = 'Delete all analysis results.';

                trigger OnAction()
                var
                    Result: Record "TRM Media Analysis Result";
                begin
                    if not Confirm('Delete all media analysis results?') then
                        exit;
                    Result.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Skipped:
                StatusStyle := 'Ambiguous';
            Rec.Status::Unsupported:
                StatusStyle := 'Ambiguous';
            Rec.Status::Failed:
                StatusStyle := 'Unfavorable';
            Rec.Status::Completed:
                StatusStyle := 'Favorable';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
