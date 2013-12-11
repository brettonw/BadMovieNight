#!/bin/sh

# set up the log
PUBLISHING_DIR="$PROJECT_DIR/Publishing"
mkdir $PUBLISHING_DIR

# set up the log
LOG="$PUBLISHING_DIR/printenv.log"
/bin/rm -f $LOG
printenv > $LOG
