#!/bin/bash

### Version 1.0
### Created by Erik Berglund
### https://github.com/erikberglund

#//////////////////////////////////////////////////////////////////////////////////////////////////
###
### DESCRIPTION
###
#//////////////////////////////////////////////////////////////////////////////////////////////////

# This script is designed to create an md5 hash of each internal resource that will be executed with administrative privileges and update a Hashes.plist

#//////////////////////////////////////////////////////////////////////////////////////////////////
###
### USAGE
###
#//////////////////////////////////////////////////////////////////////////////////////////////////

# Usage: ./updateHashes.bash [options] <argv>...
#
# Options:
#  -f		Path to Xcode project root folder "${SRCROOT}"

#//////////////////////////////////////////////////////////////////////////////////////////////////
###
### VARIABLES
###
#//////////////////////////////////////////////////////////////////////////////////////////////////

relativePath_hashPlist="Supporting Files/Property Lists/Hashes.plist"
relativePath_scripts="Supporting Files/Scripts"
relativePath_tools="Supporting Files/Binaries"

#//////////////////////////////////////////////////////////////////////////////////////////////////
###
### FUNCTIONS
###
#//////////////////////////////////////////////////////////////////////////////////////////////////

printError() {
	printf "\t%s\n" "${1}"
}

parse_command_line_options() {
	while getopts "f:" opt; do
		case ${opt} in
			f) path_projectRoot="${OPTARG}";;
			\?)	exit 1 ;;
			:) exit 1 ;;
		esac
	done
	
	updateVariables
}

updateVariables() {
	
	# Verify that passed project root folder exists and is a folder
	if [[ -d ${path_projectRoot} ]]; then
		path_hashPlist="${path_projectRoot}/${relativePath_hashPlist}"
		path_scripts="${path_projectRoot}/${relativePath_scripts}"
		path_tools="${path_projectRoot}/${relativePath_tools}"
	else
		printError "No such file or directory: ${path_projectRoot}"
		exit 1
	fi
}

md5HashOfFileAtPath() {

	# 1 - Path to file to hash
	# Verify passed file exist
	if [[ -f ${1} ]]; then
		local path_fileToHash="${1}"
	else
		printError "File doesn't exist: ${1}"
		exit 1
	fi

	# Bash functions can only return exit status.
	# Therefore if it's echoed it can be assigned if used in a subshell.
	echo $( /sbin/md5 -q "${path_fileToHash}" )
}

updateHashForTool() {
	unset OPTIND;
	while getopts "n:5:" opt; do
		case ${opt} in
			5)	local _md5="${OPTARG}" ;;
			n)	local _name="${OPTARG}" ;;
			\?)	exit 1 ;;
			:) exit 1 ;;
		esac
	done
	
	# Verify a name was passed
	if [[ -z ${_name} ]]; then
		printError "No name passed to ${FUNCNAME}"
		exit 1
	fi
		
	# Create entry for executable in hashPlist if it doesn't exist
	if ! /usr/libexec/PlistBuddy -c "Print :${_name}" "${path_hashPlist}" >/dev/null 2>&1; then
		printf "%s\n" "Adding hash dict for: ${_name}"
		local plistBuddyOutput=$( /usr/libexec/PlistBuddy -c "Add :${_name} dict" "${path_hashPlist}" 2>&1 )
		if (( ${?} != 0 )); then
			printError "${plistBuddyOutput}"
			exit 1
		fi
	fi
	
	# Check if an entry already exist for md5
	if [[ -n ${_md5} ]]; then
		local currentmd5=$( /usr/libexec/PlistBuddy -c "Print :${_name}:md5" "${path_hashPlist}" 2>&1 )
		
		# If no current md5 hash exist, set it. Else only update if it has changed.
		if [[ ${currentmd5} =~ "Does Not Exist" ]]; then
			printf "%s\n" "Adding md5 hash for: ${_name} -> ${_md5}"
			local plistBuddyOutput=$( /usr/libexec/PlistBuddy -c "Add :${_name}:md5 string ${_md5}" "${path_hashPlist}" 2>&1 )
			if (( ${?} != 0 )); then
				printError "${plistBuddyOutput}"
				exit 1
			fi
		elif [[ ${currentmd5} != ${_md5} ]]; then
			printf "%s\n" "Updating md5 hash for: ${_name} -> ${_md5}"
			local plistBuddyOutput=$( /usr/libexec/PlistBuddy -c "Set :${_name}:md5 ${_md5}" "${path_hashPlist}" 2>&1 )
			if (( ${?} != 0 )); then
				printError "${plistBuddyOutput}"
				exit 1
			fi
		fi
	fi
}

#//////////////////////////////////////////////////////////////////////////////////////////////////
###
### MAIN SCRIPT
###
#//////////////////////////////////////////////////////////////////////////////////////////////////

# Parse all passed options
parse_command_line_options "${@}"

# Add directories to scan for executables ( binaries or scripts for example).
# This script will include EVERY item in that directory.
declare -a directoriesToScan=( "${path_scripts}" "${path_tools}" )

for directoryPath in "${directoriesToScan[@]}"; do
	
	# Verify path is a directory
	if [[ ! -d ${directoryPath} ]]; then
		printError "No such file or directory: ${directoryPath}"
		continue
	fi
	
	# Loop through all items in directory
	for item in "${directoryPath}"/*; do
		
		# Verify item is a file
		if [[ -f ${item} ]]; then
			item_name=$( basename "${item}" )
			
			# Calculate item's md5 hash
			item_md5=$( md5HashOfFileAtPath "${item}" )
			
			# Update hashesPlist with item's hashes
			updateHashForTool -n "${item_name}" -5 "${item_md5}"
		fi
	done
done

exit 0