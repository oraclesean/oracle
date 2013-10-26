/*  indexes.sql
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
     Report information on indexes for a given table.
     
     Oracle hasn't taken their own advice regarding the LONG datatype and
     is still using it in DBA_IND_EXPRESSIONS, else I would have wrapped the
     contents of function-based indexes into the column_name column with a
     decode. One day I'll address the technical debt and write up something
     to handle this. */

set lines 265
column column_name format a30
column segment_size format 999,999 heading SIZE
column tablespace_name format a25
column column_expression format a40 heading ''
column clustering_factor heading CLUSTERING
break on index_name on segment_size on uniqueness on index_type on visibility on tablespace_name on blevel on leaf_blocks on distinct_keys on num_rows on clustering_factor
  select c.index_name
,        s.bytes/1024/1024             as segment_size
,        i.uniqueness
,        i.index_type
,        i.visibility
,        i.tablespace_name
,        i.blevel
,        i.leaf_blocks
,        i.distinct_keys
,        i.num_rows
,        i.clustering_factor
,        c.column_name
,        e.column_expression
    from dba_ind_columns                c
,        dba_ind_expressions            e
,        dba_segments                   s
,        dba_indexes                    i
   where i.table_owner                  = upper('&OWNER')
     and i.table_name                   = upper('&TABLE')
     and i.owner                        = s.owner
     and i.index_name                   = s.segment_name
     and i.owner                        = c.index_owner
     and i.index_name                   = c.index_name
     and s.segment_type                 = 'INDEX'
     and c.index_owner                  = e.index_owner (+)
     and c.index_name                   = e.index_name (+)
     and c.column_position              = e.column_position (+)
order by i.index_name
,        c.column_position;
clear breaks
