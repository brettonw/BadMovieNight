#!/bin/bash

# ask if we should upload the archive
SHOULD_PUSH=`osascript -e "tell application \"Xcode\"" -e "set noButton to \"No\"" -e "set yesButton to \"Yes\"" -e "set upload_dialog to display dialog \"Do you want to upload to TestFlight?\" buttons {noButton, yesButton} default button yesButton with icon 1" -e "set button to button returned of upload_dialog" -e "if button is equal to yesButton then" -e "return \"True\"" -e "else" -e "return \"False\"" -e "end if" -e "end tell"`
if [ "$SHOULD_PUSH" = "False" ]; then
exit 0
fi

# setup the publishing directories
PUBLISHING_DIR="$PROJECT_DIR/Publishing"
SOURCES_DIR="$PROJECT_DIR/Sources"
mkdir $PUBLISHING_DIR

# set up the log
LOG="$PUBLISHING_DIR/PublishToTestFlight.log"
/bin/rm -f $LOG
echo "Publishing to $PUBLISHING_DIR..." > $LOG

# API_TOKEN and TEAM_TOKEN must be set in Tokens.sh
# Find your API_TOKEN at: https://testflightapp.com/account/
# Find your TEAM_TOKEN at: https://testflightapp.com/dashboard/team/edit/
. $SOURCES_DIR/Tokens.sh
if [ "$API_TOKEN" = "" -o "$TEAM_TOKEN" = "" ]; then
    osascript -e "tell application \"Xcode\"" -e "display dialog \"You must set environment vars for API_TOKEN and TEAM_TOKEN\" buttons {\"OK\"} default button \"OK\" with icon stop" -e "end tell"
    exit 1
fi

# Do some existence checks for the build settings that this script depends on:
if [ "$CODE_SIGN_IDENTITY" = "" -o "$WRAPPER_NAME" = "" -o "$ARCHIVE_DSYMS_PATH" = "" -o "$ARCHIVE_PRODUCTS_PATH" = "" -o "$DWARF_DSYM_FILE_NAME" = "" -o "$INSTALL_PATH" = "" ]; then
    osascript -e "tell application \"Xcode\"" -e "display dialog \"Build settings are missing.\n\nFix this by editing the scheme's Run Script action and selecting the appropriate target from the 'Provide build settings from...' drop down menu.\" buttons {\"OK\"} default button \"OK\" with icon stop" -e "end tell"
    exit 1
fi

# remove the existing file
IPA_NAME="$PUBLISHING_DIR/$PROJECT_NAME.ipa"
echo "Removing $IPA_NAME..." >> $LOG
/bin/rm -f $IPA_NAME >> $LOG 2>&1

# Build paths from build settings environment vars:
DSYM="$ARCHIVE_DSYMS_PATH/$DWARF_DSYM_FILE_NAME"
APP="$ARCHIVE_PRODUCTS_PATH$INSTALL_PATH/$WRAPPER_NAME"
echo "App Wrapper: $APP" >> $LOG

# dump the security info to a temp file for processing
CODESIGN="$PUBLISHING_DIR/codesign.txt"
codesign --display --verbose=2 "$APP" > $CODESIGN 2>&1
CODE_SIGN_IDENTITY=$(perl -e '
my $infile = $ARGV[0];
open (my $in, $infile) or die;
while (<$in>) {
    if (/^Authority=(.*Distribution.*)/) {
        print $1;
        break;
    }
}
close $in;
' "$CODESIGN")
echo "Code Signing Identity: $CODE_SIGN_IDENTITY" >> $LOG

# the name of the embedded mobile provisioning profile
EMBED_PROFILE="${APP}/embedded.mobileprovision"

# make sure the environment variable CODESIGN_ALLOCATE points at the right thing
export CODESIGN_ALLOCATE="/Applications/Xcode.app/Contents/Developer/usr/bin/codesign_allocate"

# Now onto creating the IPA...
echo >> $LOG
echo "Creating IPA at ${IPA_NAME}..." >> ${LOG}
echo /usr/bin/xcrun -sdk iphoneos PackageApplication "\"${APP}\"" -o "\"${IPA_NAME}\"" --embed "\"${EMBED_PROFILE}\"" >> $LOG 2>&1
# /usr/bin/xcrun -sdk iphoneos PackageApplication "${APP}" -o "${IPA_NAME}" --embed "${EMBED_PROFILE}" --sign "${CODE_SIGN_IDENTITY}" >> $LOG 2>&1
/usr/bin/xcrun -sdk iphoneos PackageApplication "${APP}" -o "${IPA_NAME}" --embed "${EMBED_PROFILE}" >> $LOG 2>&1
if [ "$?" -ne 0 ]; then
    echo "There were errors creating IPA." >> $LOG
    osascript -e "tell application \"Xcode\"" -e "display dialog \"There were errors creating IPA... Check $LOG\" buttons {\"OK\"} with icon stop" -e "end tell"
    /usr/bin/open -a /Applications/Utilities/Console.app $LOG
    exit 1
fi 
echo "Done creating IPA ..." >> $LOG

# Now onto creating the zipped .dSYM debugging symbols
echo >> $LOG
SYM_NAME="$PUBLISHING_DIR/$PROJECT_NAME.dSYM.zip"
echo "Zipping .dSYM at $SYM_NAME..." >> $LOG
/bin/rm -f $SYM_NAME
/usr/bin/zip -r $SYM_NAME "$DSYM"
echo "Done zipping ..." >> $LOG

# Bring up an AppleScript dialog in Xcode to enter the Release Notes for this (beta) build:
NOTES=`osascript -e "tell application \"Xcode\"" -e "set notes_dialog to display dialog \"Release notes:\nHint: use Ctrl-J for New Line.\" default answer \"\" buttons {\"Next\"} default button \"Next\" with icon 1" -e "set notes to text returned of notes_dialog" -e "end tell" -e "return notes"`
if [ "$NOTES" = "" ]; then
    echo "User cancelled or did not enter release notes." >> $LOG
    exit 0
fi
echo "Added release notes:" >> $LOG
echo "$NOTES" >> $LOG

# Now onto the upload itself
echo >> $LOG
echo "Uploading to TestFlight... " >> $LOG

/usr/bin/curl "http://testflightapp.com/api/builds.json" \
-F file=@"$IPA_NAME" \
-F dsym=@"$SYM_NAME" \
-F api_token="$API_TOKEN" \
-F team_token="$TEAM_TOKEN" \
-F notify="False" \
-F replace="True" \
-F notes="$NOTES" >> $LOG 2>&1
if [ "$?" -ne 0 ]; then
    echo "There were errors uploading." >> $LOG
    osascript -e "tell application \"Xcode\"" -e "display dialog \"There were errors uploading... Check $LOG\" buttons {\"OK\"} with icon stop" -e "end tell"
    /usr/bin/open -a /Applications/Utilities/Console.app $LOG
    exit 1
fi

# launch the testflight website
echo >> $LOG
echo "Uploaded to TestFlight!" >> $LOG
if [ "$DISABLE_OPEN_TESTFLIGHT_DASHBOARD" != "YES" ]; then
    echo >> $LOG
    echo "Opening https://testflightapp.com/dashboard/builds/ now..." >> $LOG
    /usr/bin/open "https://testflightapp.com/dashboard/builds/"
fi

# increment the build number
echo >> $LOG
build_number=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PROJECT_DIR/$INFOPLIST_FILE")
build_number=$(expr $build_number + 1)
/usr/libexec/Plistbuddy -c "Set CFBundleVersion $build_number" "$PROJECT_DIR/$INFOPLIST_FILE"
echo "Build Number Incremented to $build_number" >> $LOG

# check in this build
cd $PROJECT_DIR
#svn ci --message archive.build.script

