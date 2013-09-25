/*  free.sql
    Copyright (C) 2001, 2013 Sean Scott oracle_sean@mac.com

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
*/

--Comprehensive tablespace free space report.
column ts_name      format a32                 heading "Tablespace Name"
column extensible   format 999,999,999,999,999 heading "Extensible|Bytes"
column extens_free  format 999,999,999,999,999 heading "Extensible|Free"
column pct_used_ext format 999.9               heading "Ext. %|Used"
column allocated    format 999,999,999,999,999 heading "Allocated|Bytes"
column alloc_free   format 999,999,999,999,999 heading "Allocated|Free"
column used         format 999,999,999,999,999 heading "Used|Bytes"
column pct_used     format 999.9               heading "%|Used"
column ne           format 999,999,999,999     heading "Extendable"
break on report
compute sum of extensible  on report
compute sum of allocated   on report
compute sum of used        on report
compute sum of alloc_free  on report
compute sum of extens_free on report

  select ts_name
,        extensible_bytes               extensible
,        allocated_bytes                allocated
,        alloc_free
,        allocated_bytes - alloc_free   used
,        100 * (allocated_bytes - alloc_free) / allocated_bytes pct_used
,        to_number(decode(allocated_bytes, extensible_bytes, NULL,
         extensible_bytes
      - (allocated_bytes - alloc_free))) ne
,        to_number(decode(allocated_bytes, extensible_bytes, NULL, 
         100 * (extensible_bytes - (extensible_bytes - (allocated_bytes - alloc_free)))
       / extensible_bytes))             pct_used_ext
    from (  
  select a.tablespace_name              ts_name
,        sum(decode(b.autoextensible, 'YES', b.maxbytes, b.bytes))
       / count(distinct a.file_id||'.'||a.block_id) extensible_bytes
,        sum(b.bytes)/count(distinct a.file_id||'.'||a.block_id)  allocated_bytes
,        sum(a.bytes)/count(distinct b.file_id) alloc_free
    from sys.dba_free_space             a
,        sys.dba_data_files             b
   where a.tablespace_name              = b.tablespace_name (+)
group by a.tablespace_name
,        b.tablespace_name)
order by 6 desc;

column ts_name clear
column extensible clear
column extens_free clear
column pct_used_ext clear
column allocated clear
column alloc_free clear
column used clear
column pct_used clear
column ne clear
