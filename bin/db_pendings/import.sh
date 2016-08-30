#!/usr/bin/env bash

CURRENT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$CURRENT_PATH/../bash_shared/includes.sh"

UPDATES_PATH="$AC_PATH_ROOT/data/sql/updates/"

function import() {
    db=$1
    folder="db_"$db
    pendingPath="$AC_PATH_ROOT/data/sql/updates/pending_$folder"
    updPath="$UPDATES_PATH/$folder"

    latestUpd=`ls $updPath/ -1 | tail -n 1`

    if [ -z $latestUpd ]; then
        echo "FIRST UPDATE FILE MISSING!! DID YOU ARCHIVED IT?";
        exit;
    fi

    dateToday=`date +%Y_%m_%d`
    counter=0

    dateLast=$latestUpd
    tmp=${dateLast#*_*_*_}
    oldCnt=${tmp%.sql}
    oldDate=${dateLast%_$tmp}

    if [ "$oldDate" = "$dateToday" ]; then
        ((counter=$oldCnt+1))
    fi;

    for entry in "$pendingPath"/*.sql
    do
        if [[ -e $entry ]]; then
            oldVer=$oldDate"_"$oldCnt

            cnt=$(printf -v counter "%02d" $counter ; echo $counter)

            newVer=$dateToday"_"$cnt

            startTransaction="START TRANSACTION;";
            updHeader="ALTER TABLE version_db_"$db" CHANGE COLUMN "$oldVer" "$newVer" bit;";
            endTransaction="COMMIT;";

            newFile="$updPath/"$dateToday"_"$cnt".sql"

            oldFile=$(basename "$entry")
            prefix=${oldFile%_*.sql}
            suffix=${oldFile#rev_}
            rev=${suffix%.sql}

            [[ $prefix = "rev" && $suffix =~ ^-?[0-9]+$ ]] && isRev=1 || isRev=0

            echo "-- DB update $oldVer -> $newVer" > "$newFile";

            if [[ $isRev ]]; then
                echo "DROP PROCEDURE IF EXISTS \`updateDb\`;" >> "$newFile";
                echo "DELIMITER //"  >> "$newFile";
                echo "CREATE PROCEDURE updateDb ()" >> "$newFile";
                echo "proc:BEGIN DECLARE OK VARCHAR(100) DEFAULT 'FALSE';" >> "$newFile";
            fi

            echo "$startTransaction" >> "$newFile";
            echo "$updHeader" >> "$newFile";

            if [[ $isRev ]]; then
                echo "SELECT sql_rev INTO OK FROM version_db_"$db" WHERE sql_rev = '$rev'; IF OK <> 'FALSE' THEN LEAVE proc; END IF;" >> "$newFile";
            fi;

            echo "--" >> "$newFile";
            echo "-- START UPDATING QUERIES" >> "$newFile";
            echo "--" >> "$newFile";

            cat $entry >> "$newFile";

            echo "--" >> "$newFile";
            echo "-- END UPDATING QUERIES" >> "$newFile";
            echo "--" >> "$newFile";

            echo "$endTransaction" >> "$newFile";

            if [[ $isRev ]]; then
                echo "END;" >> "$newFile";
                echo "//" >> "$newFile";
                echo "DELIMITER ;" >> "$newFile";
                echo "CALL updateDb();" >> "$newFile";
                echo "DROP PROCEDURE IF EXISTS \`updateDb\`;" >> "$newFile";
            fi;

            #rm $entry;

            oldDate=$dateToday
            oldCnt=$cnt

            ((counter+=1))
        fi
    done

}

import "world"
import "characters"
import "auth"

echo "Done."