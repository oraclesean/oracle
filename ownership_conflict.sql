/*   ownership_conflict.sql
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

     These scripts provide a variety of different methods for looking at indexes that
     are candidates to be dropped. */

column MB format 999,999,999.990
column objects format 999,999
break on owner skip 1 on tablespace_name on segment_type on report
compute sum of objects on owner on report
compute sum of MB on owner
compute sum of objects on report
compute sum of MB on report

/* Get the total space used and count of objects for all non-system owners. */
  select owner
,        tablespace_name
,        segment_type
,        count(segment_name)            objects
,        sum(bytes) / 1024 / 1024       MB
    from dba_segments
   where owner                     not in ('SYS', 'SYSTEM', 'SYSMAN', 'WMSYS', 'TSMSYS', 'OUTLN', 'DBSNMP')
group by owner
,        tablespace_name
,        segment_type
order by 1, 2, 3;

/* Find objects that aren't created under the correct owner/schema. */
break on owner on segment_type on tablespace_name on segment_name skip 1
  select s.owner
,        s.segment_name
,        s.segment_type
,        s.tablespace_name
,        decode(s.owner, r.owner, NULL, r.owner) r_owner
,        decode(s.owner, r.owner, NULL, r.tablespace_name) r_tbs
    from dba_segments                   s
,        dba_segments                   r
   where s.segment_name (+)             = r.segment_name
     and s.segment_name              like 'XX%'
     and (s.owner                not like 'XX%'
      or  s.tablespace_name      not like 'XX%')
order by 2, 3, 1, 5;

/* Indexes that aren't owned by the table owner. */
  select owner
,        index_name
,        table_owner
,        table_name
    from dba_indexes
   where owner                         != table_owner;
