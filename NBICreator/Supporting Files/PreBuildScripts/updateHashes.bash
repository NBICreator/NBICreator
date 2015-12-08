#!/bin/bash

### Version 1.0
### Created by Erik Berglund
### https://github.com/erikberglund

#//////////////////////////////////////////////////////////////////////////////////////////////////
###
### DESCRIPTION
###
#//////////////////////////////////////////////////////////////////////////////////////////////////

# This script is designed to create an md5 hash of each internal resource that will be executed with administrative privileges.
# Then it will update the NSString constants for each of the defined resources before the project is built.

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

relativePath_NBCConstants="General Classes/NBCConstants.m"
relativePath_scripts="Supporting Files/Scripts"
#relativePath_tools="Supporting Files/Binaries"

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
		path_NBCConstants="${path_projectRoot}/${relativePath_NBCConstants}"
		path_scripts="${path_projectRoot}/${relativePath_scripts}"
		#path_tools="${path_projectRoot}/${relativePath_tools}"
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
		printError "No such file or directory: ${1}"
		exit 1
	fi

	# Bash functions can only return exit status.
	# Therefore if it's echoed it can be assigned if used in a subshell.
	echo $( /sbin/md5 -q "${path_fileToHash}" )
}

updateHashesInConstantsForTool() {
	unset OPTIND;
	while getopts "n:5:" opt; do
		case ${opt} in
			5)	local _md5="${OPTARG}" ;;
			n)	case "${OPTARG}" in
					'createUser.bash') 						local _constantVariableName="NBCHashMD5CreateUser" ;;
					'generateKernelCache.bash') 			local _constantVariableName="NBCHashMD5GenerateKernelCache" ;;
					'installCertificates.bash') 			local _constantVariableName="NBCHashMD5InstallCertificates" ;;
					'pbzx') 								local _constantVariableName="NBCHashMD5Pbzx" ;;
					'sharedLibraryDependencyChecker.bash') 	local _constantVariableName="NBCHashMD5SharedLibraryDependencyChecker" ;;
					*) printError "Unknown tool: ${OPTARG}"; exit 1;;
				esac ;;
			\?)	exit 1 ;;
			:) exit 1 ;;
		esac
	done
	
	# Verify a name was passed
	if [[ -z ${_constantVariableName} ]]; then
		printError "No name passed to ${FUNCNAME}"
		exit 1
	fi
	
	# Update hash in NBCConstants.m
	sedOutput=$( /usr/bin/sed -i '' -E "s/^(.*${_constantVariableName} = @\").*/\1${_md5}\"\;/" "${path_NBCConstants}" 2>&1 )
	if (( ${?} != 0 )); then
		printError "${sedOutput}"
		exit 1	
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
declare -a directoriesToScan=( "${path_scripts}" )

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
						
			# Verify NBCConstants.m exists
			if [[ -f ${path_NBCConstants} ]]; then

				# Update NBCConstants.m with the item's hashes
				updateHashesInConstantsForTool -n "${item_name}" -5 "${item_md5}"
			else
				printError "No such file or directory: ${path_NBCConstants}"
				exit 1
			fi
		fi
	done
done

exit 0