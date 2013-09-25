#    dbbatch.sh
#    Copyright (C) 2004, 2013 Sean Scott oracle_sean@mac.com

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

# This is a set of parameters for setting up Oracle batch jobs.

CLIENT=client.com;                                                    export CLIENT
MACHINE=`uname -n`;                                                   export MACHINE
DEFAULT_MAIL=me@email.com;                                            export DEFAULT_MAIL
DBA_MAIL=me@email.com,oncallguy@company.com;                          export DBA_MAIL
APP_EMAIL=me@email.com;                                               export APP_EMAIL
ALL_MAIL=$DBA_MAIL","$APP_EMAIL                                       export ALL_MAIL
ORACLE_BASE=/oracle;                                                  export ORACLE_BASE
ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_1;                         export ORACLE_HOME
ADR_BASE=$ORACLE_BASE;                                                export ADR_BASE
NODE=mydb1;                                                           export NODE
EDITOR=vi;                                                            export EDITOR
ORACLE_TERM=vt100;                                                    export ORACLE_TERM
TERM=vt100;                                                           export TERM
DBA=/home/oracle/scripts;                                             export DBA
LOGS=/home/oracle/logs;                                               export LOGS
PATH=$ORACLE_HOME/bin:/grid/11.2.0/bin:$DBA:/usr/bin:/usr/sbin:/etc:/sbin:/bin
PATH=$PATH:/oracle/admin/scripts/
export PATH
CLASSPATH=$ORACLE_HOME/JRE:$ORACLE_HOME/jlib:$ORACLE_HOME/rdbms/jlib:$ORACLE_HOME/network/jlib
export CLASSPATH
LD_LIBRARY_PATH=$ORACLE_HOME/lib;                                     export LD_LIBRARY_PATH
ORAENV_ASK=NO;                                                        export ORAENV_ASK
# Skip the prompt for the ORACLE_SID. (Executed only for non-interactive jobs).
if [ "`tty`" != "not a tty" ]
then
        #       Prompt for the desired ORACLE_SID for interactive jobs
        . $ORACLE_HOME/bin/oraenv
fi
# Ensure one (and only one . is in the PATH)
case "$PATH" in
        *.*)            ;;                      # If already in the path?
        *:)             PATH=${PATH}.: ;;       # If path ends in a colon?
        "")             PATH=. ;;               # If path is null?
        *)              PATH=$PATH:. ;;         # If none of the above?
esac
umask 177
PS_OPTS="-ef"
export PS_OPTS
