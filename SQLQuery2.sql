USE [FIGMDHQIManagementABFM]
GO
/****** Object:  StoredProcedure [dbo].[ABFMCPCPlusLocationWiseReport]    Script Date: 12/10/2018 12:37:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER Procedure  [dbo].[ABFMCPCPlusLocationWiseReport]
As	
Begin

Declare @Query nvarchar(max)
Declare @Management varchar(100)
Declare @Rt_table varchar(100)
Declare @MipsDB varchar(100)
Declare @MipsTable varchar(100)
Declare @Status varchar(100)
Declare @Society varchar(100)
Declare @temptablename varchar(100)
Declare @iDevDbName varchar(100)

Select @Society=Society,@Management=Management,@Rt_table=[RT Table],@MipsDB=MipsDB,@MipsTable=MipsTable,@Status=[RT Status Column],@temptablename=TempTableName,@iDevDbName=iDevDbName From idev_registrydetails


if(OBJECT_ID('TempDB.dbo.#RTDetails') is not null)
drop table #RTDetails 

select * into #RTDetails
from
( 
select distinct p.externalid,p.ListName, RT.practiceuid,RT.name,RT.value
from FIGMDHQIManagementABFM.dbo.RT_CustomField rt 
inner join FIGMDHQIManagementABFM.dbo.practice p on p.practiceuid=rt.practiceuid
where rt.inactive=0
)a
PIVOT 
(
    MAX(VALUE) FOR NAME in ([EMR],[Client Account Manager],[ABFM Status],[Practice Status],[MIPS Components],[Pace],[ACC Resource],[Active Lead Last Email Sent],[Admin User],[Admin User Email],[Athena Context #],[Authorized to submit to Christiana CMMI project],[Client / CAM Action],[Elements Mapped],
[EMR Hosting],[EMR Version],[Estimated Date To Next Status],[Estimated Date To Production],[ Exec Intervention Requested],[Extract Frequency],[Extract Start Time],[Extract Stop Time],[FIGMD Resource],
[Last Extract Date],[Lead Physician Contact],[Location Count],[Mapped Core Measures],[Mapped PQRI Measures],[NDA In Place With EMR Vendor ],[Password],[PM Information],[PM System],[PM System Version],[PQRS],
[Practice Address],[Practice Admin Contact],[Practice ID],[Practice Key],[Practice Name],[Practice Notes],[Practice Participation Motivation],[Practice Status Summary],[Practice Technical Contact],[Practice Timezone],
[Provider Count],[Recent Summary],[Research Coordinator Email],[Risk Profile],[Scorecard URL],[Step],[Submission File Type],[Submission Type],[Support Ticket],[Survey Emails To],[Technical Survey Link],
[Technical User Email],[Ticket Comment],[Vendor Agreement In Place With EMR Vendor] )
) 
Pvt

if(OBJECT_ID('TempDB.dbo.#RT1') is not null)
    drop table #RT1
 select * into #RT1 from 
 (select p.externalid,p.listname,r.fieldname,r.value
 from practice p 
 left join CustomFieldDataCollectionFRED r  on p.practiceuid=r.practiceuid 
 where p.inactive=0) a
 PIVOT
 (
 MAX(value) for fieldname in ([CPCPlus(Yes/No)],[ACO])
 ) pvt

 if(OBJECT_ID('TempDB.dbo.#CPCPlusPractices') is not null)
    drop table #CPCPlusPractices

    select p.externalid,p.listname,rr.DisplayName as CPC--,rr1.DisplayName as ACO
	into #CPCPlusPractices
 from #RT1 p 
 left join CustomFieldOptionsFRED rr on p.[CPCPlus(Yes/No)]=rr.customfieldoptionsmasteruid
 --left join CustomFieldOptionsFRED rr1 on p.[ACO]=rr1.customfieldoptionsmasteruid
 where rr.DisplayName='Yes' --or rr1.DisplayName='Yes'	

--------------MIPS Dashboard raw data------------------------------

if(OBJECT_ID('TempDB.dbo.##DashboardRawData2') is not null)
drop table ##DashboardRawData2 


declare @QuarterEndDate datetime='2017-12-31 00:00:00.000'
declare @flag varchar(10)='QCNR'

select distinct rt.externalid PracticeId,rt.listname PracticeName,sp.Name [Location Name],sp.ID [Location Id],
rt.EMR,rt.[Client Account Manager][CAM/CAE],rt.[ABFM Status] as Status,isnull(rt.[Practice Status],'')[Practice Status],isnull(rt.[MIPS Components],'')[MIPS Components],isnull(rt.[Pace],'')[Pace],
''[GPRO/Individual],''[DRCF],
(n.Displayname +' '+n.ID) MeasureID,CMSPQRSSubmissionNo [CMS ID],n.MeasureDescription [Measure Name],
case when IsInverseMeasure=1 then 'Yes' else 'No' end as IsInverseMeasure,
case when CMSPQRSSubmissionNo in ('159v5','165v5','122v5') then 'Yes' else 'No' end as IsOutcomeMeasure,
case when CMSPQRSSubmissionNo in ('156v5','149v5','139v5','137v5') then 'Yes' else 'No' end as IsComplexCareMeasures,
case when CMSPQRSSubmissionNo in ('50v5','124v5','130v5','131v5','138v5','166v6','125v5') then 'Yes' else 'No' end as IsOtherMeasures,
Numerator,Denominator,cast((Average *100) as decimal(10,2)) Percentage,cast(Numerator as varchar)+'/'+cast(Denominator as varchar) [N/D],
cast(Numerator as varchar)+'/'+cast(Denominator as varchar)+'='+cast(cast((Average *100) as decimal(10,2)) as varchar) [Dashboard Performance],
mcs.PracticeUid
into ##DashboardRawData2
From ABFM_FIGMDPQRSWeb.dbo.PQRSMeasureComputationSummary_2017 mcs (nolock)
inner join PQRSNationalProgramQualityMeasure n (nolock) on n.PQRSNationalProgramQualityMeasureUid=mcs.PQRSNationalProgramQualityMeasureUid
inner join ViewFacility sp (nolock) on sp.Practiceuid=mcs.PracticeUid and sp.Servicelocationuid=mcs.Locationuid and sp.inactive=0 
--inner join ViewServiceProvider sp (nolock) on sp.Practiceuid=mcs.PracticeUid and sp.Serviceprovideruid=mcs.Provideruid and sp.inactive=0 and sp.Type in(1,3)
inner join #RTDetails rt on rt.PracticeUid=mcs.PracticeUid
inner join #CPCPlusPractices cpc on cpc.externalid=rt.externalid
where Provideruid is null and Locationuid is not null
and mcs.flag =@flag and QuarterEndDate=@QuarterEndDate
--and n.CMSPQRSSubmissionNo in('159v5','165v5','122v5','156v5','149v5','139v5','137v5','50v5','124v5','130v5','131v5','138v5','166v6','125v5')
order by rt.externalid,sp.ID



--if(OBJECT_ID('ABFM_TMPTables.dbo.MIPSDashboardRawData2') is not null)
--drop table ABFM_TMPTables.dbo.MIPSDashboardRawData2

--select * into ABFM_TMPTables.dbo.MIPSDashboardRawData2 from ##DashboardRawData2

if(OBJECT_ID('TempDB.dbo.##DashboardData2') is not null)
drop table ##DashboardData2 

select * into ##DashboardData2 from ##DashboardRawData2

update ##DashboardData2 set MeasureId='PRIME 37' where MeasureId in('PRIME 37-A','PRIME 37-B')
update ##DashboardData2 set MeasureId='PRIME 38' where MeasureId in('PRIME 38-BHW','PRIME 38-BHW-1','PRIME 38-BHW-2','PRIME 38-CN','PRIME 38-CN-1','PRIME 38-CN-2','PRIME 38-PA','PRIME 38-PA-1','PRIME 38-PA-2')
update ##DashboardData2 set MeasureId='PRIME 42' where MeasureId in('PRIME 42-1','PRIME 42-2')
update ##DashboardData2 set MeasureId='PRIME 44' where MeasureId in('PRIME 44-1','PRIME 44-2','PRIME 44-3','PRIME 44-4')
update ##DashboardData2 set MeasureId='PRIME 57' where MeasureId in('PRIME 57-A','PRIME 57-B')
update ##DashboardData2 set MeasureId='PRIME 58' where MeasureId in('PRIME 58-A','PRIME 58-B')
update ##DashboardData2 set MeasureId='PRIME 64' where MeasureId in('PRIME 64-A','PRIME 64-B')
update ##DashboardData2 set MeasureId='PRIME 69' where MeasureId in('PRIME 69-A','PRIME 69-B','PRIME 69-C')
update ##DashboardData2 set MeasureId='PRIME 72' where MeasureId in('PRIME 72-H','PRIME 72-HA','PRIME 72-L','PRIME 72-LA','PRIME 72-M','PRIME 72-MA')
update ##DashboardData2 set MeasureId='PRIME 87' where MeasureId in('PRIME 87-A','PRIME 87-B','PRIME 87-C')
update ##DashboardData2 set MeasureId='PRIME 88' where MeasureId in('PRIME 88-1','PRIME 88-1-S1','PRIME 88-1-S2','PRIME 88-2','PRIME 88-2-S1','PRIME 88-2-S2')
update ##DashboardData2 set MeasureId='QPP 37' where MeasureId in('QPP 37-A','QPP 37-B')
update ##DashboardData2 set MeasureId='QPP 57' where MeasureId in('QPP 57-A','QPP 57-B')
update ##DashboardData2 set MeasureId='QPP 59' where MeasureId in('QPP 59-A','QPP 59-B')
update ##DashboardData2 set MeasureId='QPP 60' where MeasureId in('QPP 60-A','QPP 60-B')

If ( object_id( 'TempDB.dbo.#AllMeasureCount', 'U' ) is not null )
		Drop Table #AllMeasureCount

select PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
COUNT(distinct [MeasureID])[Non-zero performance on # of Other Measures]
into #AllMeasureCount
from
(
Select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
case when MeasureID like '%-%' then left(MeasureID,charindex('-',MeasureID)-1) else MeasureID end as MeasureID,[CMS ID],Denominator,Numerator,Percentage
from ##DashboardData2 ad
where IsOtherMeasures='Yes' and IsInverseMeasure='No' and Percentage > 0.00
union
Select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
case when MeasureID like '%-%' then left(MeasureID,charindex('-',MeasureID)-1) else MeasureID end as MeasureID,[CMS ID],Denominator,Numerator,Percentage
from ##DashboardData2 ad
where IsOtherMeasures='Yes' and IsInverseMeasure='Yes' and Denominator > 0 and Percentage <> 100
) a
group by PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace]
order by PracticeId,[Location Id]

--------------OutCome Measure Counts------------------------------
If ( object_id( 'TempDB.dbo.#OutComeMeasuresCounts', 'U' ) is not null )
		Drop Table #OutComeMeasuresCounts

select PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
COUNT(distinct [MeasureID])[Non-zero performance on # of OutCome measures]
into #OutComeMeasuresCounts
from
(
Select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
case when MeasureID like '%-%' then left(MeasureID,charindex('-',MeasureID)-1) else MeasureID end as MeasureID,Denominator,Numerator,Percentage
from ##DashboardData2 ad
where IsInverseMeasure='No' and Percentage > 0.00 and IsOutcomeMeasure='Yes'
union
Select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
case when MeasureID like '%-%' then left(MeasureID,charindex('-',MeasureID)-1) else MeasureID end as MeasureID,Denominator,Numerator,Percentage
from ##DashboardData2 ad
where IsInverseMeasure='Yes' and Denominator > 0 and Percentage <> 100 and IsOutcomeMeasure='Yes'
) a
group by PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace]
order by PracticeId,[Location Id]


--------------High Priority Measure Counts------------------------------

If ( object_id( 'TempDB.dbo.#ComplexCareMeasureCounts', 'U' ) is not null )
		Drop Table #ComplexCareMeasureCounts

select PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
COUNT(distinct [MeasureID])[Non-zero performance on # of Complex Care Measures]
into #ComplexCareMeasureCounts
from
(
Select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
case when MeasureID like '%-%' then left(MeasureID,charindex('-',MeasureID)-1) else MeasureID end as MeasureID,Denominator,Numerator,Percentage
from ##DashboardData2 ad
where IsInverseMeasure='No' and Percentage > 0.00 and IsComplexCareMeasures='Yes'
union
Select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
case when MeasureID like '%-%' then left(MeasureID,charindex('-',MeasureID)-1) else MeasureID end as MeasureID,Denominator,Numerator,Percentage
from ##DashboardData2 ad
where IsInverseMeasure='Yes' and Denominator > 0 and Percentage <> 100 and IsComplexCareMeasures='Yes'
) a
group by PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace]
order by PracticeId,[Location Id]


If ( object_id( 'TempDB.dbo.#AllTypeOfMeasureCounts', 'U' ) is not null )
		Drop Table #AllTypeOfMeasureCounts

select distinct dd.PracticeId,dd.PracticeName,dd.[Location Name],dd.[Location Id],dd.EMR,dd.[CAM/CAE],dd.Status,dd.[Practice Status],dd.[MIPS Components],dd.[Pace],dd.[GPRO/Individual],dd.[DRCF],
 --isnull([Non-zero performance on # of Other Measures],0)[Non-zero performance on # of Other Measures],
 --case 
 --when  isnull([Non-zero performance on # of OutCome measures],0)>2 or  isnull([Non-zero performance on # of Complex Care Measures],0)>2
 --then isnull([Non-zero performance on # of Other Measures],0)+(isnull([Non-zero performance on # of OutCome measures],0)-2)+(isnull([Non-zero performance on # of Complex Care Measures],0)-2)
 --else isnull([Non-zero performance on # of Other Measures],0)
 --end as [Non-zero performance on # of Other Measures],
  case 
 when  isnull([Non-zero performance on # of OutCome measures],0)>2 then isnull([Non-zero performance on # of Other Measures],0)+(isnull([Non-zero performance on # of OutCome measures],0)-2)
 when  isnull([Non-zero performance on # of Complex Care Measures],0)>2 then isnull([Non-zero performance on # of Other Measures],0)+(isnull([Non-zero performance on # of Complex Care Measures],0)-2)
 else isnull([Non-zero performance on # of Other Measures],0)
 end as [Non-zero performance on # of Other Measures],
 isnull([Non-zero performance on # of OutCome measures],0)[Non-zero performance on # of OutCome Measures],
 isnull([Non-zero performance on # of Complex Care Measures],0)[Non-zero performance on # of Complex Care Measures]
 into #AllTypeOfMeasureCounts
from ##DashboardData2 dd
left join #AllMeasureCount am on am.PracticeId=dd.PracticeId and am.[Location Id]=dd.[Location Id]
left join #ComplexCareMeasureCounts hm on hm.PracticeId=dd.PracticeId and hm.[Location Id]=dd.[Location Id]
left join #OutComeMeasuresCounts om on om.PracticeId=dd.PracticeId and om.[Location Id]=dd.[Location Id]

--select * from #AllTypeOfMeasureCounts where isnull([Non-zero performance on # of OutCome measures],0)>2 or  isnull([Non-zero performance on # of Complex Care Measures],0)>2

If ( object_id( 'TempDB.dbo.#ABFM_MIPS_WithComments', 'U' ) is not null )
		Drop Table #ABFM_MIPS_WithComments

select * 
into #ABFM_MIPS_WithComments
from
(
select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
[Non-zero performance on # of Other Measures],[Non-zero performance on # of OutCome Measures],[Non-zero performance on # of Complex Care Measures],
case when [Non-zero performance on # of Other Measures]<5 then 'Less than 5 Remaining Measures' else null end as Comment
from #AllTypeOfMeasureCounts
union
select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
[Non-zero performance on # of Other Measures],[Non-zero performance on # of OutCome Measures],[Non-zero performance on # of Complex Care Measures],
case when [Non-zero performance on # of OutCome Measures]<2 then 'Less than 2 OutCome Measures' else null end as Comment
from #AllTypeOfMeasureCounts
union
select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
[Non-zero performance on # of Other Measures],[Non-zero performance on # of OutCome Measures],[Non-zero performance on # of Complex Care Measures],
case when [Non-zero performance on # of Complex Care Measures]<2 then 'Less than 2 Complex Care Measures' else null end as Comment
from #AllTypeOfMeasureCounts
)a 
order by [Location Id]

If ( object_id( 'TempDB.dbo.#ABFM_MIPS_Final', 'U' ) is not null )
		Drop Table #ABFM_MIPS_Final

select distinct PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
[Non-zero performance on # of Other Measures],[Non-zero performance on # of OutCome Measures],[Non-zero performance on # of Complex Care Measures],
Comment=STUFF ( ( SELECT '/'+InrTab.Comment
						FROM #ABFM_MIPS_WithComments InrTab
						WHERE InrTab.PracticeId = OutTab.PracticeId and InrTab.[Location Id] = OutTab.[Location Id]
						ORDER BY InrTab.Comment desc
						FOR XML PATH(''),TYPE 
					   ).value('.','VARCHAR(MAX)') 
					  , 1,1,SPACE(0))
into #ABFM_MIPS_Final				  
FROM #ABFM_MIPS_WithComments OutTab					  
GROUP BY PracticeId,PracticeName,[Location Name],[Location Id],EMR,[CAM/CAE],Status,[Practice Status],[MIPS Components],[Pace],
[Non-zero performance on # of Other Measures],[Non-zero performance on # of OutCome Measures],[Non-zero performance on # of Complex Care Measures]


--if(OBJECT_ID('ABFM_TMPTables.dbo.SubmissionStatusMIPS_CPCPlus') is not null)
--drop table ABFM_TMPTables.dbo.SubmissionStatusMIPS_CPCPlus

truncate table CPCPlusLocationWiseReport

insert into CPCPlusLocationWiseReport
select distinct s.PracticeId,s.PracticeName,s.[Location Name],s.[Location Id],isnull(s.EMR,'')EMR,isnull(s.[CAM/CAE],'')[CAM/CAE],isnull(s.Status,'')[RT Status],isnull(StatusName,'')FREDStatusName,isnull(SubStatusName,'')FREDSubStatusName,isnull(Owner,'')FREDOwner,s.[MIPS Components],s.[Pace],
[Non-zero performance on # of Other Measures][Non-zero performance on # of Other Measures(CPC Plus)],[Non-zero performance on # of OutCome Measures][Non-zero performance on # of OutCome Measures(CPC Plus)],[Non-zero performance on # of Complex Care Measures][Non-zero performance on # of Complex Care Measures(CPC Plus)],
isnull(Comment,'Ready for CPC Plus Submission')  as [Performance on at least 5 Remaining measures and at least 2 measures being OutCome and Complex Care],isnull([Registered Before Deadline],'')[Registered Before Deadline(Yes/No)] 
--into CPCPlusLocationWiseReport
from #ABFM_MIPS_Final s
inner join ##DashboardData2 dd on dd.Practiceid=s.Practiceid and dd.[Location Id]=s.[Location Id]
left join ETLTempTables_ABFM.dbo.PractcesRegistrationDetails p on p.Practiceuid=dd.Practiceuid
order by s.PracticeId,[Location Id]

select * from CPCPlusLocationWiseReport order by PracticeId,[Location Id]

--select r.*, isnull([Non-zero performance on # of Other Measures(CPC Plus)],0)[Non-zero performance on # of Other Measures(CPC Plus)],
--isnull([Non-zero performance on # of OutCome Measures(CPC Plus)],0)[Non-zero performance on # of OutCome Measures(CPC Plus)],
--isnull([Non-zero performance on # of Complex Care Measures(CPC Plus)],0)[Non-zero performance on # of Complex Care Measures(CPC Plus)],
--isnull([Performance on at least 5 Remaining measures and at least 2 measures being OutCome and Complex Care],'Less than 5 Remaining Measures/Less than 2 OutCome Measures/Less than 2 Complex Care Measures')[Performance on at least 5 Remaining measures and at least 2 measures being OutCome and Complex Care]
--from FIGMDHQIManagementABFM.dbo.ProviderLevelMIPSPerformance r
--left join ABFM_TMPTables.dbo.SubmissionStatusMIPS_CPCPlus c on c.PracticeId=r.PracticeId and c.[Location Id]=r.[Location Id]

--select * from FIGMDHQIManagementABFM.dbo.ProviderLevelMIPSPerformance
--select * from [10.20.201.105].ABFM_TMPTables.dbo.MIPSDashboardRawData2
/*
If ( object_id( 'TempDB.dbo.#ProviderLevelMIPS', 'U' ) is not null )
		Drop Table #ProviderLevelMIPS


select distinct 'ABFM' Registry,s.*
,case when p1.Inactive=0 then 'Active' else 'Inactive' end as [Practice is Active/Inactive]
--into #ProviderLevelMIPS
from #SubmissionStatusMIPS s
inner join ##DashboardData2 dd on dd.Practiceid=s.Practiceid and dd.[Location Id]=s.[Location Id]
inner join practice p1 on p1.Practiceuid=dd.Practiceuid


If ( object_id( '#ProviderLevelMIPSPerformance', 'U' ) is not null )
		Drop Table #ProviderLevelMIPSPerformance

select * into #ProviderLevelMIPSPerformance
from #ProviderLevelMIPS


If ( object_id( '#ProviderCounts', 'U' ) is not null )
		Drop Table #ProviderCounts

select Registry,[PracticeID],[Registered Before Deadline(Yes/No)],COUNT(distinct [Location Id]) [TotalProvider#],
count(distinct 
case 
when  [Performance on 6 measures with at least 1 measure being outcome/high-priority]='Ready for Submission' 
and [Registered Before Deadline(Yes/No)]='Yes'
then [Location Id] end)[MIPSReadyProvider#(Yes)],
count(distinct 
case 
when [Performance on 6 measures with at least 1 measure being outcome/high-priority] in('Less than 6 measures','No Data for any OutCome AND High Priority measure','Less than 6 measures/No Data for any OutCome AND High Priority measure')  
and [Registered Before Deadline(Yes/No)]='Yes'
then [Location Id] end)[MIPSNotReadyProvider#(Yes)],
count(distinct 
case 
when  [Performance on 6 measures with at least 1 measure being outcome/high-priority]='Ready for Submission' 
and ([Registered Before Deadline(Yes/No)] in('No','Date Not Matched') or [Registered Before Deadline(Yes/No)]='')
then [Location Id] end)[MIPSReadyProvider#(No)],
count(distinct 
case 
when [Performance on 6 measures with at least 1 measure being outcome/high-priority] in('Less than 6 measures','No Data for any OutCome AND High Priority measure','Less than 6 measures/No Data for any OutCome AND High Priority measure')  
and ([Registered Before Deadline(Yes/No)] in('No','Date Not Matched') or [Registered Before Deadline(Yes/No)]='')
then [Location Id] end)[MIPSNotReadyProvider#(No)]
into #ProviderCounts
from #ProviderLevelMIPSPerformance
group by Registry,[PracticeID],[Registered Before Deadline(Yes/No)]



If ( object_id( '#PracticeLevelPQRSStatus', 'U' ) is not null )
		Drop Table #PracticeLevelPQRSStatus

select *,
case 
when [Registered Before Deadline(Yes/No)]='Yes' and (([TotalProvider#]=[MIPSReadyProvider#(Yes)]) and [MIPSNotReadyProvider#(Yes)]=0) and [TotalProvider#]<> 0 then 'Clear(Yes)'
when [Registered Before Deadline(Yes/No)]='Yes' and (([TotalProvider#]<>[MIPSReadyProvider#(Yes)]) and [MIPSNotReadyProvider#(Yes)]>0) and [TotalProvider#]<> 0 then 'Not Clear(Yes)'
when ([Registered Before Deadline(Yes/No)] in('No','Date Not Matched') or [Registered Before Deadline(Yes/No)]='') and (([TotalProvider#]=[MIPSReadyProvider#(No)]) and [MIPSNotReadyProvider#(No)]=0) and [TotalProvider#]<> 0 then 'Clear(No)' 
when ([Registered Before Deadline(Yes/No)] in('No','Date Not Matched') or [Registered Before Deadline(Yes/No)]='') and (([TotalProvider#]<>[MIPSReadyProvider#(No)]) and [MIPSNotReadyProvider#(No)]>0) and [TotalProvider#]<> 0 then 'Not Clear(No)'
end [PracticeLevelMIPSStatus]
into #PracticeLevelPQRSStatus
from #ProviderCounts
order by [Registered Before Deadline(Yes/No)]


If ( object_id( 'ETLTempTables_ABFM.dbo.PracticeSummary', 'U' ) is not null )
		Drop Table ETLTempTables_ABFM.dbo.PracticeSummary

select Registry,[Clear(Yes)][Clear Practice#(Yes)],[Not Clear(Yes)][Not Clear Practice#(Yes)],[Clear(No)][Clear Practice#(No)],[Not Clear(No)][Not Clear Practice#(No)]
into ETLTempTables_ABFM.dbo.PracticeSummary
from
(
select Registry,PracticeId,[PracticeLevelMIPSStatus]
from #PracticeLevelPQRSStatus
) a
pivot
(
count(PracticeId) for [PracticeLevelMIPSStatus] in([Clear(Yes)],[Not Clear(Yes)],[Clear(No)],[Not Clear(No)])
) pvt


If ( object_id( '#ProviderSummary', 'U' ) is not null )
		Drop Table #ProviderSummary

select Registry,sum([MIPSReadyProvider#(Yes)])[Ready for Submission Provider#(Yes)],sum([MIPSNotReadyProvider#(Yes)])[Not Ready for Submission Provider#(Yes)]
,sum([MIPSReadyProvider#(No)])[Ready for Submission Provider#(No)],sum([MIPSNotReadyProvider#(No)])[Not Ready for Submission Provider#(No)]
into #ProviderSummary
from #ProviderCounts 
group by Registry

If ( object_id( '#FinalSummary', 'U' ) is not null )
		Drop Table #FinalSummary

select prs.Registry,[Ready for Submission Provider#(Yes)],[Not Ready for Submission Provider#(Yes)],[Clear Practice#(Yes)],[Not Clear Practice#(Yes)],
[Ready for Submission Provider#(No)],[Not Ready for Submission Provider#(No)],[Clear Practice#(No)],[Not Clear Practice#(No)]
into #FinalSummary
from #ProviderSummary prs
inner join ETLTempTables_ABFM.dbo.PracticeSummary ps on ps.Registry=prs.Registry

--truncate table iDevDB_ABFM.dbo.FinalSummary

--insert into iDevDB_ABFM.dbo.FinalSummary
--select * from #FinalSummary

--truncate table iDevDB_ABFM.dbo.ProviderLevelMIPSPerformance

--insert into iDevDB_ABFM.dbo.ProviderLevelMIPSPerformance
--select * from #ProviderLevelMIPSPerformance

--truncate table FIGMDHQIManagementABFM.dbo.FinalSummary

--insert into FIGMDHQIManagementABFM.dbo.FinalSummary
--select * from #FinalSummary

--truncate table FIGMDHQIManagementABFM.dbo.ProviderLevelMIPSPerformance

--insert into FIGMDHQIManagementABFM.dbo.ProviderLevelMIPSPerformance
--select * from #ProviderLevelMIPSPerformance

--Summary
 select * from #FinalSummary

--Provider Details
select * from #ProviderLevelMIPSPerformance pm order by PracticeId,[Location Id]

*/
END