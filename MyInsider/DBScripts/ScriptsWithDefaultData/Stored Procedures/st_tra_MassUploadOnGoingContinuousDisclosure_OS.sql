IF EXISTS(SELECT NAME FROM SYS.PROCEDURES WHERE NAME = 'st_tra_MassUploadOnGoingContinuousDisclosure_OS')
DROP PROCEDURE [dbo].[st_tra_MassUploadOnGoingContinuousDisclosure_OS]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[st_tra_MassUploadOnGoingContinuousDisclosure_OS]
	@inp_nTransactionMasterId			BIGINT = 0 
	,@inp_sUserLoginName				nvarchar(100) = null			--From Excel
	--,@inp_sPANNumber					nvarchar(50)					--From Excel
	,@inp_nRelationCodeId				INT							--The relation mentioned in the excel for finding the ForUserId. This is 100000 for Self
	,@inp_sFirstLastName				nvarchar(500)			--From Excel, this will be used for finding the ForUserId
	,@inp_dtDateOfAcquisition			DATETIME	
	,@inp_iModeOfAcquisitionCodeId		INT		--From Excel
	,@inp_dtDateOfInitimationToCompany	DATETIME		--From Excel
	,@inp_dSecuritiesPriorToAcquisition decimal(10, 0) = 0
	,@inp_sDMATDetailsINo				NVARCHAR(100)				--from Excel
	,@inp_nStockExchangeCodeId				INT		-- @inp_iExchangeCodeId
	,@inp_iTransactionTypeCodeId		INT 
	,@inp_iSecurityTypeCodeId			INT			--From Excel, if this is 0 then it will be no holdings and so the flag should be set to true	
	,@inp_dPerOfSharesPreTransaction	decimal	--Received from Excel -- for shares,debuntires etc
	,@inp_dPerOfSharesPostTransaction	decimal(5, 2) = 0
	,@inp_nNoOfSharesOrUnits			INT -- Quantity
	,@inp_dValue						decimal	--From Excel 
	,@inp_nESOPExerciseOptionQuantity	INT = 0
	,@inp_nOtherExerciseOptionQuantity	INT
	,@inp_nNoOfSecuritiesSoldForCashless INT -- Quantity2
	,@inp_dValue2						decimal(10, 0) = 0
	,@inp_iLotSize						INT			--From Excel For options and futures
	,@inp_sContractSpecification		NVARCHAR(50)
	,@inp_sISIN NVARCHAR(50)  -- from Excel
	,@inp_sCompanyName NVARCHAR(500) -- from Excel
	,@inp_iLoggedInUserId				INT		= 1 --default value from mapping table
	--,@inp_InsiderIDFlag					INT	 OUTPUT
	,@out_nReturnValue					INT = 0 OUTPUT
	,@out_nSQLErrCode					INT = 0 OUTPUT				-- Output SQL Error Number, if error occurred.
	,@out_sSQLErrMessage				VARCHAR(500) = '' OUTPUT  -- Output SQL Error Message, if error occurred.	/
	
	WITH RECOMPILE
	
AS 
BEGIN 

	BEGIN TRY
		
		--Error Codes Check these before final commmit
		DECLARE @ERR_INITIALDISCLOSURE INT = 11026
		DECLARE @ERROR_INVALIDUSERNAME INT = 11025
		DECLARE @ERROR_PANNOTASSOCIATED_WITH_USERNAME INT = 11325
		DECLARE @ERROR_RELATIVE_IS_INVALID INT = 17094
		DECLARE @ERROR_INITIALDISCLOSURE_SUBMITTED INT = 17051
		DECLARE @ERROR_NO_TRADING_POLICY_ASSOCIATED_WITH_USER INT = 11277
		DECLARE @ERROR_INVALIDDEMATNUMBER INT = 11037
		DECLARE @ERROR_UNCONFIGURED_DP_NAME INT = 11442

		DECLARE @SECURITY_TYPE_SHARES_CODEID INT = 139001
		
		DECLARE @ERROR_DEPOSITORY_ID_MANDATORY INT = 50553
		DECLARE @ERROR_NEW_DEMAT_INSERTED INT = 50554
		--Error Codes
		
		--For Transaction Master
		--DECLARE @inp_dSecuritiesPriorToAcquisition decimal(10, 0) = 0 --Default value o for initial disclosure
		--DECLARE @inp_dtDateOfAcquisition DATETIME		= dbo.uf_com_GetServerDate()--Default value as current date
		--DECLARE @inp_nTransactionMasterId		BIGINT = 0		--Will be found if present in the master table else will be 0
		DECLARE @inp_sPreclearanceRequestId		BIGINT = null	--Default value null
		DECLARE @inp_iUserInfoId INT					--Find from given username
		DECLARE @inp_sNoHoldingFlag				bit = null		--Will be set based on the SecurityType value from the Excel
		DECLARE @inp_iDisclosureTypeCodeId		INT = 147002			--For Continuous Disclosure
		DECLARE @inp_iTransactionStatusCodeId	INT = 148002			--Code for Not Confirmed value
		DECLARE @inp_iTradingPolicyId			INT = null			--Will have to find based on the applicable trading policy
			,@inp_dtPeriodEndDate			DATETIME = null		--NULL value
			,@inp_bPartiallyTradedFlag		bit = 0			-- Default value will not change
			,@inp_bSoftCopyReq				bit = 0			--Default Value 0
			,@inp_bHardCopyReq				bit = 0			--default Value 0
			,@inp_dtHCpByCOSubmission		DATETIME = null		-- NULL
			,@out_nDisclosureCompletedFlag	INT = 0 		-- 0 Default value
		
		--For Details
		DECLARE @inp_iDMATDetailsID INT = 0		--DEMAT DETAILS Id found
		DECLARE @inp_iTransactionDetailsId BIGINT		-- 0
		DECLARE @inp_iForUserInfoId INT	 = 0			--Will have to find this based on the Username, FirstNameLastName and the Relation in the excel
		DECLARE @inp_iCompanyId INT					--Find the implementation companyid
		--DECLARE @inp_iTransactionTypeCodeId INT = 143001	--Can have default value	143001
		DECLARE @inp_dQuantity2 decimal(10, 0) = 0
				--,@inp_dValue2 decimal(10, 0) = 0
				,@inp_iTransactionLetterId BIGINT	= NULL
				,@inp_dDateOfBecomingInsider DATETIME
		--DECLARE @inp_dPerOfSharesPostTransaction decimal(5, 2) = 0		--Default value as 0
		
		DECLARE @out_nSavedTransactionMasterID BIGINT, @out_nSavedTransactionDetailsID BIGINT
		
		DECLARE @bSegragateESOPAndOtherExerciseOptionQuantityFlag bit = 0
		--DECLARE @iESOPExerciseOptionQuantity INT = 0
		--DECLARE @iOtherExerciseOptionQuantity INT =0
		DECLARE @bESOPExerciseOptionQuantityFlag bit = 0
		DECLARE @bOtherExerciseOptionQuantityFlag bit = 0
		
		DECLARE @bIsMassUpload BIT = 0 -- set flag for mass upload
	
		DECLARE @tmp_tra_PreclearanceRequest table (PreclearanceRequestId BIGINT, SecuritiesToBeTradedQty DECIMAL(10,4), TotalQuantity DECIMAL(10,4)) 
		DECLARE @nRC INT		
		
		DECLARE @NoAutoSubmit_Transcation INT = 178001
		DECLARE @AutoSubmit_Transcation INT = 178002
		DECLARE @nAutoSubmitTransaction_Code INT 
		DECLARE @AllowedDEMATTable TABLE(DEMATID BIGINT, VALUE VARCHAR(200), Width VARCHAR(200))
		
		/*
			Change Start Here 
			Change add on 29-Jul-2016 by Tushar
			Variable Declaration
			
		*/
		
		DECLARE @dtInitialDisclosureDateOfAcquisation DATETIME
		DECLARE @nDisclosureType_Initial			INT = 147001
		DECLARE @nDateOfBecomingInsider DATETIME
		DECLARE @nDateOfJoining DATETIME
		DECLARE @nApplicationGoLiveDate	DATETIME
		DECLARE @nPeriodType								INT
		DECLARE @dtPEStartDate								DATETIME
		DECLARE @dtPEEndDate								DATETIME
		DECLARE @nYearCodeId								INT, 
				@nPeriodCodeId								INT 
		DECLARE @dtToday									DATETIME = dbo.uf_com_GetServerDate()
		DECLARE @ERR_AcqDateShouldBeGreaterThanInitialDisclosure INT = 17395 -- case #32 - Date Of acquisition must be greater than date of initial disclosure.
			
		
		DECLARE @Depository_ID		VARCHAR(100)
		DECLARE @DPBank				VARCHAR(100)	
		DECLARE @CompanyName varchar(300) = ''
		DECLARE @EnableDisableQuantity int; 
		/*
			Change End Here
		*/
	
		SET NOCOUNT ON;
		IF @out_nReturnValue IS NULL
			SET @out_nReturnValue = 0
		IF @out_nSQLErrCode IS NULL
			SET @out_nSQLErrCode = 0
		IF @out_sSQLErrMessage IS NULL
			SET @out_sSQLErrMessage = ''
		
		SELECT @EnableDisableQuantity = EnableDisableQuantityValue FROM mst_Company where IsImplementing=1
		IF(@EnableDisableQuantity <> 400001)
		BEGIN
			IF(@inp_iTransactionTypeCodeId = 143001)
			BEGIN
				IF(@inp_iSecurityTypeCodeId = 139004 OR @inp_iSecurityTypeCodeId = 139005)
				BEGIN
					SELECT TOP 1 @inp_nNoOfSharesOrUnits = Quantity,	@inp_dValue= Value, @inp_iLotSize = LotSize,@inp_sContractSpecification = ContractSpecification 
					FROM tra_QuantityValueDetails_OS where DisclouserType = 147002
				END
				ELSE
				BEGIN
					SELECT TOP 1 @inp_nNoOfSharesOrUnits = Quantity,	@inp_dValue= Value
					FROM tra_QuantityValueDetails_OS where DisclouserType = 147002
				END
			END
			ELSE IF(@inp_iTransactionTypeCodeId = 143002)
			BEGIN
				IF(@inp_iSecurityTypeCodeId = 139004 OR @inp_iSecurityTypeCodeId = 139005)
				BEGIN
					SELECT  @inp_nNoOfSharesOrUnits = 1,	@inp_dValue= 1, @inp_iLotSize = 1,@inp_sContractSpecification = 1 
					
				END
				ELSE
				BEGIN
					SELECT @inp_nNoOfSharesOrUnits = 1,	@inp_dValue= 1
				END
				 
			END
		END
		
		IF(@inp_nESOPExerciseOptionQuantity != 0)
		BEGIN 
			SET @bESOPExerciseOptionQuantityFlag = 1
			SET @bSegragateESOPAndOtherExerciseOptionQuantityFlag = 1			
		END
		IF(ISNULL(@inp_nOtherExerciseOptionQuantity ,0) != 0)
		BEGIN 
			SET @bOtherExerciseOptionQuantityFlag = 1
		END
		
		/* Code execute for Data Upload Utility */
		IF CHARINDEX('|',@inp_sDMATDetailsINo) > 0
		BEGIN
			SET @Depository_ID = ISNULL((select SUBSTRING(@inp_sDMATDetailsINo,(CHARINDEX('|',@inp_sDMATDetailsINo) + 1),LEN(@inp_sDMATDetailsINo))), '5')
			SET @inp_sDMATDetailsINo = (select SUBSTRING(@inp_sDMATDetailsINo,0,CHARINDEX('|',@inp_sDMATDetailsINo)))
		END
		
		--Check if userloginname is valid else give error message
		--Check if the PAN number is correct and is of the user else give error message
		--Check if it is for relative and Relativeis valid based on FirstNameLastName, userid, and relation else give error
		--Calculate Percent of the securities check how to calculate this value
		--Check if the details exist and Initial disclosure status is submitted then give error
		--Check if the details exist and Initial disclosure status is not submitted then delete the earlier one and add next.
		--Check the record exist based on login id if relation is Self or 0
		--For relatives check on the combination as discussed above
		
		--Check if the username is given is valid and find the userinfoid to be used further
		
		IF EXISTS(SELECT UserInfoID FROM usr_Authentication WHERE LoginID = @inp_sUserLoginName)
		BEGIN
			SELECT @inp_iUserInfoId = UserInfoID FROM usr_Authentication WHERE LoginID = @inp_sUserLoginName
			SELECT @inp_dDateOfBecomingInsider = DateOfBecomingInsider FROM usr_UserInfo WHERE UserInfoID = @inp_iUserInfoId
		END
		ELSE
		BEGIN
			SELECT @out_nReturnValue = @ERROR_INVALIDUSERNAME
			
			RETURN @out_nReturnValue
		END
		--Check if the user has already confirmed the initial disclosure in this case change is not allowed,.
		
		SELECT @nAutoSubmitTransaction_Code = AutoSubmitTransaction FROM mst_Company where IsImplementing = 1
		
		-- check auto submit transaction type, if transcation type is NOT Auto Submit then apply the following check 
		-- This check restrict user for uploading on-going continuous disclosure until initial disclosure is submitted
		IF(@nAutoSubmitTransaction_Code = @NoAutoSubmit_Transcation)
		BEGIN
			IF NOT EXISTS (SELECT * FROM tra_TransactionMaster_OS WHERE UserInfoId = @inp_iUserInfoId AND DisclosureTypeCodeId = 147001 AND TransactionStatusCodeId > 148002)
			BEGIN
				SELECT @out_nReturnValue = @ERROR_INITIALDISCLOSURE_SUBMITTED
				
				RETURN @out_nReturnValue
			END
		END
		
		SELECT @CompanyName = CompanyName,@inp_iCompanyId=RlCompanyId FROM rl_CompanyMasterList WHERE ISINCode = @inp_sISIN
		
		IF @inp_iSecurityTypeCodeId <> 139000
		BEGIN
			--If the security flag is 0 then consider the case of NOHOLDINGS
			SELECT @inp_sNoHoldingFlag = 0
			--For finding the Relatives id
			IF @inp_nRelationCodeId = 100000   --For Self
			BEGIN
				SELECT @inp_iForUserInfoId = @inp_iUserInfoId
			END
			ELSE							--For Relatives
			BEGIN
				IF EXISTS  (SELECT RelativesList.UserInfoIdRelative from (
						SELECT UR.UserInfoIdRelative FROM usr_UserInfo UI 
						JOIN usr_UserRelation UR ON UR.UserInfoId = UI.UserInfoId
						WHERE UR.UserInfoId = @inp_iUserInfoId  
						AND UR.RelationTypeCodeId = @inp_nRelationCodeId
						--AND LOWER(ISNULL(UI.FirstName,'') + ISNULL(UI.LastName,'')) = LOWER(@inp_sFirstLastName)
						) AS RelativesList
					join usr_UserInfo UI ON UI.UserInfoid = RelativesList.UserInfoIdRelative
					WHERE LOWER(ISNULL(UI.FirstName,'') + ISNULL(UI.LastName,'')) = LOWER(REPLACE(@inp_sFirstLastName,' ','')))
				BEGIN
					SELECT @inp_iForUserInfoId = RelativesList.UserInfoIdRelative from (
						SELECT UR.UserInfoIdRelative FROM usr_UserInfo UI 
						JOIN usr_UserRelation UR ON UR.UserInfoId = UI.UserInfoId
						WHERE UR.UserInfoId = @inp_iUserInfoId  
						AND UR.RelationTypeCodeId = @inp_nRelationCodeId
						--AND LOWER(ISNULL(UI.FirstName,'') + ISNULL(UI.LastName,'')) = LOWER(@inp_sFirstLastName)
						) AS RelativesList
					join usr_UserInfo UI ON UI.UserInfoid = RelativesList.UserInfoIdRelative
					WHERE LOWER(ISNULL(UI.FirstName,'') + ISNULL(UI.LastName,'')) = LOWER(REPLACE(@inp_sFirstLastName,' ',''))
				END
				ELSE
				BEGIN
					SELECT @out_nReturnValue = @ERROR_RELATIVE_IS_INVALID
					
					RETURN @out_nReturnValue
				END
			END
			--For finding the DEMATDetails id
			IF @inp_nRelationCodeId = 100000
			BEGIN
				SELECT @inp_iDMATDetailsID = DM.DMATDetailsId FROM usr_DMATDetails DM
				JOIN usr_UserInfo UI on UI.UserInfoid = DM.UserInfoId
				WHERE UI.UserInfoId = @inp_iUserInfoId AND DM.DEMATAccountNumber = @inp_sDMATDetailsINo
			END
			ELSE
			BEGIN
				SELECT @inp_iDMATDetailsID = DM.DMATDetailsId FROM usr_DMATDetails DM
				JOIN usr_UserInfo UI on UI.UserInfoid = DM.UserInfoId
				WHERE UI.UserInfoId = @inp_iForUserInfoId  AND DM.DEMATAccountNumber = @inp_sDMATDetailsINo
			END
			IF @inp_iDMATDetailsID IS NULL OR @inp_iDMATDetailsID = 0
			BEGIN
				
				/* 
					Code will execute for DataUploadUtility
						-	Check condition from "du_MappingTables" whether to add Demat or not
						-	Add DematNumber if it is does not exists in database 
				*/
				
				IF EXISTS (SELECT DisplayName FROM du_MappingTables WHERE DisplayName = 'AXISDIRECTFEED' AND Is_UploadDematFromFile = 1) AND CHARINDEX('|',@inp_sDMATDetailsINo) = 0
				BEGIN
					
					IF LEN(@inp_sDMATDetailsINo) = 8
					BEGIN
						EXEC st_usr_MassUploadDMATDetailsSave @inp_iForUserInfoId, 0, @inp_sDMATDetailsINo, 'Axis Direct','IN300484','','',121001,@inp_iForUserInfoId,0,0,''
					END
					ELSE IF LEN(@inp_sDMATDetailsINo) = 16
					BEGIN
						DECLARE @DP_ID VARCHAR(500)
						
						SET @DP_ID = (SELECT SUBSTRING(@inp_sDMATDetailsINo,0,9))
						
						EXEC st_usr_MassUploadDMATDetailsSave @inp_iForUserInfoId, 0, @inp_sDMATDetailsINo, 'Axis Direct', @DP_ID,'','',121001,@inp_iForUserInfoId,0,0,''
					END
					ELSE
					BEGIN
						EXEC st_usr_MassUploadDMATDetailsSave @inp_iForUserInfoId, 0, @inp_sDMATDetailsINo, 'Axis Direct',@inp_sDMATDetailsINo,'','',121001,@inp_iForUserInfoId,0,0,''
					END
											
					SELECT @inp_iDMATDetailsID = DM.DMATDetailsId FROM usr_DMATDetails DM
					JOIN usr_UserInfo UI on UI.UserInfoid = DM.UserInfoId
					WHERE UI.UserInfoId = @inp_iForUserInfoId  AND DM.DEMATAccountNumber = @inp_sDMATDetailsINo
					
					SELECT @out_nReturnValue = @ERROR_NEW_DEMAT_INSERTED
					
				END
				ELSE IF EXISTS (SELECT DisplayName FROM du_MappingTables WHERE DisplayName = 'ESOPDIRECTFEED' AND Is_UploadDematFromFile = 1)
				BEGIN
					
					IF @Depository_ID = 'IN300484'
					BEGIN
						
						SET @DPBank = 'Axis Direct'
						EXEC st_usr_MassUploadDMATDetailsSave @inp_iForUserInfoId, 0, @inp_sDMATDetailsINo, @DPBank ,@Depository_ID,'','',121001,@inp_iForUserInfoId,0,0,''
						
						SELECT @inp_iDMATDetailsID = DM.DMATDetailsId FROM usr_DMATDetails DM
						JOIN usr_UserInfo UI on UI.UserInfoid = DM.UserInfoId
						WHERE UI.UserInfoId = @inp_iForUserInfoId  AND DM.DEMATAccountNumber = @inp_sDMATDetailsINo
						PRINT @inp_iDMATDetailsID
						
						SELECT @out_nReturnValue = @ERROR_NEW_DEMAT_INSERTED
					END
					ELSE
					BEGIN
					
						SET @DPBank = ''
						EXEC st_usr_MassUploadDMATDetailsSave @inp_iForUserInfoId, 0, @inp_sDMATDetailsINo, @DPBank ,@Depository_ID,'','',121001,@inp_iForUserInfoId,0,0,''
						
						SELECT @inp_iDMATDetailsID = DM.DMATDetailsId FROM usr_DMATDetails DM
						JOIN usr_UserInfo UI on UI.UserInfoid = DM.UserInfoId
						WHERE UI.UserInfoId = @inp_iForUserInfoId  AND DM.DEMATAccountNumber = @inp_sDMATDetailsINo
						PRINT @inp_iDMATDetailsID
						
						SELECT @out_nReturnValue = @ERROR_NEW_DEMAT_INSERTED
						
					END
					
					IF @Depository_ID IS NULL OR @Depository_ID = ''
					BEGIN
						
						SELECT @out_nReturnValue = @ERROR_DEPOSITORY_ID_MANDATORY
						RETURN @out_nReturnValue

					END
				END
				ELSE
				BEGIN
					
					SELECT @out_nReturnValue = @ERROR_INVALIDDEMATNUMBER
					RETURN @out_nReturnValue
				END
				--print @ERROR_INVALIDDEMATNUMBER
				
			END
		END
		
		/*Check if the Provided DEMAT Number is amongst the allowed DEMAT accounts as per the configuration done at Company Level*/

			INSERT INTO @AllowedDEMATTable
			SELECT * from dbo.uf_com_GetApplicableDEMATList(@inp_iForUserInfoId, @inp_iDisclosureTypeCodeId, 0)

			IF(NOT EXISTS(SELECT DEMATID FROM @AllowedDEMATTable WHERE DEMATID = @inp_iDMATDetailsID))
			BEGIN
				SELECT @out_nReturnValue = @ERROR_UNCONFIGURED_DP_NAME
				
				RETURN @out_nReturnValue
			END

		/*Check if the Provided DEMAT Number is amongst the allowed DEMAT accounts as per the configuration done at Company Level*/


		--ELSE
		--BEGIN
		--	SELECT @inp_sNoHoldingFlag = 1
			
		--END	
		
		
		--Check if the userlogin name and PAN are matching for the same user else give error.
		--IF NOT EXISTS(SELECT PAN FROM usr_UserInfo WHERE UserInfoId = @inp_iUserInfoId AND PAN = @inp_sPANNumber)
		--BEGIN
		--	SELECT @out_nReturnValue = @ERROR_PANNOTASSOCIATED_WITH_USERNAME
			
		--	RETURN @out_nReturnValue
		--END
		--Find the applicable trading policy for the user. If none found then give corresponding error
		IF EXISTS (SELECT * FROM vw_ApplicableTradingPolicyForUser_OS WHERE UserInfoId = @inp_iUserInfoId)
		BEGIN
		
			SELECT @inp_iTradingPolicyId = MAX(MaptoId) FROM vw_ApplicableTradingPolicyForUser_OS 
			WHERE UserInfoId = @inp_iUserInfoId
			
		/*
		   Change Start Here
			Change add on 29-Jul-2016 by Tushar
			
			If User in Insider Type - 
							IF Date of Becoming Insider  <=  Go live date set in Trading policy under the label 
															 (Initial Disclosure before of application go live)
									THEN Date of Acquisition of Initial Disclosure is =  applicable Periods first date.
							ELSE
									THEN Date of Acquisition of Initial Disclosure is = Date of Becoming Insider
							IF User is Non Insider Type-
							IF Date of Joining  <=  Go live date set in Trading policy under the label 
															 (Initial Disclosure before of application go live)
									THEN Date of Acquisition of Initial Disclosure is =  applicable Periods first date.
							ELSE
									THEN Date of Acquisition of Initial Disclosure is = Date of Joining
		
		Note:- Autosumbission flag doesnot used this change 
	   */
		
		SELECT TOP 1 @dtInitialDisclosureDateOfAcquisation = TD.DateOfAcquisition FROM tra_TransactionMaster_OS TM
		JOIN tra_TransactionDetails_OS TD ON TM.TransactionMasterId = TD.TransactionMasterId
		WHERE TM.UserInfoId = @inp_iUserInfoId
		AND DisclosureTypeCodeId  = @nDisclosureType_Initial
		ORDER BY DateOfAcquisition DESC
		/*
			If Initial disclosure is present in DB then use lowest Date of Acquisation of Initial disclosure records else calculate date of acquasation
			on the basis of above logic. 
		*/	
		Declare @dtPeriodEndDate Datetime
		SELECT
						@nPeriodType = DiscloPeriodEndFreq
					FROM rul_TradingPolicy_OS
					WHERE TradingPolicyId = @inp_iTradingPolicyId
				
				
				--SELECT @nDateOfBecomingInsider,@nDateOfJoining,@nApplicationGoLiveDate,@nPeriodType
				----print 'Find PE dates'
				SET @nPeriodType = CASE WHEN @nPeriodType = 137001 THEN 123001 -- Yearly
									WHEN @nPeriodType = 137002	THEN 123003 -- Quarterly
									WHEN @nPeriodType = 137003	THEN 123004 -- Monthly
									WHEN @nPeriodType = 137004	THEN 123002 -- Weekly
									ELSE @nPeriodType
									END

				EXECUTE st_tra_PeriodEndDisclosureStartEndDate2
				   @nYearCodeId OUTPUT, @nPeriodCodeId OUTPUT,@dtToday, @nPeriodType, 0, @dtPEStartDate OUTPUT, @dtPeriodEndDate OUTPUT, @out_nReturnValue OUTPUT, @out_nSQLErrCode OUTPUT, @out_sSQLErrMessage OUTPUT
			
		IF(@dtInitialDisclosureDateOfAcquisation IS NULL OR @dtInitialDisclosureDateOfAcquisation = '')
		BEGIN
			IF(@nAutoSubmitTransaction_Code = @AutoSubmit_Transcation )
			BEGIN
					SELECT @nDateOfBecomingInsider = DateOfBecomingInsider,
							@nDateOfJoining =  DateOfJoining  
					FROM usr_UserInfo WHERE UserInfoId = @inp_iUserInfoId
				
					SELECT @nApplicationGoLiveDate = DiscloInitDateLimit,
						@nPeriodType = StExMultiTradeFreq
					FROM rul_TradingPolicy_OS
					WHERE TradingPolicyId = @inp_iTradingPolicyId
				
				
				--SELECT @nDateOfBecomingInsider,@nDateOfJoining,@nApplicationGoLiveDate,@nPeriodType
				----print 'Find PE dates'
				SET @nPeriodType = CASE WHEN @nPeriodType = 137001 THEN 123001 -- Yearly
									WHEN @nPeriodType = 137002	THEN 123003 -- Quarterly
									WHEN @nPeriodType = 137003	THEN 123004 -- Monthly
									WHEN @nPeriodType = 137004	THEN 123002 -- Weekly
									ELSE @nPeriodType
									END

				EXECUTE st_tra_PeriodEndDisclosureStartEndDate2
				   @nYearCodeId OUTPUT, @nPeriodCodeId OUTPUT,@dtToday, @nPeriodType, 0, @dtPEStartDate OUTPUT, @dtPEEndDate OUTPUT, @out_nReturnValue OUTPUT, @out_nSQLErrCode OUTPUT, @out_sSQLErrMessage OUTPUT
				
					IF (@nDateOfBecomingInsider IS NOT NULL AND @nDateOfBecomingInsider <= @nApplicationGoLiveDate)
					BEGIN
						SET @dtInitialDisclosureDateOfAcquisation = @dtPEStartDate
					END
					ELSE IF @dtInitialDisclosureDateOfAcquisation IS NOT NULL AND @nDateOfBecomingInsider > @nApplicationGoLiveDate
					BEGIN
						SET @dtInitialDisclosureDateOfAcquisation = @nDateOfBecomingInsider
					END
					ELSE IF @nDateOfBecomingInsider IS NULL AND @nDateOfJoining <= @nApplicationGoLiveDate
					BEGIN
						SET @dtInitialDisclosureDateOfAcquisation = @dtPEStartDate
					END
					ELSE IF @nDateOfBecomingInsider IS NULL AND @nDateOfJoining > @nApplicationGoLiveDate
					BEGIN
						SET @dtInitialDisclosureDateOfAcquisation = @nDateOfJoining
					END
				END
			END

			ELSE IF(@nAutoSubmitTransaction_Code = @NoAutoSubmit_Transcation)
			BEGIN
			IF EXISTS(select DateOfAcquisition from tra_TransactionMaster_OS TM join tra_TransactionDetails_OS TD on tm.TransactionMasterId=td.TransactionMasterId
			where DisclosureTypeCodeId=147001 and UserInfoId=@inp_iUserInfoId)
			BEGIN
				SET @dtInitialDisclosureDateOfAcquisation = (select TOP 1 DateOfAcquisition from tra_TransactionMaster_OS TM join tra_TransactionDetails_OS TD on tm.TransactionMasterId=td.TransactionMasterId
			    where DisclosureTypeCodeId=147001 and UserInfoId=@inp_iUserInfoId)
			END
			ELSE
			BEGIN
				SET @dtInitialDisclosureDateOfAcquisation = dbo.uf_com_GetServerDate()
			END
				
			END
			
			IF CONVERT(DATE, @inp_dtDateOfAcquisition) < CONVERT(DATE,@dtInitialDisclosureDateOfAcquisation)
			BEGIN
				SET @out_nReturnValue = @ERR_AcqDateShouldBeGreaterThanInitialDisclosure
				RETURN @out_nReturnValue
			END
			
		/*
			Change End Here
		*/
				
				SELECT @out_nReturnValue = 0
		END
		ELSE
		BEGIN
			SELECT @out_nReturnValue = @ERROR_NO_TRADING_POLICY_ASSOCIATED_WITH_USER
			RETURN @out_nReturnValue
		END
		--Find the implementation companyid 
		--SELECT @inp_iCompanyId = CompanyId FROM mst_Company WHERE IsImplementing = 1
		
		SELECT @inp_sPreclearanceRequestId = NULL
		
		--SELECT @inp_sPreclearanceRequestId = PreclearanceRequestId
		--  FROM tra_PreclearanceRequest PR
		--  WHERE TransactionTypeCodeId = @inp_iTransactionTypeCodeId
		--  AND SecurityTypeCodeId = @inp_iSecurityTypeCodeId
		--  AND UserInfoId = @inp_iUserInfoId
		--  AND PreclearanceStatusCodeId = 144002
		--  AND IsPartiallyTraded = 1
		
		INSERT INTO @tmp_tra_PreclearanceRequest
  SELECT PR.PreclearanceRequestId , PR.SecuritiesToBeTradedQty, 0 FROM tra_PreclearanceRequest_NonImplementationCompany PR
  --INNER JOIN tra_TransactionMaster TM ON PR.PreclearanceRequestId = TM.PreclearanceRequestId
  --LEFT JOIN tra_TransactionDetails TD ON TM.TransactionMasterId = TD.TransactionMasterId
  
  WHERE PR.PreclearanceStatusCodeId = 144002 -- Approved 
  AND PR.IsPartiallyTraded = 1
  AND PR.TransactionTypeCodeId = @inp_iTransactionTypeCodeId
  AND PR.SecurityTypeCodeId = @inp_iSecurityTypeCodeId
  AND PR.UserInfoId = @inp_iUserInfoId
  AND PR.DMATDetailsID = @inp_iDMATDetailsID
  AND PR.CompanyId = @inp_iCompanyId


  UPDATE TPR
  SET TPR.TotalQuantity =  A.TotalSum
  FROM @tmp_tra_PreclearanceRequest TPR
  INNER JOIN (SELECT TPR1.PreclearanceRequestId, SUM(ISNULL(TD.Quantity, 0)) AS TotalSum
				  FROM @tmp_tra_PreclearanceRequest TPR1
						INNER JOIN tra_TransactionMaster_OS TM ON TPR1.PreclearanceRequestId = TM.PreclearanceRequestId
						LEFT JOIN tra_TransactionDetails_OS TD ON TM.TransactionMasterId = TD.TransactionMasterId
					GROUP BY TPR1.PreclearanceRequestId
					) A ON A.PreclearanceRequestId = TPR.PreclearanceRequestId
 
  --SELECT TOP 1 @inp_sPreclearanceRequestId = PreclearanceRequestId FROM @tmp_tra_PreclearanceRequest WHERE SecuritiesToBeTradedQty > TotalQuantity
  --ORDER BY PreclearanceRequestId DESC
		
		IF(@inp_sPreclearanceRequestId IS NOT NULL AND @inp_sPreclearanceRequestId != 0)
		BEGIN
			SELECT @out_nSavedTransactionMasterID = TM.TransactionMasterId FROM tra_TransactionMaster_OS TM
			WHERE TM.UserInfoId = @inp_iUserInfoId AND TM.DisclosureTypeCodeId = @inp_iDisclosureTypeCodeId 
			AND TM.PreclearanceRequestId = @inp_sPreclearanceRequestId
			AND TM.TransactionStatusCodeId IN (@inp_iTransactionStatusCodeId)
			
			IF(@out_nSavedTransactionMasterID IS NULL OR @out_nSavedTransactionMasterID = 0)
			BEGIN
				EXEC @nRC = dbo.st_tra_TradingTransactionMasterCreate_Override_OS
									0,
									@inp_sPreclearanceRequestId,
									@inp_iUserInfoId,
									@inp_iDisclosureTypeCodeId,
									@inp_iTransactionStatusCodeId,
									@inp_sNoHoldingFlag,
									@inp_iTradingPolicyId,
									@dtPeriodEndDate,
									@inp_bPartiallyTradedFlag,
									@inp_bSoftCopyReq,
									@inp_bHardCopyReq,
									@inp_iLoggedInUserId,
									'MASSUPLOAD',
									NULL,
									0,
									@out_nSavedTransactionMasterID out, 
									@out_nDisclosureCompletedFlag out,
									@out_nReturnValue out, 
									@out_nSQLErrCode out, 
									@out_sSQLErrMessage out
				
				IF(@out_nReturnValue = 0)
				BEGIN
					-- auto submit transcation 
					EXEC st_tra_TradingTransaction_Auto_Submit
							@out_nSavedTransactionMasterID, 
							@bIsMassUpload,
							@out_nReturnValue OUTPUT, 
							@out_nSQLErrCode OUTPUT, 
							@out_sSQLErrMessage OUTPUT	
				END
			END
		END
		ELSE 
		BEGIN
		
			SELECT @inp_sPreclearanceRequestId = NULL
			
			--SELECT @out_nSavedTransactionMasterID = TM.TransactionMasterId FROM tra_TransactionMaster_OS TM
			--INNER JOIN tra_TransactionDetails_OS TD ON TM.TransactionMasterId = TD.TransactionMasterId
			--WHERE TM.UserInfoId = @inp_iUserInfoId AND TM.DisclosureTypeCodeId = @inp_iDisclosureTypeCodeId 
			--AND	TD.SecurityTypeCodeId = @inp_iSecurityTypeCodeId
			--AND TM.PreclearanceRequestId IS NULL
			--AND TM.TransactionStatusCodeId IN (@inp_iTransactionStatusCodeId)
			--AND TD.DateOfAcquisition = @inp_dtDateOfAcquisition
			--AND TD.CompanyId = @inp_iCompanyId
			
			--Below code have already commentted
			--If the transaction already exist then delete the Transaction details for the transaction.
			--IF EXISTS(SELECT * FROM tra_TransactionMaster WHERE UserInfoId = @inp_iUserInfoId AND DisclosureTypeCodeId = @inp_iDisclosureTypeCodeId AND SecurityTypeCodeId = @inp_iSecurityTypeCodeId)
			--BEGIN
			--	DELETE FROM tra_TransactionDetails 
			--	WHERE TransactionMasterId = (SELECT TransactionMasterId FROM tra_TransactionMaster 
			--	WHERE UserInfoId = @inp_iUserInfoId AND DisclosureTypeCodeId = @inp_iDisclosureTypeCodeId)
			--	 AND SecurityTypeCodeId = @inp_iSecurityTypeCodeId AND DMATDetailsId = @inp_iDMATDetailsID AND ForUserInfoId = @inp_iForUserInfoId
			--END
			--ELSE 
			IF(@out_nSavedTransactionMasterID IS NULL OR @out_nSavedTransactionMasterID = 0)
			BEGIN
				EXEC @nRC = dbo.st_tra_TradingTransactionMasterCreate_Override_OS 
									0,
									@inp_sPreclearanceRequestId,
									@inp_iUserInfoId,
									@inp_iDisclosureTypeCodeId,
									@inp_iTransactionStatusCodeId,
									@inp_sNoHoldingFlag,
									@inp_iTradingPolicyId,
									@dtPeriodEndDate,
									@inp_bPartiallyTradedFlag,
									@inp_bSoftCopyReq,
									@inp_bHardCopyReq,
									@inp_iLoggedInUserId,
									'MASSUPLOAD',
									NULL,
									0,
									@out_nSavedTransactionMasterID out, 
									@out_nDisclosureCompletedFlag out,
									@out_nReturnValue out, 
									@out_nSQLErrCode out, 
									@out_sSQLErrMessage out	
				
				IF(@out_nReturnValue = 0)
				BEGIN
					-- auto submit transcation 
					EXEC st_tra_TradingTransaction_Auto_Submit
							@out_nSavedTransactionMasterID, 
							@bIsMassUpload,
							@out_nReturnValue OUTPUT, 
							@out_nSQLErrCode OUTPUT, 
							@out_sSQLErrMessage OUTPUT	
				END
			END
		END 
		
		
		IF (@out_nReturnValue = 0)
		BEGIN
		 --   IF @inp_sNoHoldingFlag = 0
			--BEGIN
			--	IF @inp_iSecurityTypeCodeId = @SECURITY_TYPE_SHARES_CODEID
			--	BEGIN
			--		SELECT @iOtherExerciseOptionQuantity = @inp_dQuantity
			--	END
			IF(@inp_iLotSize IS NULL OR @inp_iLotSize = '')
			BEGIN
			  SET @inp_iLotSize = 0
			END 

			SET @inp_nOtherExerciseOptionQuantity = @inp_nNoOfSharesOrUnits
			
				EXEC st_tra_TradingTransactionSave_Override_OS 0, @out_nSavedTransactionMasterID, @inp_iSecurityTypeCodeId,@inp_iForUserInfoId,@inp_iDMATDetailsID,@inp_iCompanyId,@inp_dtDateOfAcquisition ,@inp_dtDateOfInitimationToCompany ,@inp_iModeOfAcquisitionCodeId ,@inp_nStockExchangeCodeId,@inp_iTransactionTypeCodeId,@inp_nNoOfSharesOrUnits,@inp_dValue,@inp_iLotSize,@inp_sContractSpecification,@CompanyName,@inp_iLoggedInUserId,'MASSUPLOAD',@inp_nOtherExerciseOptionQuantity,@out_nSavedTransactionDetailsID out,@out_nReturnValue out, @out_nSQLErrCode out, @out_sSQLErrMessage out 
			--END
		END
		SELECT @out_nSavedTransactionMasterID
		
		RETURN @out_nReturnValue
	END	 TRY
	
	BEGIN CATCH		
		SET @out_nSQLErrCode    =  ERROR_NUMBER()
		SET @out_sSQLErrMessage =   ERROR_MESSAGE()
		SET @out_nReturnValue = @out_nSQLErrCode --dbo.uf_com_GetErrorCode(@ERR_INITIALDISCLOSURE,ERROR_NUMBER())
		RETURN @out_nReturnValue
	END CATCH
END

