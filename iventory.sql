select DatabaseName=sd.name, recovery_model_desc as recovery, sd.state_desc,sd.is_read_only,sd.user_access_desc
 ,upper(left(mf.physical_Name,1)) Drive,sd.compatibility_level
 ,[FILESIZE_GB] = CONVERT(DECIMAL(10,2),(CONVERT(DECIMAL(10,2),mf.SIZE/128.0))/1024.0)
 ,[FILE_Name] = mf.name  ,[File_Location] = mf.physical_Name ,[FIle_ID]= mf.file_id,[Type] = mf.type_desc
FROM sys.master_files mf inner join sys.databases sd  ON mf.database_id=sd.database_id
order by 1


--select * from sys.databases where state_desc='offline'