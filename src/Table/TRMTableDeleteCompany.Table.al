table 70703 "TRM Table Delete Company"
{
    Caption = 'Table Delete Company';
    DataClassification = SystemMetadata;
    DataPerCompany = false;

    fields
    {
        field(1; "Company Name"; Code[30])
        {
            Caption = 'Company Name';
            TableRelation = Company.Name;
        }
        field(10; Selected; Boolean)
        {
            Caption = 'Selected for Deletion';
        }
    }

    keys
    {
        key(PK; "Company Name")
        {
            Clustered = true;
        }
    }
}
