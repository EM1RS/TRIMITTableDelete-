page 70701 "TRM Table Delete Lines"
{
    ApplicationArea = All;
    Caption = 'Table Delete Lines';
    PageType = ListPart;
    SourceTable = "TRM Table Delete Line";
    SourceTableView = sorting("Record Count") order(descending) where(Excluded = const(false));
    DelayedInsert = true;
    MultipleNewLines = true;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Table ID"; Rec."Table ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'The ID of the table to delete data from.';
                }
                field("Table Name"; Rec."Table Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the table.';
                }
                field(Active; Rec.Active)
                {
                    ApplicationArea = All;
                    ToolTip = 'Only active lines are processed during deletion.';
                }
                field("Media Table"; Rec."Media Table")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates this table contains Media or MediaSet fields (discovered via metadata).';
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    ToolTip = 'Current status of the deletion for this line.';
                    StyleExpr = StatusStyle;
                }
                field("Batch Size"; Rec."Batch Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of records to delete per batch (1-5000). Zero means default of 500.';
                }
                field("Run Delete Trigger"; Rec."Run Delete Trigger")
                {
                    ApplicationArea = All;
                    ToolTip = 'If enabled, the OnDelete trigger and delete events run for each record, so related data (e.g. lines, dimensions, comments) is cleaned up by standard logic. This is significantly slower and only works in the company you are currently logged into. If disabled, records are deleted raw without triggers (fast, works across companies, but related data is not removed).';
                }
                field("Delete Older Than"; Rec."Delete Older Than")
                {
                    ApplicationArea = All;
                    ToolTip = 'Only delete records older than the selected period. Requires a Date Field to be set.';
                }
                field("Older Than (Months)"; Rec."Older Than (Months)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of months used when Delete Older Than is set to Custom Months. Records older than this many months are deleted.';
                }
                field("Date Field No."; Rec."Date Field No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'The Date or DateTime field used to determine record age for the Delete Older Than filter.';
                }
                field("Date Field Name"; Rec."Date Field Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Name of the date field used for age filtering.';
                }

                field("Use Filters"; Rec."Use Filters")
                {
                    ApplicationArea = All;
                    ToolTip = 'If enabled, only records matching the filter view are deleted.';
                }
                field("Table Filters"; Rec."Table Filters")
                {
                    ApplicationArea = All;
                    ToolTip = 'Table view filter string to limit which records are deleted.';
                }
                field("Record Count"; Rec."Record Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of records in the table (updated when populated or refreshed).';
                }
                field("Delete Count"; Rec."Delete Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of records deleted during the last or current run.';
                }
                field("Records Remaining"; Rec."Records Remaining")
                {
                    ApplicationArea = All;
                    ToolTip = 'Records remaining to be deleted.';
                }
                field("Started Date/Time"; Rec."Started Date/Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the deletion was started.';
                }
                field("Completed Date/Time"; Rec."Completed Date/Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the deletion completed, failed, or was partially completed.';
                }
                field("Last Run Date"; Rec."Last Run Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time of the last batch commit for this table.';
                }
                field("Last Error"; Rec."Last Error")
                {
                    ApplicationArea = All;
                    ToolTip = 'Error from the last delete attempt, if any.';
                    Style = Unfavorable;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DeleteSingle)
            {
                ApplicationArea = All;
                Caption = 'Delete This Table';
                Image = Delete;
                ToolTip = 'Delete data from only this table. If previously partially completed, continues from remaining records.';
                Scope = Repeater;

                trigger OnAction()
                var
                    Mgt: Codeunit "TRM Table Delete Mgt.";
                begin
                    Mgt.DeleteSingleTable(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ResetStatus)
            {
                ApplicationArea = All;
                Caption = 'Reset Status';
                Image = ResetStatus;
                ToolTip = 'Reset the status of this line to Ready so it can be run again.';
                Scope = Repeater;

                trigger OnAction()
                begin
                    Rec.ResetStatus();
                    CurrPage.Update(false);
                end;
            }
            action(ToggleRunDeleteTrigger)
            {
                ApplicationArea = All;
                Caption = 'Toggle Run Delete Trigger';
                Image = ToggleBreakpoint;
                ToolTip = 'Switch Run Delete Trigger on or off for the selected lines. With triggers on, deletion is significantly slower and only runs in the company you are currently logged into. Use it for partial deletes where related data must be cleaned up; leave it off when emptying entire tables.';

                trigger OnAction()
                var
                    Line: Record "TRM Table Delete Line";
                begin
                    CurrPage.SetSelectionFilter(Line);
                    if Line.FindSet(true) then
                        repeat
                            Line."Run Delete Trigger" := not Line."Run Delete Trigger";
                            Line.Modify();
                        until Line.Next() = 0;
                    CurrPage.Update(false);
                end;
            }
            action(DeleteLines)
            {
                ApplicationArea = All;
                Caption = 'Exclude Selected Lines';
                Image = DeleteRow;
                ToolTip = 'Exclude the selected lines from the list. They will not reappear when populating.';

                trigger OnAction()
                var
                    Line: Record "TRM Table Delete Line";
                begin
                    CurrPage.SetSelectionFilter(Line);
                    if Line.IsEmpty() then
                        exit;
                    if not Confirm('Exclude %1 selected line(s)? They will be hidden and not re-added.', false, Line.Count) then
                        exit;
                    Line.ModifyAll(Excluded, true);
                    Line.ModifyAll(Active, false);
                    CurrPage.Update(false);
                end;
            }
            action(RefreshCounts)
            {
                ApplicationArea = All;
                Caption = 'Refresh Record Counts';
                Image = Refresh;
                ToolTip = 'Refresh the current record counts for all lines.';

                trigger OnAction()
                var
                    Mgt: Codeunit "TRM Table Delete Mgt.";
                begin
                    Mgt.RefreshRecordCounts();
                    CurrPage.Update(false);
                end;
            }

            action(FindMediaTables)
            {
                ApplicationArea = All;
                Caption = 'Find Media Tables';
                Image = Find;
                ToolTip = 'Discover all application tables containing Media or MediaSet fields using metadata only. Does not scan table records.';

                trigger OnAction()
                var
                    Mgt: Codeunit "TRM Table Delete Mgt.";
                    Field: Record Field;
                    TablesFound: Integer;
                    FieldsFound: Integer;
                begin
                    if not Confirm('Find all application tables containing Media or MediaSet fields?\This reads metadata only and does not scan table records.') then
                        exit;
                    TablesFound := Mgt.FindMediaTables();
                    // Count total media fields across all tables
                    Field.SetFilter(TableNo, '>0&<2000000000');
                    Field.SetFilter(Type, '%1|%2', Field.Type::Media, Field.Type::MediaSet);
                    Field.SetRange(Class, Field.Class::Normal);
                    Field.SetRange(Enabled, true);
                    FieldsFound := Field.Count;
                    if TablesFound > 0 then
                        Message('Found %1 new table(s) with Media or MediaSet fields (%2 field(s) total across all discovered tables).', TablesFound, FieldsFound)
                    else
                        Message('No new tables with Media or MediaSet fields were found. All are already in the list.');
                    CurrPage.Update(false);
                end;
            }
            action(AnalyzeMedia)
            {
                ApplicationArea = All;
                Caption = 'Analyze Media References';
                Image = AnalysisView;
                ToolTip = 'Scan media tables for active Media/MediaSet references. Only inspects tables marked as Media Table. Results are stored persistently.';

                trigger OnAction()
                var
                    Mgt: Codeunit "TRM Table Delete Mgt.";
                    ResultPage: Page "TRM Media Analysis Results";
                begin
                    Mgt.AnalyzeMediaReferences();
                    ResultPage.Run();
                end;
            }
            action(ClearList)
            {
                ApplicationArea = All;
                Caption = 'Clear List';
                Image = ClearLog;
                ToolTip = 'Remove all lines from the list.';

                trigger OnAction()
                var
                    Line: Record "TRM Table Delete Line";
                begin
                    if not Confirm('Remove all lines from the list?') then
                        exit;
                    Line.Reset();
                    Line.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Failed:
                StatusStyle := 'Unfavorable';
            Rec.Status::"Partially Completed":
                StatusStyle := 'Ambiguous';
            Rec.Status::Completed:
                StatusStyle := 'Favorable';
            Rec.Status::Running:
                StatusStyle := 'StrongAccent';
            else
                StatusStyle := 'Standard';
        end;
    end;

    var
        StatusStyle: Text;
}
