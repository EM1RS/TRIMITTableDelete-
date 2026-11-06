permissionset 70700 "TRM Table Delete"
{
    Assignable = true;
    Caption = 'TRIMIT Table Delete';

    Permissions =
        table "TRM Table Delete Setup" = X,
        table "TRM Table Delete Line" = X,
        table "TRM Table Delete Company" = X,
        table "TRM Media Analysis Result" = X,
        tabledata "TRM Table Delete Setup" = RIMD,
        tabledata "TRM Table Delete Line" = RIMD,
        tabledata "TRM Table Delete Company" = RIMD,
        tabledata "TRM Media Analysis Result" = RIMD,
        page "TRM Table Delete Setup" = X,
        page "TRM Table Delete Lines" = X,
        page "TRM Table Delete Companies" = X,
        page "TRM Media Analysis Results" = X,
        codeunit "TRM Table Delete Mgt." = X,
        query "TRM Table Record Count" = X;
}
