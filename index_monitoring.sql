-- Index monitoring usage scripts

  select 'alter index '||owner||'.'||index_name||' monitoring usage;'
    from dba_indexes
   where owner                          = '&OWNER';

  select index_name
,        table_name
,        monitoring
,        used
,        start_monitoring
,        end_monitoring
    from v$object_usage;

  select p.object_name
,        p.operation
,        p.options
         count(*)
    from dba_hist_sql_plan              p
,        dba_hist_sqlstat               s
   where p.object_owner                != 'SYS'
     and p.operation                 like '%INDEX%'
     and p.sql_id                       = s.sql_id
group by p.object_name
,        p.operation
,        p.options
order by 1, 2, 3;

column mbytes format 999,999,999.990
  select io.name
,        t.name
,        decode(bitand(i.flags, 65536), 0, 'NO', 'YES')
,        decode(bitand(ou.flags, 1), 0, 'NO', 'YES')
,        ou.start_monitoring
--,        ou.end_monitoring 
,        sum(ds.bytes/1024/1024)       as mbytes
    from sys.obj$                       io
,        sys.obj$                       t
,        sys.ind$                       i
,        sys.object_usage               ou
,        dba_users                      du
,        dba_segments                   ds
   where io.owner#                      = du.user_id
     and du.username                    = '&OWNER'
     and du.username                    = ds.owner
     and io.name                        = ds.segment_name
     and i.obj#                         = ou.obj#
     and io.obj#                        = ou.obj#
     and t.obj#                         = i.bo#
group by io.name
,        t.name
,        decode(bitand(i.flags, 65536), 0, 'NO', 'YES')
,        decode(bitand(ou.flags, 1), 0, 'NO', 'YES')
,        ou.start_monitoring
order by 6 asc;
