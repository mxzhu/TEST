IF  EXISTS (SELECT * FROM sys.objects WHERE name = 'uf_tra_GetNextTradingDateOrNoOfDaysforPreClerance_OS')
	DROP FUNCTION uf_tra_GetNextTradingDateOrNoOfDaysforPreClerance_OS
GO

/*-------------------------------------------------------------------------------------------------
Description:	This routine calculate next trading date and no of trading days  
				And return date or no of days for trading - as varchar - which need to be type cast for use 
				
Created by:		Rajashri
Created on:		23-Apr-2020

Modification History:
Modified By		Modified On		Description

Usage :
--Following include "Form Date" in calucation
select dbo.uf_tra_GetNextTradingDateOrNoOfDays(CONVERT(date, '2016-01-21'), null, CONVERT(date, '2016-01-29'), 1, 0, 0, 116001) -- return date
select dbo.uf_tra_GetNextTradingDateOrNoOfDays(CONVERT(date, '2016-01-21'), 8, null, 1, 1, 0, 116001) -- return no of days

--Following exclude "From Date" in calculation
select dbo.uf_tra_GetNextTradingDateOrNoOfDays(CONVERT(date, '2016-01-21'), null, CONVERT(date, '2016-01-29'), 0, 0, 0, 116001) -- return date
select dbo.uf_tra_GetNextTradingDateOrNoOfDays(CONVERT(date, '2016-01-21'), 8, null, 0, 1, 0, 116001) -- return no of days

--NOTE: Holidays will be stored in table and we have configuration at implementing company that use calendar days or trading days 
--------------------------------------------------------------------------------------------------*/

CREATE FUNCTION [dbo].[uf_tra_GetNextTradingDateOrNoOfDaysforPreClerance_OS]
(	
	@inp_dtFromDate			DATETIME,			-- date from which no of days to be caluculated
	@inp_nTradingDays		INT = NULL,			-- no of trading days to calculate, next trading date
	@inp_dtToDate			DATETIME = NULL,	-- date upto which no of days to be calculated
	@inp_bIncludeFromDate	BIT = 0,			-- flag to indicate if include from date into calculation - 1: include from Date, 0: exclude from date
	@inp_bRetOutDate		BIT = 1,			-- flag to indicate output as date or no of days - 1: Date 0: no of days 
	@inp_bCalcuatePastdate	BIT = 0,			-- flag to indicate if calcuate date after from date or prior (mostly used in trading window - not implemetned yet)
	@inp_nExchangeCodeId	INT = 116001		-- Default exchange code (NOTE - currently exchange type will not be pass, this will be used in future)
)
RETURNS VARCHAR(15) AS  
BEGIN
	DECLARE @sRetOutput VARCHAR(15)
	DECLARE @dtRetDate DATE
	DECLARE @nRetNoOfDays INT
	
	DECLARE @nTradingDaysCountType INT
	DECLARE @nDaysCount_TradingDays INT = 534001 
	DECLARE @nDaysCount_CalendarDays INT = 534002
	
	DECLARE @nBufferDays INT = CASE 
								WHEN @inp_nTradingDays IS NULL THEN 0 
								WHEN @inp_nTradingDays IS NOT NULL AND @inp_nTradingDays < 15 THEN 30 
								ELSE @inp_nTradingDays * 2 
								END
	DECLARE @dtNextDate DATETIME
	
	DECLARE @dtFrmDate	DATETIME = CONVERT(date, @inp_dtFromDate)
	DECLARE @dtToDate	DATETIME 
	DECLARE @dtTempToDate DATETIME
	
	DECLARE @nNonTradingDaysCount INT
	DECLARE @nTradingDaysCount INT
	
	-- get code from company table to check if company need to use trading days only or all days for trading
	SELECT @nTradingDaysCountType = PreclearnceValidyDateCountType_OS  FROM mst_Company WHERE IsImplementing = 1
	
	-- Check if calculate date from trading date or from "to date"
	IF (@inp_nTradingDays IS NOT NULL)
	BEGIN
		SET @nTradingDaysCount = @inp_nTradingDays
		
		-- check if trading days count type 
		IF (@nTradingDaysCountType = @nDaysCount_TradingDays)
		BEGIN
			-- check if calculate past date or future date
			IF (@inp_bCalcuatePastdate = 1)
			BEGIN
				SET @dtTempToDate = @dtFrmDate
				SET @dtFrmDate = DATEADD(DAY, (@inp_nTradingDays+@nBufferDays)*-1, @dtFrmDate)
				
				-- check if from date is included or not
				-- if not included then consider from date from next day
				IF (@inp_bIncludeFromDate = 0)
				BEGIN
					SET @dtTempToDate = DATEADD(DAY, -1, @dtTempToDate)
				END
			END
			ELSE 
			BEGIN
				-- check if from date is included or not
				-- if not included then consider from date from next day
				IF (@inp_bIncludeFromDate = 0)
				BEGIN
					SET @dtFrmDate = DATEADD(DAY, 1, @dtFrmDate)
				END
				
				SET @dtTempToDate = DATEADD(DAY, @inp_nTradingDays+@nBufferDays, @dtFrmDate)
			END
			
			-- Fetch all dates between 	@dtFrmDate and @dtTempToDate. These will be available in 'DateRange' table
			;WITH DateRange AS
			(
			  SELECT @dtFrmDate DateValue
			  UNION ALL
			  SELECT DateValue + 1 FROM DateRange WHERE DateValue + 1 <= @dtTempToDate
			),
			-- From the data available in 'DateRange' table, exclude all Holidays.
			WorkingDays as
			(
				SELECT  
					DateValue, 
					CASE 
						WHEN @inp_bCalcuatePastdate = 1 THEN ROW_NUMBER() OVER(ORDER BY DateValue DESC)
						ELSE ROW_NUMBER() OVER(ORDER BY DateValue)
					END AS RowNum 
				FROM DateRange M
				LEFT JOIN NonTradingDays H on CONVERT(date,M.DateValue) = CONVERT(date, H.NonTradDay) AND H.Exchangetype = @inp_nExchangeCodeId
				WHERE H.NonTradDay is null 
			)
			
			-- And finally fetch the date at Row #@inp_iTradingDays
			select @dtToDate = DateValue from WorkingDays where RowNum = @inp_nTradingDays
			
			OPTION (MAXRECURSION 0)
		END
		ELSE IF (@nTradingDaysCountType = @nDaysCount_CalendarDays)
		BEGIN
			-- check if from date is included or not
			-- if included then consider from "from" date given
			IF (@inp_bIncludeFromDate = 1)
			BEGIN
				SET @inp_nTradingDays = @inp_nTradingDays - 1
			END
			
			IF(@inp_bCalcuatePastdate = 1)
			BEGIN
				SET @inp_nTradingDays = @inp_nTradingDays * -1
			END
			
			SET @dtToDate = DATEADD(DAY, @inp_nTradingDays, @dtFrmDate)
		END
	END
	ELSE IF (@inp_dtToDate IS NOT NULL)
	BEGIN
		SET @dtToDate = CONVERT(date, @inp_dtToDate)
		
		-- check if trading days count type 
		IF (@nTradingDaysCountType = @nDaysCount_TradingDays)
		BEGIN
			IF(@inp_bCalcuatePastdate = 1)
			BEGIN
				-- in case past date calculation swap from date with to date to get count
				SET @dtTempToDate = @dtFrmDate
				
				SET @dtFrmDate = @dtToDate
				SET @dtToDate = @dtTempToDate
			END
		
			SELECT @nNonTradingDaysCount = COUNT(*) FROM NonTradingDays 
			WHERE Exchangetype = @inp_nExchangeCodeId AND CONVERT(date, NonTradDay) >= @dtFrmDate AND CONVERT(date, NonTradDay) <= @dtToDate
			
			-- check if "from date" is included in calculation or not -- if not included then reduce count 
			IF (EXISTS (SELECT * FROM NonTradingDays WHERE Exchangetype = @inp_nExchangeCodeId AND CONVERT(date, NonTradDay) = @dtFrmDate))
			BEGIN
				-- decrease count becuase from date is not included
				SET @nNonTradingDaysCount =  @nNonTradingDaysCount - 1
			END
			
			-- get difference and substract non trading days(holiday)
			SET @nTradingDaysCount = DATEDIFF(DAY, @dtFrmDate, @dtToDate) 
			-- @nNonTradingDaysCount
		END
		ELSE IF (@nTradingDaysCountType = @nDaysCount_CalendarDays)
		BEGIN
			SET @nTradingDaysCount = DATEDIFF(DAY, @dtFrmDate, @dtToDate)
			
			IF(@inp_bCalcuatePastdate = 1)
			BEGIN
				SET @nTradingDaysCount = @nTradingDaysCount * -1
			END
		END
		
		-- check if from date is included or not .. if from date included then consider from "from" date given
		IF (@inp_bIncludeFromDate = 1)
		BEGIN
			IF(@nTradingDaysCount < 0)
			BEGIN
				SET @nTradingDaysCount = @nTradingDaysCount + -1
			END
			ELSE
			BEGIN
				SET @nTradingDaysCount = @nTradingDaysCount + 1
			END
		END
		
	END
	
	SET @dtRetDate = @dtToDate
	
	SET @nRetNoOfDays = @nTradingDaysCount
	
	SET @sRetOutput = CASE WHEN	@inp_bRetOutDate = 1 THEN CONVERT(varchar, @dtRetDate) ELSE CONVERT(varchar, @nRetNoOfDays) END
		
	RETURN @sRetOutput
END


