/*
 Script: create_sqlpatch_hint.sql
 Available here: https://github.com/maiconcarneiro/blog-dibiei/blob/main/create_sqlpatch_hint.sql

 This script can create a SQL Patch for an SQL ID using the specified hint
 The code was adjusted and tested to work properly in versions 11.2 to 19c.
 The script will be search the SQL_TEXT for the SQL_ID in CursorCache, AWR and STS respectivelly.
 You can disable the AWR and or STS option chaning the vUseAWR and vUseSTS variables.

 Syntax:
  @create_sqlpatch_hint <SQL_ID>  'Hints here'

 Author: Maicon Carneiro  (dibiei.blog)
*/

SET VERIFY OFF
SET SERVEROUTPUT ON
SET FEEDBACK ON

DECLARE

  /****************** change these values ************************/

  vSQL_ID varchar2(32) := '&1';

  vHINT clob := q'[
     &2
   ]';

  /****************************************************************/


 ------------------------ env config --------------------------
  vUseAWR boolean := true; --Require Management Pack option
  vUseSTS boolean := true; --Enterprise Edition included
 --------------------------------------------------------------

  vPatchName varchar2(30) := 'SQLPatch_' || vSQL_ID; 
  vSQL_TEXT clob;
  vSQL_TEXT_legacy varchar2(4000);
  vHINT_Legacy VARCHAR2(500);
  vVersion varchar2(20);
  vSQL varchar2(4000);
  vCount number := 0;
  vPatchExists number := 0;
  vSource varchar2(20) := null;
BEGIN

-- try to get sql_text of the sql_id from CursorCache
select count(*) into vCount from gv$sql where sql_id = vSQL_ID and rownum=1;
if vCount > 0 then 
 SELECT sql_text INTO vSQL_TEXT  FROM gv$sql WHERE sql_id = vSQL_ID AND rownum=1;
 vSource := 'Cursor Cahce';
end if;

-- if no present in CursorCache, try to get sql_text of the sql_id from AWR
if vSource is null and vUseAWR = true then
 select count(*) into vCount from dba_hist_sqltext where sql_id = vSQL_ID and rownum=1;
 if vCount > 0 then 
  SELECT sql_text INTO vSQL_TEXT FROM dba_hist_sqltext WHERE sql_id = vSQL_ID AND rownum=1;
  vSource := 'AWR';
 end if;
end if;

-- if no present in CursorCache and AWR, try to get sql_text of the sql_id from SQL Tuning Set
if vSource is null and vUseSTS = true then
 select count(*) into vCount from dba_sqlset_statements where sql_id = vSQL_ID and rownum=1;
 if vCount > 0 then 
  SELECT sql_text INTO vSQL_TEXT FROM dba_sqlset_statements WHERE sql_id = vSQL_ID AND rownum=1;
  vSource := 'SQL Tuning Set';
 end if;
end if;

if vSource is null then
 dbms_output.put_line('SQL ID '|| vSQL_ID ||' not found in Cursor Cache or AWR');
 return;
end if;

 select count(*) into vPatchExists from dba_sql_patches where name = vPatchName;
 IF (vPatchExists > 0) THEN
  SYS.DBMS_SQLDIAG.drop_sql_patch(name => vPatchName);
 END IF;

-- get the oracle version
select version into vVersion from v$instance;
 
  if vVersion <= '12.1' then  
    -- for 11g and 12cR1
     vSQL_TEXT_legacy := substr(vSQL_TEXT, 1, 4000);
     vHINT_Legacy     := substr(vHINT, 1, 500);
     
     vSQL := '
          begin
            sys.dbms_sqldiag_internal.i_create_patch (
               sql_text  => :vSQL_TEXT_legacy, 
               hint_text => :vHINT_Legacy, 
               name      => :vPatchName
              );
           end;';
  
     EXECUTE IMMEDIATE vSQL USING IN vSQL_TEXT_legacy, vHINT_Legacy, vPatchName ;
     
  else
   -- for 12cR2 and later
    vSQL := '
        declare
          vResult varchar2(100);
        begin
         vResult := sys.dbms_sqldiag.create_sql_patch (
             sql_text  => :vSQL_TEXT, 
             hint_text => :vHINT, 
             name      => :vPatchName
             );
         end;
        ';
    
     EXECUTE IMMEDIATE vSQL USING IN vSQL_TEXT, vHINT, vPatchName ;
  end if;

 dbms_output.put_line('===============================================================');
 dbms_output.put_line('SQL Patch ' || vPatchName || ' created from ' || vSource);
 dbms_output.put_line('===============================================================');

END;
/
