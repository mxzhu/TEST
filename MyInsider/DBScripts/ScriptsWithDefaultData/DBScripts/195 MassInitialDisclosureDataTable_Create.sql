
CREATE TYPE [dbo].[MassInitialDisclosureDataTable] AS TABLE(
	TransactionMasterId [int] NULL,
	UserName [nvarchar](250) NULL,
	PANNumber [nvarchar](100) NULL,
	DateOfBecomingInsider datetime NULL,
	SecurityType int NULL,
	ModeOfAcquisation int NULL,
	DateOfIntimationToCompany datetime,
	TradingForRelation int NULL,--Can be varchar also check
	FirstNameLastName [nvarchar](500) NULL,
	DEMATAccountNo NVARCHAR(50) NULL,
	StockExchange INT NULL,
	PercentOfSecurities decimal(5,2) NULL,
	LotSize [int] NULL,
	NumberOfSecurities decimal NULL,
	ValueOfSecurities decimal NULL
)
GO

----------------------------------------------------------------------------------------------------------------------

INSERT INTO DBUpdateStatus (ScriptNumber, ScriptFileName, Description, CreatedBy)
VALUES (195, '195 MassInitialDisclosureDataTable_Create', 'MassInitialDisclosureDataTable Create', 'Raghvendra')
