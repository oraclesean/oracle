#!/bin/sh

# Update the OPatch directory for the local Oracle installation. It backs up the current OPatch
# directory to OPatch_old and copies the response file (assuming the file name is the default ocm.rsp).

# For GRID 11.2.0 installations and above, this must be run as the grid owner.

# Pass four command line arguments:
# $1 ORACLE_HOME
# $2 GRID_HOME
# $3 Full patch and file name for the OPatch patch.
# $4 The location to unzip the OPatch patch unzip.

# The patch is usually p6880880_VERSION_OS.zip

su - oracle -c "rm -fR $4/OPatch"
su - oracle -c "unzip $1 -d $4/"

su - oracle -c "mv -f $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_old"
mv -f $GRID_HOME/OPatch $GRID_HOME/OPatch_old

su - oracle -c "cp -fpr $4/OPatch $ORACLE_HOME/"
cp -fpr /oracle/software/OPatch $GRID_HOME/

su - oracle -c "cp -fpr $ORACLE_HOME/OPatch_old/ocm.rsp $ORACLE_HOME/OPatch/"
cp -fpr $GRID_HOME/OPatch_old/ocm.rsp $GRID_HOME/OPatch/

su - oracle -c "$ORACLE_HOME/OPatch/opatch version"
su - oracle -c "$GRID_HOME/OPatch/opatch version"

# Example usage:
# ./update_opatch.sh /oracle/product/11.2.0/db_1/ /grid/11.2.0/ ~/p6880880_112000_Linux-x86-64.zip /oracle/software
