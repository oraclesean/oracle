/*   index_shrinks.sql
     Copyright (C) 2013 Sean Scott

     This program is free software; you can redistribute it and/or modify
     it under the terms of the GNU General Public License as published by
     the Free Software Foundation; either version 2 of the License, or
     (at your option) any later version.

     This program is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
     GNU General Public License for more details.

     You should have received a copy of the GNU General Public License along
     with this program; if not, write to the Free Software Foundation, Inc.,
     51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

     Build out alter index shrink space statements for a particular tablespace. */

column table_owner format a12
column table_name format a30
column index_name format a30
column table_size_mb format 999,999.90
column index_size_mb format 999,999.90
  select 'alter index ' || table_owner || '.' || index_name || ' shrink space COMPACT;;' || chr(10) ||
         'alter index ' || table_owner || '.' || index_name || ' shrink space;' || chr(10) ||
         '-- extents = ' || extents || ' size = ' || index_size_mb || chr(10) ||
         'select extents, bytes / 1024 / 1024 from dba_segments where owner = ''' || table_owner || ''' and segment_name = ''' || index_name || ''';'
    from (
  select t.owner              as table_owner
,        t.segment_name       as table_name
,        sum(t.bytes) / 1024 / 1024 as table_size_mb
,        i.segment_name       as index_name
,        sum(i.bytes) / 1024 / 1024 as index_size_mb
,        i.extents
    from dba_segments         t
,        dba_segments         i
,        dba_indexes          x
   where t.owner              = x.table_owner
     and t.segment_name       = x.table_name
     and i.owner              = x.owner
     and i.segment_name       = x.index_name
     and t.tablespace_name    = '&TABLESPACE_NAME'
group by t.owner
,        t.segment_name
,        i.segment_name
,        i.extents
  having sum(t.bytes)         < sum(i.bytes)
order by 5 asc);
