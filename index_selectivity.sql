/*   index_selectivity.sql
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

     Report on the selectivity and size of indexes. */

  select i.owner
,        i.table_name
,        i.index_name
,        to_char((i.distinct_keys / i.num_rows) * 100, '999.99') selectivity
,        i.distinct_keys
,        i.num_rows
,        i.index_type
,        s.bytes / 1024 / 1024          MB
,        c.constraint_name
    from dba_indexes                    i
,        dba_segments                   s
,        dba_constraints                c
   where i.num_rows                     > 0
     and i.distinct_keys / i.num_rows   < 0.2
     and i.owner                   not in ('SYS','SYSTEM','SYSMAN')
     and i.owner                        = s.owner
     and i.index_name                   = s.segment_name
     and s.segment_type                 = 'INDEX'
     and i.owner                        = c.index_owner (+)
     and i.index_name                   = c.index_name (+)
order by i.distinct_keys                asc
,        s.bytes                        desc
,        i.distinct_keys / i.num_rows;
