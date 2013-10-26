/*   fix_index_naming.sql
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

     A set of scripts for identifying indexes and constraints that don't meet
     the naming convention of TABLENAME_P. */

--PK indexes that don't prefix with the table name:
  select 'alter index ' || owner || '.' || index_name || ' rename to ' || table_name || '_P;'
    from dba_indexes
   where index_name              not like table_name || '%'
     and (index_name                 like '%P' 
      or  index_name                 like '%PK')
     and owner                          = '&OWNER'
     and uniqueness                     = 'UNIQUE'
     and index_type                    != 'LOB'
order by owner
,        table_name;

--Non-PK indexes that don't prefix with the table name:
  select 'alter index ' || owner || '.' || index_name || ' rename to ' || table_name || '_' || substr(uniqueness, 1, 1) || '0; --' || index_type
    from dba_indexes
   where index_name              not like table_name || '%'
     and index_name              not like '%P'
     and index_name              not like '%PK'
     and owner                          = '&OWNER'
     and index_type                    != 'LOB'
order by owner, table_name;


--Primary Key constraints that don't have the same name as their index:
  select 'alter table ' || owner || '.' || table_name || ' rename constraint ' || constraint_name || ' to ' || index_name || ';'
    from dba_constraints
   where constraint_type                = 'P'
     and owner                          = '&OWNER'
     and constraint_name               != index_name;

--Primary Keys constraint name that don't match their index name and that don't match the table_name:
  select 'alter table ' || owner || '.' || table_name || ' rename constraint ' || constraint_name || ' to ' || index_name || ';'
    from dba_constraints
   where constraint_type                = 'P'
     and owner                          = '&OWNER'
     and constraint_name               != index_name
     and constraint_name         not like table_name || '%';

--Indexes on primary keys that don't match their constraint name and don't match the table name:
  select 'alter index ' || owner || '.' || index_name || ' rename to ' || constraint_name || ';'
    from dba_constraints
   where constraint_type                = 'P'
     and owner                          = '&OWNER'
     and constraint_name               != index_name;
