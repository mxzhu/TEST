
/*
	CREATED BY  :	AKHILESH KAMATE
	CREATED ON  :	19-DEC-2015
	DESCRIPTION :	THIS TABLE IS USED TO MAINTAIN SFTP FILE DETAILS
*/

IF NOT EXISTS (SELECT NAME FROM SYS.TABLES WHERE UPPER(NAME) = 'du_SFTPFileDetails')
BEGIN

	CREATE TABLE du_SFTPFileDetails
	(
		SFTPFileDetailsID INT PRIMARY KEY IDENTITY(1,1) NOT NULL,
		MappingTableID INT NOT NULL,
		HostName VARCHAR(150) NOT NULL,
		UserName VARCHAR(150) NOT NULL,
		[Password] VARCHAR(150) NOT NULL,
		PortNumber INT NOT NULL,
		SshHostKeyFingerprint VARCHAR(250) NOT NULL,
		SourceFilePath VARCHAR(150) NOT NULL,
		CreatedBy INT NOT NULL,
		CreatedOn DATETIME NOT NULL,
		ModifiedBy INT NOT NULL,
		ModifiedOn DATETIME NOT NULL,	
	) 
	
	ALTER TABLE [dbo].[du_SFTPFileDetails]  WITH CHECK ADD  CONSTRAINT [FK_du_SFTPFileDetails_du_MappingTables] FOREIGN KEY([MappingTableID])
	REFERENCES [dbo].[du_MappingTables] ([MappingTableID])
	
END











	

