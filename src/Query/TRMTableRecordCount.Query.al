query 70700 "TRM Table Record Count"
{
    // This query is referenced by the CalcFormula but not actually usable for dynamic counts.
    // Record counts are calculated via RecordRef in the codeunit instead.
    QueryType = Normal;

    elements
    {
        dataitem(TableDeleteLine; "TRM Table Delete Line")
        {
            column("Table_ID"; "Table ID") { }
            column(RecordCount)
            {
                Method = Count;
            }
        }
    }
}
