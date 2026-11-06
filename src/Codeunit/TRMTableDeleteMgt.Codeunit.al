codeunit 70700 "TRM Table Delete Mgt."
{
    TableNo = "TRM Table Delete Setup";
    Permissions = tabledata "Sent Email" = rimd;

    trigger OnRun()
    begin
    end;

    procedure RunDeleteAll()
    var
        Setup: Record "TRM Table Delete Setup";
        Line: Record "TRM Table Delete Line";
        EnvInfo: Codeunit "Environment Information";
        TablesProcessed: Integer;
        TablesSkipped: Integer;
        TotalDeleted: Integer;
        SelectedCompany: Record "TRM Table Delete Company";
    begin
        Setup.GetSetup();
        if not Setup.Enabled then
            Error(NotEnabledErr);

        if EnvInfo.IsProduction() then
            if not Confirm(ConfirmProductionQst) then
                exit;

        Line.SetRange(Active, true);
        Line.SetRange(Excluded, false);
        if Line.IsEmpty() then
            Error(NoActiveLinesErr);

        if not FindSelectedCompanies(SelectedCompany) then
            Error(NoSelectedCompaniesErr);

        if not Confirm(ConfirmRunAllQst) then
            exit;

        Line.FindSet();
        repeat
            TablesProcessed += 1;
            DeleteTableSelectedCompanies(Line, Setup."Require Confirmation");
            Line.Get(Line."Line No.");
            TotalDeleted += Line."Delete Count";
            if Line."Last Error" <> '' then
                TablesSkipped += 1;
        until Line.Next() = 0;

        Setup.GetSetup();
        Setup."Last Run Date" := CurrentDateTime;
        Setup."Last Run By" := CopyStr(UserId, 1, MaxStrLen(Setup."Last Run By"));
        Setup.Modify();
        Commit();

        Message(CompletedAllMsg, TablesProcessed, TotalDeleted, TablesSkipped);
    end;

    procedure DeleteSingleTable(var Line: Record "TRM Table Delete Line")
    var
        Setup: Record "TRM Table Delete Setup";
        EnvInfo: Codeunit "Environment Information";
    begin
        Setup.GetSetup();
        if not Setup.Enabled then
            Error(NotEnabledErr);

        if EnvInfo.IsProduction() then
            if not Confirm(ConfirmProductionQst) then
                exit;

        DeleteTableSelectedCompanies(Line, true);

        Line.Get(Line."Line No.");
        if Line.Status = Line.Status::Failed then
            Message(SingleTableFailedMsg, Line."Table Name", Line."Last Error")
        else
            Message(SingleTableCompletedMsg, Line."Table Name", Line."Delete Count");
    end;

    local procedure DeleteTableSelectedCompanies(var Line: Record "TRM Table Delete Line"; RequireConfirmation: Boolean)
    var
        SelectedCompany: Record "TRM Table Delete Company";
        RecCount: Integer;
        ErrorText: Text;
    begin
        if not ValidateTableForDeletion(Line."Table ID", ErrorText) then begin
            SetLineFailed(Line, ErrorText);
            exit;
        end;

        RecCount := GetRecordCountSelectedCompaniesWithDateFilter(Line);

        if RecCount = 0 then begin
            SetLineCompleted(Line, 0, 0);
            exit;
        end;

        if RequireConfirmation then
            if not ConfirmDeletion(Line, GetSelectedCompaniesForDisplay(), RecCount) then
                exit;

        Line.Status := Line.Status::Running;
        Line."Started Date/Time" := CurrentDateTime;
        Line."Delete Count" := 0;
        Line."Last Error" := '';
        Line."Records Remaining" := RecCount;
        Line.Modify();
        Commit();

        FindSelectedCompanies(SelectedCompany);
        SelectedCompany.FindSet();
        repeat
            ErrorText := DeleteBatched(Line, SelectedCompany."Company Name");
            if ErrorText <> '' then begin
                Line.Get(Line."Line No.");
                SetLinePartiallyCompleted(Line, ErrorText);
                exit;
            end;
        until SelectedCompany.Next() = 0;

        Line.Get(Line."Line No.");
        RecCount := GetRecordCountSelectedCompaniesWithDateFilter(Line);
        SetLineCompleted(Line, Line."Delete Count", RecCount);
    end;

    local procedure DeleteBatched(var Line: Record "TRM Table Delete Line"; CompanyToDelete: Text): Text
    var
        RecRef: RecordRef;
        BatchSize: Integer;
        BatchCount: Integer;
        BatchDeleted: Integer;
        Progress: Dialog;
        ErrorText: Text;
    begin
        BatchSize := Line.GetEffectiveBatchSize();

        // Triggers on a RecordRef opened in another company would run their logic against the current company
        if Line."Run Delete Trigger" and (CompanyToDelete <> CompanyName()) then
            exit(StrSubstNo(TriggerOtherCompanyErr, CompanyToDelete));

        Progress.Open(DeletingBatchMsg, Line."Table Name", Line."Delete Count");

        repeat
            BatchCount := 0;
            BatchDeleted := 0;

            RecRef.Open(Line."Table ID", false, CompanyToDelete);
            if Line."Use Filters" and (Line."Table Filters" <> '') then
                RecRef.SetView(Line."Table Filters");
            ApplyDateFilter(RecRef, Line);

            if not RecRef.FindSet() then begin
                RecRef.Close();
                Progress.Close();
                exit('');
            end;

            repeat
                ClearLastError();
                if not TryDeleteRecord(RecRef, Line."Run Delete Trigger") then begin
                    ErrorText := GetLastErrorText();
                    RecRef.Close();
                    Progress.Close();
                    // Persist partial batch progress
                    if BatchDeleted > 0 then begin
                        Line.Get(Line."Line No.");
                        Line."Delete Count" += BatchDeleted;
                        Line."Records Remaining" -= BatchDeleted;
                        Line.Modify();
                        Commit();
                    end;
                    exit(ErrorText);
                end;
                BatchCount += 1;
                BatchDeleted += 1;
            until (RecRef.Next() = 0) or (BatchCount >= BatchSize);

            RecRef.Close();

            // Commit deletions and progress atomically
            Line.Get(Line."Line No.");
            Line."Delete Count" += BatchDeleted;
            Line."Records Remaining" -= BatchDeleted;
            Line."Last Run Date" := CurrentDateTime;
            Line.Modify();
            Commit();

            Progress.Update(2, Line."Delete Count");
        until BatchCount = 0;

        Progress.Close();
        exit('');
    end;

    local procedure ConfirmDeletion(Line: Record "TRM Table Delete Line"; CompanyText: Text; RecCount: Integer): Boolean
    var
        TriggerText: Text;
    begin
        if Line."Run Delete Trigger" then
            TriggerText := TriggersOnTxt
        else
            TriggerText := TriggersOffTxt;

        exit(Confirm(
            ConfirmDeleteDetailedQst,
            false,
            Line."Table ID",
            Line."Table Name",
            CompanyText,
            RecCount,
            Line.GetEffectiveBatchSize(),
            TriggerText));
    end;

    local procedure ValidateTableForDeletion(TableID: Integer; var ErrorText: Text): Boolean
    begin
        if TableID = 0 then begin
            ErrorText := 'Table ID is not specified.';
            exit(false);
        end;

        // Block Tenant Media Set, Tenant Media, Tenant Media Thumbnails
        if TableID in [2000000183, 2000000184, 2000000185] then begin
            ErrorText := StrSubstNo(BlockedSystemTableErr, TableID);
            exit(false);
        end;

        // Block virtual/system tables
        if (TableID >= 2000000000) and (TableID <= 2000000300) then begin
            ErrorText := StrSubstNo(BlockedSystemTableErr, TableID);
            exit(false);
        end;

        ClearLastError();
        if not TryOpenTable(TableID) then begin
            ErrorText := StrSubstNo(CannotOpenTableErr, TableID, GetLastErrorText());
            exit(false);
        end;

        exit(true);
    end;

    local procedure SetLineFailed(var Line: Record "TRM Table Delete Line"; ErrorText: Text)
    begin
        Line.Status := Line.Status::Failed;
        Line."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(Line."Last Error"));
        Line."Last Run Date" := CurrentDateTime;
        Line."Completed Date/Time" := CurrentDateTime;
        Line.Modify();
        Commit();
    end;

    local procedure SetLinePartiallyCompleted(var Line: Record "TRM Table Delete Line"; ErrorText: Text)
    begin
        Line.Status := Line.Status::"Partially Completed";
        Line."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(Line."Last Error"));
        Line."Last Run Date" := CurrentDateTime;
        Line."Completed Date/Time" := CurrentDateTime;
        Line.Modify();
        Commit();
    end;

    local procedure SetLineCompleted(var Line: Record "TRM Table Delete Line"; TotalDeleted: Integer; Remaining: Integer)
    begin
        Line.Status := Line.Status::Completed;
        Line."Delete Count" := TotalDeleted;
        Line."Records Remaining" := Remaining;
        Line."Last Error" := '';
        Line."Last Run Date" := CurrentDateTime;
        Line."Completed Date/Time" := CurrentDateTime;
        Line.Modify();
        Commit();
    end;

    [TryFunction]
    local procedure TryOpenTable(TableID: Integer)
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(TableID);
        RecRef.Close();
    end;

    [TryFunction]
    local procedure TryDeleteRecord(var RecRef: RecordRef; RunTrigger: Boolean)
    begin
        RecRef.Delete(RunTrigger);
    end;

    procedure GetRecordCountForCompany(TableID: Integer; UseFilters: Boolean; TableFilters: Text; CompanyToCount: Text): Integer
    var
        RecRef: RecordRef;
        RecCount: Integer;
    begin
        if TableID = 0 then
            exit(0);
        ClearLastError();
        if not TryOpenTable(TableID) then
            exit(0);
        RecRef.Open(TableID, false, CompanyToCount);
        if UseFilters and (TableFilters <> '') then
            RecRef.SetView(TableFilters);
        RecCount := RecRef.Count;
        RecRef.Close();
        exit(RecCount);
    end;

    procedure GetRecordCountForCompanyWithDateFilter(Line: Record "TRM Table Delete Line"; CompanyToCount: Text): Integer
    var
        RecRef: RecordRef;
        RecCount: Integer;
    begin
        if Line."Table ID" = 0 then
            exit(0);
        ClearLastError();
        if not TryOpenTable(Line."Table ID") then
            exit(0);
        RecRef.Open(Line."Table ID", false, CompanyToCount);
        if Line."Use Filters" and (Line."Table Filters" <> '') then
            RecRef.SetView(Line."Table Filters");
        ApplyDateFilter(RecRef, Line);
        RecCount := RecRef.Count;
        RecRef.Close();
        exit(RecCount);
    end;

    procedure GetRecordCountAllCompanies(TableID: Integer; UseFilters: Boolean; TableFilters: Text): Integer
    var
        Company: Record Company;
        TotalCount: Integer;
    begin
        if TableID = 0 then
            exit(0);
        ClearLastError();
        if not TryOpenTable(TableID) then
            exit(0);
        Company.FindSet();
        repeat
            TotalCount += GetRecordCountForCompany(TableID, UseFilters, TableFilters, Company.Name);
        until Company.Next() = 0;
        exit(TotalCount);
    end;

    procedure GetRecordCountSelectedCompanies(TableID: Integer; UseFilters: Boolean; TableFilters: Text): Integer
    var
        SelectedCompany: Record "TRM Table Delete Company";
        TotalCount: Integer;
    begin
        if not FindSelectedCompanies(SelectedCompany) then
            exit(0);

        SelectedCompany.FindSet();
        repeat
            TotalCount += GetRecordCountForCompany(TableID, UseFilters, TableFilters, SelectedCompany."Company Name");
        until SelectedCompany.Next() = 0;

        exit(TotalCount);
    end;

    procedure GetRecordCountSelectedCompaniesWithDateFilter(Line: Record "TRM Table Delete Line"): Integer
    var
        SelectedCompany: Record "TRM Table Delete Company";
        TotalCount: Integer;
    begin
        if not FindSelectedCompanies(SelectedCompany) then
            exit(0);

        if not Line.HasDateFilter() then begin
            SelectedCompany.FindSet();
            repeat
                TotalCount += GetRecordCountForCompany(Line."Table ID", Line."Use Filters", Line."Table Filters", SelectedCompany."Company Name");
            until SelectedCompany.Next() = 0;
        end else begin
            SelectedCompany.FindSet();
            repeat
                TotalCount += GetRecordCountForCompanyWithDateFilter(Line, SelectedCompany."Company Name");
            until SelectedCompany.Next() = 0;
        end;

        exit(TotalCount);
    end;

    procedure RefreshRecordCounts()
    var
        Line: Record "TRM Table Delete Line";
        RecCount: Integer;
        SelectedCompany: Record "TRM Table Delete Company";
    begin
        if not FindSelectedCompanies(SelectedCompany) then
            Error(NoSelectedCompaniesErr);

        if Line.FindSet() then
            repeat
                RecCount := GetRecordCountSelectedCompaniesWithDateFilter(Line);
                Line."Record Count" := RecCount;
                Line."Records Remaining" := RecCount;
                Line.Modify();
            until Line.Next() = 0;
        Commit();
    end;

    procedure FindMediaTables(): Integer
    var
        Field: Record Field;
        Line: Record "TRM Table Delete Line";
        AllObj: Record AllObjWithCaption;
        Setup: Record "TRM Table Delete Setup";
        LineNo: Integer;
        TablesFound: Integer;
        ProcessedTables: Dictionary of [Integer, Boolean];
    begin
        Setup.GetSetup();

        Line.Reset();
        if Line.FindLast() then
            LineNo := Line."Line No.";

        // Query field metadata for Media and MediaSet fields only
        Field.SetFilter(TableNo, '>0&<2000000000');
        Field.SetFilter(Type, '%1|%2', Field.Type::Media, Field.Type::MediaSet);
        Field.SetRange(Class, Field.Class::Normal);
        Field.SetRange(Enabled, true);
        if not Field.FindSet() then
            exit(0);

        repeat
            // Skip system tables that must never be added
            if not (Field.TableNo in [2000000183, 2000000184, 2000000185]) then
                if not ProcessedTables.ContainsKey(Field.TableNo) then begin
                    ProcessedTables.Add(Field.TableNo, true);

                    // Skip if already in the list
                    if not TableAlreadyExists(Field.TableNo) then begin
                        // Verify the table object exists
                        AllObj.SetRange("Object Type", AllObj."Object Type"::Table);
                        AllObj.SetRange("Object ID", Field.TableNo);
                        if AllObj.FindFirst() then begin
                            LineNo += 10000;
                            Line.Init();
                            Line."Line No." := LineNo;
                            Line.Validate("Table ID", Field.TableNo);
                            Line.Active := false;
                            Line."Media Table" := true;
                            Line."Batch Size" := Setup."Default Batch Size";

                            Line.Insert(true);
                            TablesFound += 1;
                        end;
                    end else begin
                        // Mark existing entry as media table if not already
                        Line.SetRange("Table ID", Field.TableNo);
                        if Line.FindFirst() then
                            if not Line."Media Table" then begin
                                Line."Media Table" := true;
                                Line.Modify();
                            end;
                        Line.Reset();
                    end;
                end;
        until Field.Next() = 0;

        Commit();
        exit(TablesFound);
    end;

    procedure AnalyzeMediaReferences()
    var
        Line: Record "TRM Table Delete Line";
        Field: Record Field;
        TablesAnalyzed: Integer;
        TotalTables: Integer;
        Progress: Dialog;
        CompanyToAnalyze: Text[30];
    begin

        Line.SetRange("Media Table", true);
        Line.SetRange(Excluded, false);
        if Line.IsEmpty() then
            Error(NoMediaTablesErr);

        TotalTables := Line.Count;
        Progress.Open(AnalyzingMediaMsg, TablesAnalyzed, TotalTables);
        Progress.Update(2, TotalTables);

        CompanyToAnalyze := CompanyName;

        Line.FindSet();
        repeat
            TablesAnalyzed += 1;
            Progress.Update(1, TablesAnalyzed);

            Field.SetRange(TableNo, Line."Table ID");
            Field.SetFilter(Type, '%1|%2', Field.Type::Media, Field.Type::MediaSet);
            Field.SetRange(Class, Field.Class::Normal);
            Field.SetRange(Enabled, true);
            if Field.FindSet() then
                repeat
                    AnalyzeOneField(Line."Table ID", Line."Table Name", Field, CompanyToAnalyze);
                until Field.Next() = 0;
        until Line.Next() = 0;

        Progress.Close();
    end;

    local procedure AnalyzeOneField(TableID: Integer; TableName: Text[250]; Field: Record Field; CompanyToAnalyze: Text[30])
    var
        Result: Record "TRM Media Analysis Result";
        WithMedia: Integer;
        EmptyCount: Integer;
        TotalCount: Integer;
        MediaRefs: Integer;
        StartTime: DateTime;
        ErrorText: Text;
        FieldTypeText: Text[30];
        Handled: Boolean;
    begin
        if Field.Type = Field.Type::Media then
            FieldTypeText := 'Media'
        else
            FieldTypeText := 'MediaSet';

        StartTime := CurrentDateTime;

        // Delete previous result for same company/table/field
        Result.SetRange("Company Name", CompanyToAnalyze);
        Result.SetRange("Table No.", TableID);
        Result.SetRange("Field No.", Field."No.");
        Result.DeleteAll();
        Result.Reset();

        // Dispatch to typed analyzer if available
        ClearLastError();
        Handled := DispatchTypedAnalyzer(TableID, Field."No.", CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs, ErrorText);

        if ErrorText <> '' then begin
            InsertAnalysisResult(
                CompanyToAnalyze, TableID, TableName, Field."No.",
                CopyStr(Field.FieldName, 1, 80), FieldTypeText,
                0, 0, TotalCount, 0, StartTime,
                Enum::"TRM Table Delete Status"::Skipped, ErrorText);
            Commit();
            exit;
        end;

        if Handled then begin
            InsertAnalysisResult(
                CompanyToAnalyze, TableID, TableName, Field."No.",
                CopyStr(Field.FieldName, 1, 80), FieldTypeText,
                WithMedia, EmptyCount, TotalCount, MediaRefs, StartTime,
                Enum::"TRM Table Delete Status"::Completed, '');
            Commit();
            exit;
        end;

        // No typed analyzer — mark as unsupported
        ClearLastError();
        if not TryGetTableCount(TableID, CompanyToAnalyze, TotalCount) then begin
            ErrorText := GetLastErrorText();
            InsertAnalysisResult(
                CompanyToAnalyze, TableID, TableName, Field."No.",
                CopyStr(Field.FieldName, 1, 80), FieldTypeText,
                0, 0, 0, 0, StartTime,
                Enum::"TRM Table Delete Status"::Skipped, ErrorText);
            Commit();
            exit;
        end;

        InsertAnalysisResult(
            CompanyToAnalyze, TableID, TableName, Field."No.",
            CopyStr(Field.FieldName, 1, 80), FieldTypeText,
            0, 0, TotalCount, 0, StartTime,
            Enum::"TRM Table Delete Status"::Unsupported,
            UnsupportedFieldErr);
        Commit();
    end;

    local procedure DispatchTypedAnalyzer(TableID: Integer; FieldNo: Integer; CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer; var ErrorText: Text): Boolean
    begin
        case TableID of
            Database::Item:
                if FieldNo = 89 then begin
                    AnalyzeItemPicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs, ErrorText);
                    exit(true);
                end;
            6037103: // trm Master
                if FieldNo = 900 then begin
                    AnalyzeTrmMasterPicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs, ErrorText);
                    exit(true);
                end;
            6037037: // trm Collection Master Relation
                if FieldNo = 900 then begin
                    AnalyzeTrmCollMasterRelPicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs, ErrorText);
                    exit(true);
                end;
            6037178: // trm Picture Cache
                if FieldNo = 900 then begin
                    AnalyzeTrmPictureCachePicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs, ErrorText);
                    exit(true);
                end;
        end;
        exit(false);
    end;

    local procedure AnalyzeItemPicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer; var ErrorText: Text)
    var
        Item: Record Item;
        MediaCount: Integer;
    begin
        ClearLastError();
        if not TryAnalyzeItemPicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs) then
            ErrorText := GetLastErrorText();
    end;

    [TryFunction]
    local procedure TryAnalyzeItemPicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer)
    var
        Item: Record Item;
        MediaCount: Integer;
    begin
        WithMedia := 0;
        EmptyCount := 0;
        MediaRefs := 0;
        Item.ChangeCompany(CompanyToAnalyze);
        Item.SetLoadFields(Picture);
        TotalCount := Item.Count;
        if Item.FindSet() then
            repeat
                MediaCount := Item.Picture.Count;
                if MediaCount > 0 then begin
                    WithMedia += 1;
                    MediaRefs += MediaCount;
                end else
                    EmptyCount += 1;
            until Item.Next() = 0;
    end;

    local procedure AnalyzeTrmMasterPicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer; var ErrorText: Text)
    begin
        ClearLastError();
        if not TryAnalyzeTrmMasterPicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs) then
            ErrorText := GetLastErrorText();
    end;

    [TryFunction]
    local procedure TryAnalyzeTrmMasterPicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer)
    var
        TrmMaster: Record "trm Master";
        MediaCount: Integer;
    begin
        WithMedia := 0;
        EmptyCount := 0;
        MediaRefs := 0;
        TrmMaster.ChangeCompany(CompanyToAnalyze);
        TrmMaster.SetLoadFields(Picture);
        TotalCount := TrmMaster.Count;
        if TrmMaster.FindSet() then
            repeat
                MediaCount := TrmMaster.Picture.Count;
                if MediaCount > 0 then begin
                    WithMedia += 1;
                    MediaRefs += MediaCount;
                end else
                    EmptyCount += 1;
            until TrmMaster.Next() = 0;
    end;

    local procedure AnalyzeTrmCollMasterRelPicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer; var ErrorText: Text)
    begin
        ClearLastError();
        if not TryAnalyzeTrmCollMasterRelPicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs) then
            ErrorText := GetLastErrorText();
    end;

    [TryFunction]
    local procedure TryAnalyzeTrmCollMasterRelPicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer)
    var
        TrmCollMasterRel: Record "trm Collection Master Relation";
        MediaCount: Integer;
    begin
        WithMedia := 0;
        EmptyCount := 0;
        MediaRefs := 0;
        TrmCollMasterRel.ChangeCompany(CompanyToAnalyze);
        TrmCollMasterRel.SetLoadFields(Picture);
        TotalCount := TrmCollMasterRel.Count;
        if TrmCollMasterRel.FindSet() then
            repeat
                MediaCount := TrmCollMasterRel.Picture.Count;
                if MediaCount > 0 then begin
                    WithMedia += 1;
                    MediaRefs += MediaCount;
                end else
                    EmptyCount += 1;
            until TrmCollMasterRel.Next() = 0;
    end;

    local procedure AnalyzeTrmPictureCachePicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer; var ErrorText: Text)
    begin
        ClearLastError();
        if not TryAnalyzeTrmPictureCachePicture(CompanyToAnalyze, WithMedia, EmptyCount, TotalCount, MediaRefs) then
            ErrorText := GetLastErrorText();
    end;

    [TryFunction]
    local procedure TryAnalyzeTrmPictureCachePicture(CompanyToAnalyze: Text[30]; var WithMedia: Integer; var EmptyCount: Integer; var TotalCount: Integer; var MediaRefs: Integer)
    var
        TrmPictureCache: Record "trm Picture Cache";
    begin
        WithMedia := 0;
        EmptyCount := 0;
        MediaRefs := 0;
        TrmPictureCache.ChangeCompany(CompanyToAnalyze);
        TrmPictureCache.SetLoadFields(Picture);
        TotalCount := TrmPictureCache.Count;
        if TrmPictureCache.FindSet() then
            repeat
                if TrmPictureCache.Picture.HasValue then begin
                    WithMedia += 1;
                    MediaRefs += 1;
                end else
                    EmptyCount += 1;
            until TrmPictureCache.Next() = 0;
    end;

    [TryFunction]
    local procedure TryGetTableCount(TableID: Integer; CompanyToAnalyze: Text[30]; var TotalCount: Integer)
    var
        RecRef: RecordRef;
    begin
        RecRef.Open(TableID, false, CompanyToAnalyze);
        TotalCount := RecRef.Count;
        RecRef.Close();
    end;

    local procedure InsertAnalysisResult(CompanyToAnalyze: Text[30]; TableID: Integer; TableName: Text[250]; FieldNo: Integer; FieldName: Text[80]; FieldTypeText: Text[30]; WithMedia: Integer; EmptyCount: Integer; TotalCount: Integer; MediaRefs: Integer; StartTime: DateTime; AnalysisStatus: Enum "TRM Table Delete Status"; ErrorText: Text)
    var
        Result: Record "TRM Media Analysis Result";
    begin
        Result.Init();
        Result."Entry No." := 0;
        Result."Company Name" := CompanyToAnalyze;
        Result."Table No." := TableID;
        Result."Table Name" := TableName;
        Result."Field No." := FieldNo;
        Result."Field Name" := FieldName;
        Result."Field Type" := FieldTypeText;
        Result."Records With Media" := WithMedia;
        Result."Empty Records" := EmptyCount;
        Result."Total Records" := TotalCount;
        Result."Total Media References" := MediaRefs;
        Result."Analysis Start" := StartTime;
        Result."Analysis End" := CurrentDateTime;
        Result."Analysis Duration (ms)" := CurrentDateTime - StartTime;
        Result.Status := AnalysisStatus;
        Result."Last Error" := CopyStr(ErrorText, 1, MaxStrLen(Result."Last Error"));
        Result.Insert(true);
    end;

    procedure SyncCompanySelection()
    var
        Company: Record Company;
        SelectedCompany: Record "TRM Table Delete Company";
        SelectedCompanyToDelete: Record "TRM Table Delete Company";
    begin
        if Company.FindSet() then
            repeat
                if not SelectedCompany.Get(Company.Name) then begin
                    SelectedCompany.Init();
                    SelectedCompany."Company Name" := Company.Name;
                    SelectedCompany.Selected := false;
                    SelectedCompany.Insert();
                end;
            until Company.Next() = 0;

        SelectedCompany.Reset();
        if SelectedCompany.FindSet() then
            repeat
                if not Company.Get(SelectedCompany."Company Name") then
                    if SelectedCompanyToDelete.Get(SelectedCompany."Company Name") then
                        SelectedCompanyToDelete.Delete();
            until SelectedCompany.Next() = 0;
    end;

    local procedure FindSelectedCompanies(var SelectedCompany: Record "TRM Table Delete Company"): Boolean
    begin
        SyncCompanySelection();
        SelectedCompany.Reset();
        SelectedCompany.SetRange(Selected, true);
        exit(not SelectedCompany.IsEmpty());
    end;

    local procedure GetSelectedCompaniesForDisplay(): Text
    var
        SelectedCompany: Record "TRM Table Delete Company";
        CompanyCount: Integer;
    begin
        if not FindSelectedCompanies(SelectedCompany) then
            exit('');

        CompanyCount := SelectedCompany.Count;
        if CompanyCount = 1 then begin
            SelectedCompany.FindFirst();
            exit(SelectedCompany."Company Name");
        end;

        exit(StrSubstNo(SelectedCompaniesTxt, CompanyCount));
    end;

    local procedure ApplyDateFilter(var RecRef: RecordRef; Line: Record "TRM Table Delete Line")
    var
        FldRef: FieldRef;
        CutoffDate: Date;
    begin
        if not Line.HasDateFilter() then
            exit;
        CutoffDate := Line.GetCutoffDate();
        if CutoffDate = 0D then
            exit;
        FldRef := RecRef.Field(Line."Date Field No.");
        case FldRef.Type of
            FieldType::Date:
                FldRef.SetFilter('..%1', CutoffDate);
            FieldType::DateTime:
                FldRef.SetFilter('..%1', CreateDateTime(CutoffDate, 235959T));
        end;
    end;

    local procedure TableAlreadyExists(TableID: Integer): Boolean
    var
        Line: Record "TRM Table Delete Line";
    begin
        Line.SetRange("Table ID", TableID);
        exit(not Line.IsEmpty());
    end;

    var
        ConfirmProductionQst: Label 'WARNING: You are in a PRODUCTION environment!\\Deleting data here is permanent and cannot be undone.\\Are you absolutely sure you want to continue?';
        NotEnabledErr: Label 'Table Delete is not enabled. Enable it in the setup page first.';
        NoActiveLinesErr: Label 'No active table delete lines found.';
        NoMediaTablesErr: Label 'No media tables found in the list. Run Find Media Tables first.';
        ConfirmRunAllQst: Label 'This will DELETE data from all active tables in the list.\\\Are you absolutely sure you want to continue?';
        ConfirmDeleteDetailedQst: Label 'Confirm deletion:\Table ID: %1\Table: %2\Company: %3\Records: %4\Batch Size: %5\Run OnDelete Triggers: %6\\\Proceed?', Comment = '%1=Table ID, %2=Table Name, %3=Company, %4=Record Count, %5=Batch Size, %6=Trigger Info';
        CompletedAllMsg: Label 'Done.\Processed: %1 table(s)\Deleted: %2 records\Skipped/Failed: %3 table(s)', Comment = '%1=Tables, %2=Deleted, %3=Skipped';
        SingleTableCompletedMsg: Label 'Deleted %2 records from %1.', Comment = '%1=Table Name, %2=Count';
        SingleTableFailedMsg: Label 'Deletion of %1 failed:\%2', Comment = '%1=Table Name, %2=Error';
        BlockedSystemTableErr: Label 'Table %1 is a system table and cannot be deleted directly. Use the standard Detached Media Cleanup for media tables.', Comment = '%1=Table ID';
        CannotOpenTableErr: Label 'Cannot open table %1: %2', Comment = '%1=Table ID, %2=Error';
        FindMediaConfirmQst: Label 'Find all application tables containing Media or MediaSet fields?\This reads metadata only and does not scan table records.';
        FindMediaResultMsg: Label 'Found %1 new table(s) with Media or MediaSet fields (%2 field(s) total across all discovered tables).', Comment = '%1=Tables, %2=Fields';
        FindMediaNoneMsg: Label 'No tables with Media or MediaSet fields were found, or all are already in the list.';
        DeletingBatchMsg: Label 'Deleting #1##########\Records deleted: #2######';
        AnalyzingMediaMsg: Label 'Analyzing media fields... #1## of #2##';
        UnsupportedFieldErr: Label 'Generic Media/MediaSet content inspection is not supported through FieldRef. A typed analyzer is required for this table and field.';
        NoSelectedCompaniesErr: Label 'No companies are selected for deletion. Use Manage Companies to select at least one company.';
        SelectedCompaniesTxt: Label '%1 selected companies', Comment = '%1=Count of selected companies';
        TriggersOnTxt: Label 'Yes (OnDelete triggers run)';
        TriggersOffTxt: Label 'No (raw delete, triggers skipped)';
        TriggerOtherCompanyErr: Label 'Run Delete Trigger is only allowed in the current company. Disable it to delete from company %1.', Comment = '%1=Company Name';
}
