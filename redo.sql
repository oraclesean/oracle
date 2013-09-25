/*  redo.sql
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

--Report of online redo log file information
col group# format 999
col thread# format 999
col member format a70 wrap
col status format a10
col archived format a10
col fsize format 9999 heading "Size (MB)"
break on thread# skip 1 on group#

  select l.thread#
,        l.group#
,        f.member
,        l.archived
,        l.status
,        (bytes/1024/1024) fsize
    from v$log                          l
,        v$logfile                      f
   where f.group#                       = l.group#
order by 1, 2;

clear breaks
