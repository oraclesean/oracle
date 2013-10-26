/*   index_drops.sql
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

/* Indexes that don't have statistics */
  select index_name
    from dba_indexes
   where index_name                not in (
  select index_name
    from v$segment_statistics);

/* Indexes that are candidates for being dropped (not part of a constraint, not in
   an execution plan). */
  select owner
,        index_name
    from dba_indexes
   where (owner, index_name)       not in (
  select owner, object_name
    from dba_hist_sql_plan
   where object_type                    = 'INDEX') --Exclude indexes that have been used in an execution plan.
     and (owner, index_name)       not in (
  select owner, index_name
    from dba_constraints
   where constraint_type               in ('P','R')) --Exclude indexes that are part of a referential integrity constraint.
order by 1;

column cardinality format 999,999,999.90
column sample_pct  format 999,999,999.90

/* Indexes that may be empty/droppable because they have 0 distinct keys, 0 rows,
   and aren't part of a PK/FK constraint. */
  select owner
,        index_name
,        uniqueness
,        index_type
,        num_rows
,        decode(distinct_keys, NULL, 0, 0, 0, distinct_keys/num_rows) as cardinality
,        status
,        last_analyzed
    from dba_indexes
   where distinct_keys                  = 0
     and num_rows                       = 0
     and (owner, index_name)       not in (
  select owner, index_name
    from dba_constraints
   where constraint_type               in ('P','R'));

/* Small indexes that may be droppable because they're small and not used in a
   FK/PK constraint. Sometimes, a FTS may be as good or better than doing an index
   lookup against a tiny index/table. */
  select owner
,        index_name
,        pct_free
,        logging
,        index_type
,        distinct_keys
,        num_rows
,        decode(distinct_keys, NULL, 0, 0, 0, distinct_keys/num_rows) as cardinality
,        status
,        last_analyzed
,        decode(distinct_keys, NULL, 0, 0, 0, distinct_keys/sample_size) * 100 as sample_pct
    from dba_indexes
   where (distinct_keys                 < 20
      or  num_rows                      < 20)
     and distinct_keys                 != 0
     and num_rows                      != 0
     and (owner, index_name)       not in (
  select owner, index_name
    from dba_constraints
   where constraint_type               in ('P','R'))
order by 8 desc, 1, 2;

  select owner
,        index_name
,        pct_free
,        logging
,        index_type
,        distinct_keys
,        num_rows
,        decode(distinct_keys, NULL, 0, 0, 0, distinct_keys/num_rows) as cardinality
,        status
,        last_analyzed
,        decode(distinct_keys, NULL, 0, 0, 0, distinct_keys/sample_size) * 100 as sample_pct
    from dba_indexes
   where uniqueness                    != 'UNIQUE'
     and distinct_keys                 != 0
     and num_rows                      != 0
order by 8 desc, 1, 2;

/* Identify potentially redundant indexes based on predicates */
column column_name_list format a50
column column_name_list_dup format a50

  select /*+ rule */ 
         a.table_owner
,        a.table_name
,        a.index_owner
,        a.index_name
,        column_name_list
,        column_name_list_dup
,        dup duplicate_indexes
,        i.uniqueness
,        i.partitioned
,        i.leaf_blocks
,        i.distinct_keys
,        i.num_rows
,        i.clustering_factor 
    from ( 
  select table_owner
,        table_name
,        index_owner
,        index_name
,        column_name_list_dup
,        dup
,        max(dup) OVER (partition by table_owner, table_name, index_name) dup_mx 
    from ( 
  select table_owner
,        table_name
,        index_owner
,        index_name
,        substr(SYS_CONNECT_BY_PATH(column_name, ','), 2) column_name_list_dup
,        dup 
    from ( 
  select index_owner
,        index_name
,        table_owner
,        table_name
,        column_name
,        count(1) OVER (partition by index_owner, index_name) cnt
,        ROW_NUMBER () OVER (partition by index_owner, index_name order by column_position) as seq
,        count(1) OVER (partition by table_owner, table_name, column_name, column_position) as dup 
    from dba_ind_columns 
   where index_owner                   in ('&OWNER'))
   where dup                           != 1 
   start with seq                       = 1 
 connect by prior seq + 1               = seq 
     and prior index_owner              = index_owner 
     and prior index_name               = index_name)) a
,        ( 
  select table_owner
,        table_name
,        index_owner
,        index_name
,        substr(SYS_CONNECT_BY_PATH(column_name, ','), 2) column_name_list
    from ( 
  select index_owner
,        index_name
,        table_owner
,        table_name
,        column_name
,        count(1) OVER (partition by index_owner, index_name) cnt
,        ROW_NUMBER () OVER (partition by index_owner, index_name order by column_position) as seq
    from dba_ind_columns 
   where index_owner                   in ('&OWNER')) 
   where seq                            = cnt 
   start with seq                       = 1 
 connect by prior seq + 1               = seq 
     and prior index_owner              = index_owner 
     and prior index_name               = index_name) b
,        dba_indexes                    i 
   where a.dup                          = a.dup_mx 
     and a.index_owner                  = b.index_owner 
     and a.index_name                   = b.index_name 
     and a.index_owner                  = i.owner 
     and a.index_name                   = i.index_name 
order by a.table_owner
,        a.table_name
,        column_name_list_dup;
