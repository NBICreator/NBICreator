#!/bin/bash

# Commands
readonly cmd_PlistBuddy="/usr/libexec/PlistBuddy"

# Folder Paths
readonly folder_current="${BASH_SOURCE[0]%/*}"

# Files
readonly file_BoardIDtoModelIDcsv="${folder_current}/BoardIDtoModelID.csv"
readonly file_BoardIDtoModelIDplist="${folder_current}/BoardIDtoModelID.plist"
readonly file_BoardIDtoModelIDAmbiguousplist="${folder_current}/BoardIDtoModelIDAmbiguous.plist"

# Other
readonly csvSeparator=";"
declare -i counter=0

# Check that csv-file exist at expected location
if ! [[ -f ${file_BoardIDtoModelIDcsv} ]]; then
	printf "%s\n" "Script need to be run from the same directory as the file BoardIDtoModelID.csv"
	exit 1
fi

# Read each line in csv and update file_BoardIDtoModelIDplist if needed
while read line
do
	counter=$(( counter + 1 ))
	IFS="${csvSeparator}" read boardId modelId <<< "${line}"
	printf "%-21s-> %-14s " "${boardId}" "${modelId}"
	if [[ -n ${boardId} ]]; then
		storedModelIdForBoardId=$( "${cmd_PlistBuddy}" -c "Print ${boardId}" "${file_BoardIDtoModelIDplist}" 2>&1 )
	else
		printf "%s\n" "- No BoardID -"
		continue
	fi
	
	if [[ -z ${modelId} ]]; then
		printf "%s\n" "- No ModelID -"
		continue
	fi
	
	if [[ ${storedModelIdForBoardId} == ${modelId} ]]; then
		# If current BoardID and ModelID mapping in file_BoardIDtoModelIDAmbiguousplist is the same as csv, continue.
		printf "\n"
		
	elif [[ ${storedModelIdForBoardId} =~ "Does Not Exist" ]]; then
		# If current BoardID doesn't exist in file_BoardIDtoModelIDplist, add it
		"${cmd_PlistBuddy}" -c "Add :${boardId} string ${modelId}" "${file_BoardIDtoModelIDplist}" &>/dev/null
		printf "%s\n" "- New! -"
		
	elif [[ ${storedModelIdForBoardId} != ${modelId} ]]; then
		# If a BoardID maps to multiple ModelIDs it's considered ambiguous and will be added to the file_BoardIDtoModelIDAmbiguousplist for investigation
		printf "%s\n"  "- Ambiguous -"
		declare -a ambiguousBoardIDArray=( $( "${cmd_PlistBuddy}" -c "Print :${boardId}:" "${file_BoardIDtoModelIDAmbiguousplist}" 2>&1 ) )
		if [[ ${ambiguousBoardIDArray[*]} =~ "Does Not Exist" ]]; then
			"${cmd_PlistBuddy}" -c "Add :${boardId} array" "${file_BoardIDtoModelIDAmbiguousplist}" &>/dev/null
			"${cmd_PlistBuddy}" -c "Add :${boardId}:0 string ${storedModelIdForBoardId}" "${file_BoardIDtoModelIDAmbiguousplist}" &>/dev/null
		fi
		if ! [[ ${ambiguousBoardIDArray[@]} =~ ${modelId} ]]; then
			"${cmd_PlistBuddy}" -c "Add :${boardId}:0 string ${modelId}" "${file_BoardIDtoModelIDAmbiguousplist}" &>/dev/null	
		fi
	else
		printf "%s\n" "- Unknown ModelID -"
	fi
	
done < "${file_BoardIDtoModelIDcsv}"

exit 0