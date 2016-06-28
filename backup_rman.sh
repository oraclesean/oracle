#!/bin/sh

#    backup_rman.sh
#    Copyright (C) 2004, 2013, 2016 Sean Scott

#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License along
#    with this program; if not, write to the Free Software Foundation, Inc.,
#    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# This is a highly adaptable RMAN backup script for Oracle 10g/11g databases.
# It facilitates a variety of backup options and was designed to be a single
# source for performing a variety of cron-based Oracle database backups.
#
# FEATURES
# Disk or tape backup destinations
# Full, incremental (differential/cumulative), copy, archive log, spfile backup options
# Multiple channels; channel size limits; channel options
# Control deletion of archive logs by backup count and age in hours
# Compression, encryption, optimization, parallelization, validation options
# Failure and success notification options
# Pre- and post- backup SQL execution options
# Preview (no backup) option
# Directory cleanup options
# Builds a recovery script with each backup
# Extensive before/after diagnostic logging of the Oracle environment including:
#   filesystem, memory, semaphores, processes

# Requires $HOME/dbbatch.sh, $DBA/functions.sh

#     Execute batch profile (since crontab's default is to not run .profile)
. /mnt/dbscripts/dbbatch.sh
. $DBA/functions.sh

# See if nawk should be used instead of awk
(nawk '{ print ; exit }' /etc/passwd) > /dev/null 2>&1
if [ ${?} -eq 0 ]
  then cmd=nawk
  else cmd=awk
fi

#****************************************************************
# Functions
#****************************************************************
error()
{
  echo "$@" 1>&2
  if [ -n "$email_failure" ]
    then
        if [ -n "$logmail" ]
          then mailto $email_failure $logmail "BACKUP FAILURE while $phase of $sid database on $machine" FILE
          else mailto $email_failure "$1" "BACKUP FAILURE while $phase of $sid database on $machine"
        fi
  fi
  exit 1
}

usage()
{
  version
  echo "usage: $PROGRAM -d oracle_sid -b backuptype [-l directory | -T SBT_channel] "
  echo "                [-acefFhHprRsStvx] --catalog --compress --deletearchive --encrypt "
  echo "                [-i level {--id}] --maxopenfiles files --maxsetsize kbytes "
  echo "                --nocrosscheck --nodeleteexpired --nodeleteobsolete --preview "
  echo "                --skipreadonly --spfile --validate "
  echo " "
  echo "Arguments:"
  echo "   -d oracle_sid        SID of the database to back up "
  echo "   -b                   type of backup (full, incremental, copy, archivelog, spfile) "
  echo "   -l directory         local directory to store the files "
  echo "   -T SBT_channel       SBT channel to allocate for tape backups (default is disk backup) "
  echo " "
  echo "Optional arguments: "
  echo "   -a channels          channels to allocate for backup operations (default 1) "
  echo "   -B backup_count      minimum count of backups to device of archive logs before deletion "
  echo "   -c kbytes            channel size limit, in kbytes (default 2GB) "
  echo "   -C hours             minimum age of archive logs (in hours) before deletion "
  echo "   --catalog string     catalog database connection string or path to file with connection information "
  echo "   --compress           compression backup "
  echo "   --deletearchive      delete archivelog input (overrides settings of log backup count and age) "
  echo "   -e email             comma delimited list of emails to be used for failure notification "
  echo "   --encrypt            encrypt backup "
  echo "   -f                   files per backup set, database backups (default 5) "
  echo "   -F                   files per backup set, archive log backups (default 50) "
  echo "   -h                   display this message "
  echo "   -H ORACLE_HOME       define an ORACLE_HOME directory "
  echo "   -i level             level for incremental backup, 0-4 (default 0) "
  echo "   --ic                 perform a cumulative incremental backup "
  echo "   --maxopenfiles       maximum number of open files (default 1) "
  echo "   --maxsetsize kbytes  maximum backup set size, in kbytes (default 2GB) "
  echo "   --nocrosscheck       do not crosscheck backups "
  echo "   --nodeleteexpired    do not delete expired backups "
  echo "   --nodeleteobsolete   do not delete obsolete backups "
  echo "   -p prefix            backup files base name (default SID_backup) "
  echo "   -P PARMS             parms option for channel allocation "
  echo "   --pre SQL            sql commands to be run before backup starts "
  echo "   --post SQL           sql commands to be run after backup completes "
  echo "   --preview            preview the backup; generate files, but don't execute them "
  echo "   -r redundancy        level of backup redundancy (default 1) "
  echo "   -R retention         minimum days of backup retention (default 14) "
  echo "   --resync             resync catalog "
  echo "   -s suffix            backup files extension (default bak) "
  echo "   -S email             comma delimited list of emails to be used for success notification "
  echo "   --skipreadonly       skip read-only tablespaces "
  echo "   --spfile             backup the spfile "
  echo "   --summary            log summary information only "
  echo "   -t tag               backup set tag "
  echo "   --trace              backup control file to trace file "
  echo "   -v                   display version information "
  echo "   --validate           validate backup when complete "
  echo "   -x days              cleanup logs and scripts more than days old "
  echo " "
}

usage_and_exit()
{
  usage
  exit $1
}

version()
{
  echo " "
  echo "$PROGRAM version $VERSION"
  echo " "
}

do_dbenv()
{
  # Get environment settings from the database. This is much easier than trying to figure
  # out the current version, discover the trace location (ORACLE_BASE/admin/SID/bdump vs
  # ADR_HOME or a non-standard location). We want the node in the event that we're backing
  # up spfiles from more than one node of a RAC instance, so that they can be destinguished
  # and don't overwrite each other.

  dbenv=$(mktemp)
  if [ $? -ne 0 ]
    then error "Could not create the Oracle environment file"
  fi

  $ORACLE_HOME/bin/sqlplus -s "/ as sysdba" <<EOF > $dbenv
  set heading off
  set feedback off
  select '#!/bin/sh' from dual;
  select 'export tracedir=' || value from v\$parameter where name = 'background_dump_dest';
  select 'export dbuname=' || value from v\$parameter where name = 'db_unique_name';
  select 'export node=' || value from v\$parameter where name = 'instance_number';
  select 'export nls=' || a.value || '_' || b.value || '.' || c.value
    from v\$nls_parameters a, v\$nls_parameters b, v\$nls_parameters c
   where a.parameter = 'NLS_LANGUAGE' and b.parameter = 'NLS_TERRITORY' and c.parameter = 'NLS_CHARACTERSET';
  exit
EOF
  source $dbenv
  rm $dbenv
}

do_logdelete()
{
  if [ "$backdir" ]
    # We're backing up to disk...
    then logdest="disk"
    else logdest="SBT_TAPE"
  fi

  # Determine if there's a retention count of log backups requested
  if [ "$logbackupcount" ]
    then logdeletecount=" backed up $logbackupcount times to $logdest"
  fi

  # Determine if there's a retention age of log backups requested
  if [ "$logbackuphours" ]
    then logdeletehours=" completed before 'sysdate - $logbackuphours / 24'"
  fi

  logdelete="delete force noprompt expired archivelog all $logdeletecount $logdeletehours;"
}

do_backup_script()
{
  # Write the backup and recovery scripts based on the user entries.
  echo "!#/bin/sh" | tee $restorescript
  echo "export ORACLE_BASE=$ORACLE_BASE" | tee -a $restorescript
  echo "export ORACLE_HOME=$ORACLE_HOME" | tee -a $restorescript
  echo "export ORACLE_SID=$sid" | tee -a $restorescript
  echo "export CLASSPATH=$CLASSPATH" | tee -a $restorescript
  echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH" | tee -a $restorescript
  echo "export ORAENV_ASK=NO" | tee -a $restorescript
  # The following addresses a bug where RMAN duplicate fails due to missing NLS_LANG
  echo "export NLS_LANG=$nls" | tee -a $restorescript
  echo "export PATH=$PATH" | tee -a $restorescript
  echo ". $ORACLE_HOME/bin/oraenv" | tee -a $restorescript
  echo "$ORACLE_HOME/bin/rman target / $catalog <<EOF" | tee -a $restorescript
  echo "show all;" | tee -a $rmanscript

  if [ "$backdir" ]
    # We're backing up to disk...
    then echo "configure controlfile autobackup format for device type disk to" | tee -a $rmanscript $restorescript
         echo "        '$backdir/$sid_%F.bct';" | tee -a $rmanscript $restorescript
         echo "configure snapshot controlfile name to '$backdir/snap_$sid.$suffix';" | tee -a $rmanscript $restorescript
         channeltype="type disk"
         channelformat="'$backdir/$basename_%d_%t_%U.$suffix'"
    # Else we're backing up to tape.
    else channeltype="type $sbtchannel"
  fi

  echo "configure controlfile autobackup on;" | tee -a $rmanscript

  # In the event both are defined, recovery window trumps redundancy;
  # if this isn't the desired behavior, switch these two checks.
  if [ "$redundancy" ]
    then echo "configure retention policy to redundancy $redundancy;" | tee -a $rmanscript
  fi

  if [ "$retention" ]
    then echo "configure retention policy to recovery window of $retention days;" | tee -a $rmanscript
  fi

  # For 11.2, add the ability to define the type of compression:
  if [ "$compress" ]
    then echo "configure device $channeltype backup type to compressed backupset;" | tee -a $rmanscript $restorescript
    else echo "configure device $channeltype backup type to backupset;" | tee -a $rmanscript $restorescript
  fi

  if [ "$parallel" -gt 1 ]
    then echo "configure device $channeltype parallelism $parallel;" | tee -a $rmanscript $restorescript
  fi

  # Always include some informative listings:
  echo "show all;" | tee -a $rmanscript
  echo "list incarnation;" | tee -a $rmanscript
  echo "report schema;" | tee -a $rmanscript

  if [ "$optimization" ]
    then echo "configure backup optimization on;" | tee -a $rmanscript
    else echo "configure backup optimization off;" | tee -a $rmanscript
  fi

  if [ "$encrypt" ]
    then echo "configure encryption for database on;" | tee -a $rmanscript
    else echo "configure encryption for database off;" | tee -a $rmanscript
  fi

  if [ "$resync" ]
    then echo "resync catalog;" | tee -a $rmanscript
  fi

  if [ "$crosscheck" ]
    then echo " " | tee -a $rmanscript
    if [ "$sbtchannel" ]
      then echo "allocate channel for maintenance type 'SBT_TAPE' $parms;" | tee -a $rmanscript
    fi
         echo "allocate channel for maintenance type disk;" | tee -a $rmanscript
         echo "crosscheck backup;" | tee -a $rmanscript
         echo "crosscheck archivelog all;" | tee -a $rmanscript
    if [ "$deleteobsolete" ]
      then echo "delete force noprompt obsolete;" | tee -a $rmanscript
    fi
    if [ "$deleteexpired" ]
      then echo "delete force noprompt expired backup;" | tee -a $rmanscript
           echo $logdelete | tee -a $rmanscript
    fi
    echo "release channel;" | tee -a $rmanscript
  fi

    if [ "$pre" ]
      then echo "sql '$pre';" | tee -a $rmanscript
    fi

  echo "release channel;" | tee -a $restorescript
  echo "run {" | tee -a $rmanscript $restorescript

  # Create $channels channels.
  channelno=0
  while (( $channelno < $channels ))
  do
    echo "allocate channel ch_$channelno $channeltype $parms format $channelformat;" | tee -a $rmanscript $restorescript
    echo "setlimit channel ch_$channelno kbytes $channelsize maxopenfiles $maxopenfiles;" | tee -a $rmanscript $restorescript
    let channelno++
  done

  if [ "$backuptype" == "full" ]
  then echo "backup full" | tee -a $rmanscript
       echo "tag = '$tag'" | tee -a $rmanscript
       echo "filesperset $filespersetdbf $skipreadonly" | tee -a $rmanscript
       echo "database include current controlfile;" | tee -a $rmanscript
       echo "sql 'alter system archive log current';" | tee -a $rmanscript
       echo "backup filesperset $filespersetarc" | tee -a $rmanscript
       echo "archivelog all $deletearchive;" | tee -a $rmanscript

       if [ "$deleteobsolete" ]
         then echo "delete force noprompt obsolete;" | tee -a $rmanscript
       fi
       if [ "$deleteexpired" ]
         then echo "delete force noprompt expired backup;" | tee -a $rmanscript
              echo $logdelete | tee -a $rmanscript
       fi

  elif [ "$backuptype" == "copy" ]
  then echo "recover copy of database with tag '$tag';" | tee -a $rmanscript
       echo "backup incremental level $level $inctype" | tee -a $rmanscript
       echo "tag = '$tagi" | tee -a $rmanscript
       echo "filesperset $filespersetdbf $skipreadonly" | tee -a $rmanscript
       echo "database include current controlfile;" | tee -a $rmanscript
       echo "sql 'alter system archive log current';" | tee -a $rmanscript
       echo "backup filesperset $filespersetarc" | tee -a $rmanscript
       echo "archivelog all $deletearchive;" | tee -a $rmanscript

       if [ "$deleteobsolete" ]
         then echo "delete force noprompt obsolete;" | tee -a $rmanscript
       fi
       if [ "$deleteexpired" ]
         then echo "delete force noprompt expired backup;" | tee -a $rmanscript
              echo $logdelete | tee -a $rmanscript
       fi

  elif [ "$backuptype" == "incremental" ]
  then echo "backup incremental level $level $inctype" | tee -a $rmanscript
       echo "tag = '$tag'" | tee -a $rmanscript
       echo "filesperset $filespersetdbf $skipreadonly" | tee -a $rmanscript
       echo "database include current controlfile;" | tee -a $rmanscript
       echo "sql 'alter system archive log current';" | tee -a $rmanscript
       echo "backup filesperset $filespersetarc" | tee -a $rmanscript
       echo "archivelog all $deletearchive;" | tee -a $rmanscript


       if [ "$deleteobsolete" ]
         then echo "delete force noprompt obsolete;" | tee -a $rmanscript
       fi
       if [ "$deleteexpired" ]
         then echo "delete force noprompt expired backup;" | tee -a $rmanscript
              echo $logdelete | tee -a $rmanscript
       fi

  elif [ "$backuptype" == "archivelog" ]
  then echo "sql 'alter system archive log current';" | tee -a $rmanscript
       echo "backup filesperset $filespersetarc" | tee -a $rmanscript
       echo "archivelog all $deletearchive;" | tee -a $rmanscript

       if [ "$deleteexpired" ]
         then echo $logdelete | tee -a $rmanscript
       fi

  # Allow a backup of just the spfile, useful for each node in a RAC cluster.
  elif [ "$backuptype" == "spfile" ]
  then echo "sql \"create pfile=''$backdir/$basename.node$node.spfile'' from spfile\";" | tee -a $rmanscript
  fi

  # Create a text controlfile backup. 
  if [ "$trace" ]
    then echo "sql \"alter database backup controlfile to trace as ''$backdir/$basename.trace.ctl''\";" | tee -a $rmanscript
  fi

  # If this is already an spfile backup, disregard the --spfile option.
  if [ "$spfile" ] && [ "&backuptype" != "spfile" ]
      then echo "sql \"create pfile=''$backdir/$basename.node$node.spfile'' from spfile\";" | tee -a $rmanscript
  fi

  echo "restore database;" | tee -a $restorescript
  echo "recover database;" | tee -a $restorescript

  # Release $channels channels.
  channelno=0
  while (( $channelno < $channels ))
  do
    echo "release channel ch_$channelno;" | tee -a $rmanscript $restorescript
    let channelno++
  done

  echo "}" | tee -a $rmanscript $restorescript

  if [ "$post" ]
    then echo "sql '$post';" | tee -a $rmanscript
  fi

  echo "EOF" | tee -a $restorescript

}

do_validation_script()
{
  echo "allocate channel for maintenance type disk;" | tee -a $validscript
  echo "list backup $summary;" | tee -a $validscript
  echo "report obsolete;" | tee -a $validscript
  if [ "$deleteobsolete" ]
    then echo "delete force noprompt obsolete;" | tee -a $validscript
  fi
  if [ "$deleteexpired" ]
    then echo "delete force noprompt expired backup;" | tee -a $validscript
         echo $logdelete | tee -a $validscript
  fi
  echo "release channel;" | tee -a $validscript
  echo "run {" | tee -a $validscript

  # Create $channels chennels.
  channelno=0
  while (( $channelno < $channels ))
  do
    echo "allocate channel ch_$channelno $channeltype $parms format $channelformat;" | tee -a $validscript
    echo "setlimit channel ch_$channelno kbytes $channelsize maxopenfiles $maxopenfiles;" | tee -a $validscript
    let channelno++
  done

  echo "restore database validate check logical;" | tee -a $validscript
  echo "restore database preview $summary;" | tee -a $validscript

  # Release $channels channels.
  channelno=0
  while (( $channelno < $channels ))
  do
    echo "release channel ch_$channelno;" | tee -a $validscript
    let channelno++
  done

  echo "}" | tee -a $validscript
}

do_backup()
{
  now=`date '+%m/%d/%y %H:%M:%S'`
  echo "Backup of database $mysid beginning at $now." | tee -a $logfile $logmail

  # Send output from RMAN to its own log that we can tee to the individual log files.
  logrman=$(mktemp)
  if [ $? -ne 0 ]
    then error "Could not create the RMAN log file"
  fi

  $ORACLE_HOME/bin/rman target / $catalog cmdfile $script log="$logrman"
  exit_status=$?
  now=`date '+%m/%d/%y %H:%M:%S'`
  cat $logrman | tee -a $logfile $logmail
  message="Backup of database $mysid complete at $now." | tee -a $logfile $logmail

  if [ $exit_status -ne 0 ]
  then error "Failure while $phase of $sid on $machine - see $backdir/$logfile for details"
  fi

  rm $logrman
}

do_log_cleanup()
{
  # Clean up all of the old files. Comment those that you want to keep or manage manually.
  # .log are the backup logs.
  # .rman are the generated RMAN backup scripts
  # .spfile are the SPFILE copies
  # .trace.ctl are the controlfile to trace files
  # .recovery.sh are the recovery scripts
  echo "Performing cleanup of supporting files older than $clean days."
  echo " "
  echo "The following files are being removed from the system:"
  find $backdir -type f -regex ".*\.\(log\|rman\|spfile\|recovery\.sh\|trace\.ctl\)" -mtime +14 -exec ls -l {} \; -delete | tee -a $logfile
  echo " "
}


# Set up the environment. Define any default values here.
PROGRAM=`basename $0`
VERSION=1.0
backdir=
backuptype=incremental
basename=
catalog=nocatalog
channels=1
channelsize=2097150
clean=
compress=0
crosscheck=1
deletearchive=
deleteexpired=1
deleteobsolete=1
email_failure=
email_success=
encrypt=
filespersetdbf=5
filespersetarc=50
inctype=
level=0
logbackupcount=
logbackuphours=
machine=`uname -n`
maxopenfiles=1
maxsetsize=2097150
optimization=0
parms=
parallel=0
prefix=
pre=
post=
preview=
redundancy=
resync=
retention=
sbtchannel=
sid=
skipreadonly=
spfile=
suffix=bak
summary=
tag=
trace=
tracedir=
validate=

# Call the functions:
. functions.sh

# Get command line arguments
while getoptex "a: b: B: c: C: catalog: compress; d: deletearchive; e: encrypt; f: F: h; i: ic; l: maxopenfiles: maxsetsize: nocrosscheck; nodeleteexpired; nodeleteobsolete; o; p: parallel; P: preview; r: R: resync; s: S: skipreadonly; spfile; summary; trace; t: T: v; validate; x: " "$@"
do
  case $OPTOPT in
    a                ) channels="$OPTARG"       ;;
    b                ) backuptype=`fixcase "$OPTARG"` ;;
    B                ) logbackupcount="$OPTARG" ;;
    c                ) channelsize="$OPTARG"    ;;
    C                ) logbackuphours="$OPTARG" ;;
    catalog          ) catalog="$OPTARG"        ;;
    compress         ) compress=1               ;;
    d                ) sid="$OPTARG"            ;;
    deletearchive    ) deletearchive="delete input" ;;
    e                ) email_failure="$OPTARG"  ;;
    encrypt          ) encrypt=1                ;;
    f                ) filespersetdbf="$OPTARG" ;;
    F                ) filespersetarc="$OPTARG" ;;
    H                ) ORACLE_HOME="$OPTARG"    ;;
    i                ) level="$OPTARG"          ;;
    ic               ) inctype="cumulative"     ;;
    l                ) backdir="$OPTARG"        ;;
    maxopenfiles     ) maxopenfiles="$OPTARG"   ;;
    maxsetsize       ) maxsetsize="$OPTARG"     ;;
    nocrosscheck     ) crosscheck=              ;;
    nodeleteexpired  ) deleteexpired=           ;;
    nodeleteobsolete ) deleteobsolete=          ;;
    o                ) optimization=1           ;;
    p                ) prefix="$OPTARG"         ;;
    P                ) parms="PARMS='$OPTARG'"  ;;
    parallel         ) parallel="$OPTARG"       ;;
    pre              ) pre="$OPTARG"            ;;
    post             ) post="$OPTARG"           ;;
    preview          ) preview=1                ;;
    r                ) redundancy="$OPTARG"     ;;
    R                ) retention="$OPTARG"      ;;
    resync           ) resync=1                 ;;
    s                ) suffix="$OPTARG"         ;;
    S                ) email_success="$OPTARG"  ;;
    skipreadonly     ) skipreadonly="skip readonly" ;;
    spfile           ) spfile=1                 ;;
    summary          ) summary="summary"        ;;
    t                ) tag="$OPTARG"            ;;
    T                ) sbtchannel="$OPTARG"     ;;
    trace            ) trace=1                  ;;
    validate         ) validate=1               ;;
    x                ) clean="$OPTARG"          ;;
    h                ) usage_and_exit 0         ;;
    '?'              ) usage_and_exit 0         ;;
    v                ) version                  ;;
  esac
done
shift $[OPTIND-1]

phase="validating command line arguments"
# Validate command line arguments.
# You have to have a local backup directory:
if [ ! "$backdir" ]
  then error "A local directory for backups and/or backup files must be supplied"
elif [ ! -d "$backdir" ]
  then error "The supplied local directory does not exist"
elif [ ! -w "$backdir" ]
  then error "The supplied local directory is not writable"
fi

is_num $channels
if [ $? == 1 ]
  then error "Channels to be allocated must be a numeric value"
fi

is_num $backupcount
if [ $? == 1 ]
  then error "Log backup count mut be a numeric value"
fi

is_num $backuphours
if [ $? == 1 ]
  then error "Log age (hours) mut be a numeric value"
fi

is_num $channelsize
if [ $? == 1 ]
  then error "Channel size must be a numeric value"
fi

is_num $filespersetdbf
if [ $? == 1 ]
  then error "Files per backup set must be a numeric value"
fi

is_num $filespersetarc
if [ $? == 1 ]
  then error "Files per archivelog backup set must be a numeric value"
fi

is_num $level
if [ "$level" -a $? == 1 ]
  then error "Incremental backup level must be a numeric value"
elif [ "$level" -lt 0 -o "$level" -gt 4 ]
  then error "Incremental backup level must be between 0 and 4"
fi

is_num $maxopenfiles
if [ $? == 1 ]
  then error "Max open files must be a numeric value";
fi

is_num $maxsetsize
if [ $? == 1 ]
  then error "Max set size must be a numeric value"
fi

is_num $parallel
if [ $? == 1 ]
  then error "Parallel backup degree must be a numeric value"
fi

is_num $redundancy
if [ $? == 1 ]
  then error "Backup redundancy level must be a numeric value"
fi

is_num $retention
if [ $? == 1 ]
  then error "Backup retention days must be a numeric value"
fi

# Set up the environment; warn if an invalid SID is supplied
if [ ! "$sid" ]
  then error "You must supply a SID to back up"
fi

valid_db $sid
if [ $? -ne 0 ]
  then error "The database $sid is invalid"
fi

is_num $clean
if [ $? == 1 ]
  then error "Log cleanup days must be a numeric value"
fi

ORAENV_ASK=NO;          export $ORAENV_ASK;
ORACLE_SID=$sid;        export $ORACLE_SID;
. $ORACLE_HOME/bin/oraenv

phase="obtaining database status"
db_status $sid
if [ $? -ne 0 ]
  then error "The database $sid is not open"
fi

phase="creating support files"
# Create the file extensions
now=`date '+%y-%m-%d_%H-%M-%S'`

# Add a random string to prevent the end of DST from creating duplicate files:
un=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)

if [ ! "$prefix" ]
  then prefix=$sid_backup
       basename=$PROGRAM.$sid.$now.$un
  else basename=$prefix.$sid.$now.$un
fi

if [ ! "$prefix" ]
  then prefix=$sid_backup
       basename=$PROGRAM.$sid.$now
  else basename=$prefix.$sid.$now
fi

# touch the log and script files:
logfile=$backdir/$basename.log
touch $logfile
if [ $? -ne 0 ]
  then error "Could not create the log file"
fi

logmail=$(mktemp)
if [ $? -ne 0 ]
  then error "Could not create the email log file"
fi

rmanscript=$backdir/$basename.rman
touch $rmanscript
if [ $? -ne 0 ]
  then error "Could not create the backup script file"
fi

restorescript=$backdir/$basename.recovery.sh
touch $restorescript
if [ $? -ne 0 ]
  then error "Could not create the restore script file"
fi

phase="setting RMAN backup type"
if [ ! "$backuptype" ]
  then error "A backup type (full, incremental, copy, archivelog or spfile) must be supplied"
elif [ "$backuptype" != "incremental" -a "$backuptype" != "full" -a "$backuptype" != "copy" -a "$backuptype" != "archivelog" -a "$backuptype" != "spfile" ]
  then error "The backup type must be one of full, incremental, copy, archivelog or spfile"
fi

if [ "$backuptype" != "incremental" -a "$id" ]
  then error "A differential backup type is only valid for incremental backups"
fi

phase="setting archivelog deletion policies"
do_logdelete

phase="setting database environment"
do_dbenv

phase="preparing for backup"
do_backup_script

phase="capturing pre-backup environment"
# Send full diagnostic information to the logfile, but not the email log.
echo " " | tee -a $logfile
if [ "$summary" != "summary" ]
  then echo "User processes in the $sid database before backup:" | tee -a $logfile
       ps $PS_OPTS | grep -v grep | grep oracle$sid | tee -a $logfile
       echo " " | tee -a $logfile
       echo "Database processes running in the $sid database before backup:" | tee -a $logfile
       ps $PS_OPTS | grep -v grep | grep ora_ | grep $sid | tee -a $logfile
       echo " " | tee -a $logfile
fi
echo "ipcs debug information before backup:" | tee -a $logfile
ipcs -ms | tee -a $logfile
echo "Free space information before backup:" | tee -a $logfile $logmail
df -k $backdir | tee -a $logfile $logmail
echo "Directory listing before backup:" | tee -a $logfile
if [ "$summary" != "summary" ]
  then ls -lt $backdir | tee -a $logfile
fi

# If this is not a preview (just write files but don't do a backup) then we run the backup.
if [ ! "$preview" ]
  then script=$rmanscript
       phase="performing backup"
       do_backup
  else echo "Running in preview mode." | tee -a $logfile $logmail
       phase="performing backup preview"
fi

if [ "$validate" ]
  then phase="performing validation"
       validscript=$backdir/$basename.validate.rman
       touch $validscript
       if [ $? -ne 0 ]
         then error "Could not create the validation script file"
       fi

       do_validation_script

       if [ ! "$preview" ]
         then script=$validscript
              phase="validating backup"
              do_backup
         else echo "Validation not performed - running in preview mode" | tee -a $logfile $logmail
       fi
fi

if [ ! "$preview" ]
  then echo " " | tee -a $logfile

       if [ "$clean" ]
         then phase="performing cleanup"
              do_log_cleanup
       fi

       phase="capturing post-backup environment"
       # Don't write "after backup" diagnostic information for previews.
       if [ "$summary" != "summary" ]
         then echo "User processes in the $sid database after backup:" | tee -a $logfile
              ps $PS_OPTS | grep -v grep | grep oracle$sid | tee -a $logfile
              echo " " | tee -a $logfile
              echo "Database processes running in the $sid database after backup:" | tee -a $logfile
              ps $PS_OPTS | grep -v grep | grep ora_ | grep $sid | tee -a $logfile
              echo " " | tee -a $logfile
       fi
       echo "ipcs debug information after backup:" | tee -a $logfile
       ipcs -ms | tee -a $logfile
       echo "Free space information after backup:" | tee -a $logfile
       df -k $backdir | tee -a $logfile $logmail
       if [ "$summary" != "summary" ]
         then echo "Directory listing after backup:" | tee -a $logfile
              ls -lt $backdir | tee -a $logfile
       fi
fi

# It worked! Send a congratulatory email as positive reinforcement of a job well done!
if [ "$email_success" ]
  then mailto $email_success $logmail "Backup successful for $sid database on $machine" FILE
fi

# Get rid of the email-only log file, we don't need to keep it.
rm $logmail

exit 0
