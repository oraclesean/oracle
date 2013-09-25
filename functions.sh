#!/bin/sh

#    functions.sh
#    Copyright (C) 2004 Sean Scott oracle_sean@mac.com

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

# functions.sh
# A collection of functions used in other Oracle scripts.

fixcase()
{
  echo $1 | tr '[A-Z]' '[a-z]'
}

is_num()
{
  case $1 in
      *[!0-9]*) return 1 ;;
  esac
}

what_system()
{
  sysname=`uname -s`
  if   [ "$sysname" = "AIX" ]
    then echo "AIX"
  elif [ "$sysname" = "Darwin" ]
    then echo "MAC-OSX"
  elif [ "$sysname" = "SMP_DC_OSx" ]
    then echo "PYRAMID"
  elif [ "$sysname" = "SMP_DC.OSx" ]
    then echo "PYRAMID"
  elif [ "$sysname" = "HP-UX" ]
    then echo "HP"
  elif [ "$sysname" = "OSF1" ]
    then echo "DECOSF"
  elif [ "$sysname" = "ULTRIX" ]
    then echo "ULTRIX"
  elif [ "$sysname" = "Linux" ]
    then echo "Linux"
  elif [ "$sysname" = "SunOS" ]
    then case `uname -r` in
          4*) echo "SUNBSD";;
          5*) echo "SOLARIS";;
          * ) echo "?";;
         esac;
  else echo "?"
  fi
}

function getoptex()
{
  let $# || return 1
  local optlist="${1#;}"
  let OPTIND || OPTIND=1
  [ $OPTIND -lt $# ] || return 1
  shift $OPTIND
  if [ "$1" != "-" -a "$1" != "${1#-}" ]
  then OPTIND=$[OPTIND+1]; if [ "$1" != "--" ]
  then
    local o
    o="-${1#-$OPTOFS}"
    for opt in ${optlist#;}
    do
      OPTOPT="${opt%[;.:]}"
      unset OPTARG
      local opttype="${opt##*[^;:.]}"
      [ -z "$opttype" ] && opttype=";"
      if [ ${#OPTOPT} -gt 1 ]
      then # long-named option
        case $o in
          "--$OPTOPT")
            if [ "$opttype" != ":" ]; then return 0; fi
            OPTARG="$2"

# Added test on following argument being an option identified by '-' this way #
# the routine no longer takes options as an argument thus breaking error #
# detection. 2004-04-04 by raphael at oninet dot pt #

            if [ -z "$OPTARG" -o "${OPTARG:0:1}" = "-" ] ;
            then # error: must have an agrument
              let OPTERR && echo "$0: error: $OPTOPT must have an argument" >&2
              OPTARG="$OPTOPT";
              OPTOPT="?"
              return 1;
            fi
            OPTIND=$[OPTIND+1] # skip option's argument
            return 0
          ;;
          "--$OPTOPT="*)
            if [ "$opttype" = ";" ];
            then # error: must not have arguments
              let OPTERR && echo "$0: error: $OPTOPT must not have arguments" >&2
              OPTARG="$OPTOPT"
              OPTOPT="?"
              return 1
            fi
            OPTARG=${o#"--$OPTOPT="}
            return 0
          ;;
        esac
      else # short-named option
        case "$o" in
          "-$OPTOPT")
            unset OPTOFS
            [ "$opttype" != ":" ] && return 0
            OPTARG="$2"

# Added test on following argument being an option identified by '-' this way #
# the routine no longer takes options as an argument thus breaking error #
# detection. 2004-04-04 by raphael at oninet dot pt #

            if [ -z "$OPTARG" -o "${OPTARG:0:1}" = "-" ] ;
            then
              echo "$0: error: -$OPTOPT must have an argument" >&2
              OPTARG="$OPTOPT"
              OPTOPT="?"
              return 1
            fi
            OPTIND=$[OPTIND+1] # skip option's argument
            return 0
          ;;
          "-$OPTOPT"*)
            if [ $opttype = ";" ]
            then # an option with no argument is in a chain of options
              OPTOFS="$OPTOFS?" # move to the next option in the chain
              OPTIND=$[OPTIND-1] # the chain still has other options
              return 0
            else
              unset OPTOFS
              OPTARG="${o#-$OPTOPT}"
              return 0
            fi
          ;;
        esac
      fi
    done
    echo "$0: error: invalid option: $o"
  fi; fi
  OPTOPT="?"
  unset OPTARG
  return 1
}

function optlistex
{
  local l="$1"
  local m # mask
  local r # to store result
  while [ ${#m} -lt $[${#l}-1] ]; do m="$m?"; done # create a "???..." mask
  while [ -n "$l" ]
  do
    r="${r:+"$r "}${l%$m}" # append the first character of $l to $r
    l="${l#?}" # cut the first charecter from $l
    m="${m#?}" # cut one "?" sign from m
    if [ -n "${l%%[^:.;]*}" ]
    then # a special character (";", ".", or ":") was found
      r="$r${l%$m}" # append it to $r
      l="${l#?}" # cut the special character from l
      m="${m#?}" # cut one more "?" sign
    fi
  done
  echo $r
}

function getopt()
{
  local optlist=`optlistex "$1"`
  shift
  getoptex "$optlist" "$@"
  return $?
} 

mailto()
{
  # mailto to body subject file
  if [ $# -eq 0 ]
    then echo "No email provided"
  else
    subj=
    file=

    if [ $# -ge 3 ]
      then subj=$3
    fi

    if [ $# -ge 4 ]
      then file=$4
    fi

    if [ "$file" != "FILE" ]
      then
        if [ "$subj" != "" ]
          then echo "$2" | mail -s "$3" $1
          else echo "$2" | mail $1
        fi
      else
        if [ -r $2 ]
          then
            if [ "$subj" != "" ]
              then cat "$2" | mail -s "$3" $1
              else cat "$2" | mail $1
            fi
          else
            if [ "$subj" != "" ]
              then echo "Error: Trying to mail non-existent file: $2" | mail -s "$3" $1
              else echo "Error: Trying to mail non-existent file: $2" | mail $1
            fi
        fi
    fi
fi
}

valid_db()
{
  if [ ! $# ]
    then echo "Error - No SID specified"
         return 1
  fi
  mysid=`fixcase $1`

  if [ -r /etc/oratab ]
    then ORATAB=/etc/oratab
    else
      if [ -r /var/opt/oracle/oratab ]
        then ORATAB=/var/opt/oracle/oratab
        else echo "Error - Can't find an oratab file"
             return 1
      fi
  fi

  for ORACLE_SID in `grep -v "^#" $ORATAB | grep -v "^$" | cut -d: -f1`
  do
    if [ "$ORACLE_SID" = "$mysid" ]
      then return 0
    fi
  done
  echo "Error - Invalid database SID: $1"
       return 1
}

db_status()
{
  ps $PS_OPTS | grep -v grep | grep -i ora_pmon_$1 >/dev/null
  if [ $? -eq 0 ]
    then return 0
    else return 1
  fi
}
