-- Alter Table
ALTER TABLE rul_TradingPolicy
ADD GenCashAndCashlessPartialExciseOptionForContraTrade INT NOT NULL DEFAULT(172001),
	GenSecuritiesPriortoAcquisitionManualInputorAutoCalculate BIT NOT NULL DEFAULT(0)
GO	
----------------------------------------------------------------------------------------------------------------
INSERT INTO DBUpdateStatus (ScriptNumber, ScriptFileName, Description, CreatedBy)
VALUES (205, '205 rul_TradingPolicy_Alter', 'rul_TradingPolicy alter', 'Tushar')

