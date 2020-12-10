IF NOT EXISTS(SELECT name FROM SYS.tables WHERE [name]='rnt_MassUploadDetails')
BEGIN
	CREATE TABLE rnt_MassUploadDetails
	(
		RntInfoId			INT PRIMARY KEY IDENTITY(1,1) NOT NULL,
		RntUploadDate		DATETIME NOT NULL,
		PANNumber			VARCHAR(20),
		SecurityType		VARCHAR(50),
		SecurityTypeCode	VARCHAR(50),
		DPID				VARCHAR(50),
		ClientId			VARCHAR(50),
		DematAccountNo		VARCHAR(50),
		UserInfoId			VARCHAR(50),
		UserName			VARCHAR(200),
		Shares				DECIMAL(10,0),
		Equity				DECIMAL(10,2),
		Category			VARCHAR(50),
		CreatedBy			INT,
		CreatedOn			DATETIME,
		ModifiedBy			INT,
		ModifiedOn			DATETIME
	)
END
GO

----------------------------------------------------------------------------------------------------------------
INSERT INTO DBUpdateStatus (ScriptNumber, ScriptFileName, Description, CreatedBy)
VALUES (214, '214 rnt_MassUploadDetails_Create', 'rnt_MassUploadDetails Create', 'ED 18-Dec')
