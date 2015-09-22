#!/bin/bash

### Version 1.0
### Created by Erik Berglund

###
### DESCRIPTION
###

# This script is designed to check all shared library dependencies the passed binary and all it's shared libraries requires.
# Then it lists all dependencies that are missing on the passed system volume

###
### USAGE
###

# Usage: ./sharedLibraryDependencyChecker.bash [options] <argv>...
#
# Options:
#  -t			[Required] Path to application (.app) or binary. Multiple paths can be defined with additional -t args.
#  -v			(Optional/Ignored if -a is used) Path to system volume root
#  -x			(Optional) Format output as regex strings
#  -a			(Optional) Output all dependencies for target(s)
#  -r			(Optional) Output what file(s) depends on each output entry
#  -f			(Optional) Output full paths for all files (Used to turn off the default behaviour of only outputting path to the .framework bundle for files contained within)
#  -e [regex]	(Optional) Output full paths for all files matched by [regex] (Used to turn off the default behaviour for matching files of only outputting path to the .framework bundle for files contained within)
#  -i [regex]	(Optional) Igore item(s) matching [regex] in output

###
### VARIABLES
###

path_tmp_relational_plist="/tmp/$( uuidgen ).plist"

declare -a target_executables
declare -a external_dependencies
declare -a bundled_dependencies
declare -a missing_external_dependencies
declare -a missing_bundled_dependencies

###
### FUNCTIONS
###

resolve_dependencies_for_target() {

	# 1 - Path to the dependency to check
	local dependency_target="${1}"
	
	if [[ -f "${dependency_target}" ]]; then
		
		# Loop through all dependencies listed by 'otool -L <dependency_target>'
		while read dependency_path; do
			
			# Get absolute path to dependency
			local dependency_library_path=$( resolve_dependency_path "${dependency_path}" "${dependency_target%/*}" )
			
			if [[ -L ${dependency_library_path} ]]; then
				# If dependency path is a symbolic link
				
				symlink_path="${dependency_library_path}"
								
				while [[ -L ${symlink_path} ]]; do
					readlink_path=$( readlink "${symlink_path}" )
					
					if ! [[ ${readlink_path} =~ ^Versions ]]; then
						add_item_to_array external_dependencies "${symlink_path}"
						symlink_path=$( resolve_dependency_path "${readlink_path}" "${symlink_path%/*}" )
					else
						break
					fi
				done
				
				dependency_path="${symlink_path}"
				dependency_library_path="${symlink_path}"
			elif [[ -n ${dependency_library_path} ]]; then
				# If dependency path is not empty
				
				if [[ ${dependency_library_path} =~ \.framework ]] && [[ ${outputAbsolutePath} != yes ]]; then
			
					# If item contains '.framework' then just add the path to the framework bundle
					dependency_library_path_key=$( sed -nE 's/^(.*.framework)\/.*$/\1/p' <<< ${dependency_library_path}  )
				else
					dependency_library_path_key=${dependency_library_path}
				fi
				current_key_value=$( /usr/libexec/PlistBuddy -c "Print ${dependency_library_path_key}" "${path_tmp_relational_plist}" 2>&1 )
				if [[ ${current_key_value} =~ "Does Not Exist" ]]; then
					plist_buddy_output_add_array=$( /usr/libexec/PlistBuddy -c "Add '""${dependency_library_path_key}""' array" "${path_tmp_relational_plist}" 2>&1 )
				fi
				/usr/libexec/PlistBuddy -c "Add '""${dependency_library_path_key}:0""' string ${dependency_target}" "${path_tmp_relational_plist}"
			else
				# If dependency_library_path is empty, continue
				continue
			fi
			
			if [[ ${dependency_path} =~ ^@ ]] && ! array_contains_item bundled_dependencies "${dependency_library_path}"; then
				
				# Add dependency to bundled_dependencies array if it's not already added
				add_item_to_array bundled_dependencies "${dependency_library_path}"
				
				# Resolve current dependency's dependencies as well
				resolve_dependencies_for_target "${dependency_library_path}"
			elif ! array_contains_item external_dependencies "${dependency_library_path}"; then
				
				# Add dependency to external_dependencies array if it's not already added
				add_item_to_array external_dependencies "${dependency_library_path}"
				
				# Resolve current dependency's dependencies as well
				resolve_dependencies_for_target "${dependency_library_path}"
			fi
		done < <( otool -L "${dependency_target}" | sed -nE "s/^[ $( printf '\t' )]+(.*)\(.*$/\1/p" 2>&1 )
	else
		printf "%s\n" "[ERROR] No such file: ${dependency_target}" >&2
	fi
}

resolve_dependency_path() {
	
	# 1 - Path to the dependency to check
	local dependency_path="${1}"
	
	# 2 - Path to the linker's @executable_path for current dependency
	local linker_executable_path="${2}"
	
	if [[ ${dependency_path} =~ ^@ ]]; then
	
		# Replace the linker variable with an absolute path
		case "${dependency_path%%/*}" in
			'@executable_path')
				local base_path=$( sed -E 's/^\///g;s/\/$//g' <<< "${linker_executable_path}" )
			;;
			*)
				printf "%s\n" "[ERROR] ${dependency_path%%/*} - Unknown Linker Path!" >&2
				exit 1
			;;
		esac
		
		# Remove the linker variable and any slash prefixes
		dependency_path=$( sed -E 's,^[^/]*/,,;s/\/$//g' <<< "${dependency_path}" )
	fi
	
	# Check if the dependency_path contains any parent directory notations ( ../../ )
	if [[ ${dependency_path} =~ \.\./ ]]; then
		
		# Read directory paths to arrays with each directory as one item
		IFS='/' read -a base_path_folders <<< "${base_path:-${2}}"
		IFS='/' read -a dependency_path_folders <<< "${dependency_path}"
		
		# Count number of parent directory steps to remove ( ../../ )
		count=0
		for directory in ${dependency_path_folders[*]}; do
			if [[ ${directory} == .. ]]; then
				(( count++ ))
			fi
		done
			
		# Remove $count directories from both arrays and join the shortened version to one correct directory path
		IFS=/ eval 'dependency_path="/${base_path_folders[*]:0:$(( ${#base_path_folders[@]} - count ))}/${dependency_path_folders[*]:${count}}"'
	elif [[ ${dependency_path} == ${1##*/} ]]; then
		
		dependency_path="${linker_executable_path}/${dependency_path}"
	fi
	
	# Return path and remove extra '/' in path
	echo -n "${dependency_path}" | sed 's/\/\//\//g'
}

add_item_to_array () {
	
	# 1 - Array variable name
	local array="${1}"
	shift 1
	
	# Add passed item to the array
	eval "${array}+=( $( printf "'%s' " "${@}" ) )"
}

array_contains_item() {
	
	# 1 - Array variable name
	local array="${1}[@]"
	
	# 2 - Item to add to variable
	local item="${2}"
	
	# Return 0 if item already exist in array, else return 1
	for arrayItem in "${!array}"; do
		if [[ ${item} == ${arrayItem} ]]; then return 0; fi
	done
	return 1
}

clean_and_sort_array() {
	
	# 1 - Array variable name
	local array="${1}[@]"
	
	declare -a newArray
	for arrayItem in "${!array}"; do
		if [[ ${arrayItem} =~ \.framework && ( ${outputAbsolutePath} != yes && ! ${arrayItem} =~ ${outputAbsolutePathForRegex} ) ]]; then
			
			# If item contains '.framework' then just add the path to the framework bundle
			newArray+=( "$( sed -nE 's/^(.*.framework)\/.*$/\1/p' <<< ${arrayItem}  )" )
		else
			newArray+=( "${arrayItem}" )
		fi
	done
	
	# Sort the new array
	IFS=$'\n' array=( $( sort <<< "${newArray[*]}" | uniq ) )
	
	# Update passed array with the cleaned and sorted version
	eval "${1}=( $( printf "'%s' " "${array[@]}" ) )"
}

find_missing_dependencies_on_volume() {
	
	# 1 - Array variable name
	local array="${1}[@]"
	
	# 2 - Array variable name for new array
	# -
	
	declare -a newArray
	for arrayItem in "${!array}"; do
		
		# Create path to item om target volume
		itemPathOnTargetVolume=$( sed -E 's/\/+/\//g' <<< "${targetVolumePath}/${arrayItem}" )

		# If item doesn't exist on target volume, add it to newArray
		if ! [[ -e ${itemPathOnTargetVolume} ]]; then newArray+=( "${arrayItem}" ); fi
		
		# Update passed array with missing shared libraries
		eval "${2}=( $( printf "'%s' " "${newArray[@]}" ) )"
	done
}

parse_command_line_options() {
	while getopts "ae:fi:rt:v:x" opt; do
		case ${opt} in
			a)  outputAll="yes" ;;
			e)  outputAbsolutePathForRegex="${OPTARG}" ;;
			f)  outputAbsolutePath="yes" ;;
			i)  outputIgnoreRegex="${OPTARG}" ;;
			r)	outputReferences="yes" ;;
			t)	target_executables+=( "${OPTARG}" ) ;;
			v)	targetVolumePath="${OPTARG}" ;;
			x)	outputRegex="yes" ;;
			\?)	print_usage; exit 1 ;;
			:) print_usage; exit 1 ;;
		esac
	done
	
	verfiy_command_line_options
}

verfiy_command_line_options() {
	for (( i=0; i<${#target_executables[@]}; i++)); do
		targetExecutable="${target_executables[i]}"
		if [[ -z ${targetExecutable} ]]; then
		    printf "%s\n" "Input variable 1 targetExecutable=${targetExecutable} is not valid!";
			print_usage
		    exit 1
		elif [[ ${targetExecutable##*.} == app ]]; then
			targetExecutableName=$( /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${targetExecutable}/Contents/Info.plist" 2>&1 )
			if [[ -n ${targetExecutableName} ]]; then
				targetExecutable="${targetExecutable}/Contents/MacOS/${targetExecutableName}"
				if ! [[ -f ${targetExecutable} ]]; then
					printf "%s\n" "Could not find executable from App Bundle!"
					printf "%s\n" "Try passing the executable path directly."
					print_usage
					exit 1
				else
					target_executables[${i}]="${targetExecutable}"
				fi
			else
				printf "%s\n" "Could not get CFBundleExecutable from ${targetExecutable} from App Bundle!"
				printf "%s\n" "Try passing the executable path directly."
				print_usage
				exit 1	
			fi
		fi
	done
	
	if [[ ${outputAll} != yes ]]; then
		if [[ -z ${targetVolumePath} ]] || ! [[ -d ${targetVolumePath} ]]; then
		    printf "%s\n" "Input variable 2 targetVolumePath=${targetVolumePath} is not valid!";
			print_usage
		    exit 1
		fi
	fi
	
	if ! [[ -f /usr/bin/otool ]]; then
		printf "%s\n" "Could not find otool"
	fi
}

print_usage() {
	printf "\n%s\n\n" "Usage: ./${0##*/} [options] <argv>..."
	printf "%s\n" "Options:"
	printf "  %s\t\t%s\n" "-t" "[Required] Path to application (.app) or binary. Multiple paths can be defined with additional -t args."
	printf "  %s\t\t%s\n" "-v" "(Optional/Ignored if -a is used) Path to system volume root"
	printf "  %s\t\t%s\n" "-x" "(Optional) Format output as regex strings"
	printf "  %s\t\t%s\n" "-a" "(Optional) Output all dependencies for target(s)"
	printf "  %s\t\t%s\n" "-r" "(Optional) Output what file(s) depends on each output entry"
	printf "  %s\t\t%s\n" "-f" "(Optional) Output full paths for all files (Used to turn off the default behaviour of only outputting path to the .framework bondle for files contained within)"
	printf "  %s\t%s\n" "-e [regex]" "(Optional) Output full paths for all files matched by [regex] (Used to turn off the default behaviour for matching files of only outputting path to the .framework bundle for files contained within)"
	printf "  %s\t%s\n" "-i [regex]" "(Optional) Igore item(s) matching [regex] in output"
	printf "\n"
}

###
### MAIN SCRIPT
###

parse_command_line_options "${@}"
for (( i=0; i<${#target_executables[@]}; i++)); do
	targetExecutable="${target_executables[i]}"
	resolve_dependencies_for_target "${targetExecutable}"
done
clean_and_sort_array external_dependencies
clean_and_sort_array bundled_dependencies
if [[ ${outputAll} != yes ]]; then
	find_missing_dependencies_on_volume external_dependencies missing_external_dependencies
fi

# Print result
missing_external_dependencies_count=${#missing_external_dependencies[@]}

if [[ ${outputRegex} != yes ]]; then
	if [[ ${outputAll} == yes ]]; then
		if [[ ${#external_dependencies[@]} -ne 0 ]]; then
			printf "\n%s\n" "[${targetExecutable} - All Dependencies]"
			for ((i=0; i<${#external_dependencies[@]}; i++)); do
				if [[ -n ${outputIgnoreRegex} && ${external_dependencies[i]} =~ ${outputIgnoreRegex} ]]; then
					continue
				fi
				printf "\t%s\n" "$((${i}+1)) ${external_dependencies[i]}"
				if [[ ${outputReferences} == yes ]]; then
					printf "\n\t\t%s\n" "## Referenced by the following sources ##"
					oldIFS=${IFS}; IFS=$'\n'
					current_key_value=( $( /usr/libexec/PlistBuddy -c "Print '""${external_dependencies[i]}""'" "${path_tmp_relational_plist}" | grep -Ev [{}] | sed -E 's/^[ $( printf '\t' )]*//' 2>&1 ) )
					IFS=${oldIFS}
					for ((j=0; j<${#current_key_value[@]}; j++)); do
						printf "\t\t%s\n" "${current_key_value[j]}"
					done
					printf "\n"
				fi
			done
		else
			printf "\n%s\n" "[${1##*/} - No Dependencies]"
		fi
	else
		if [[ ${missing_external_dependencies_count} -ne 0 ]]; then
			printf "\n%s\n" "[${targetExecutable} - Missing Dependencies]"
			for ((i=0; i<missing_external_dependencies_count; i++)); do
				if [[ -n ${outputIgnoreRegex} && ${missing_external_dependencies[i]} =~ ${outputIgnoreRegex} ]]; then
					continue
				fi
				printf "\t%s\n" "$((${i}+1)) ${missing_external_dependencies[i]}"
				if [[ ${outputReferences} == yes ]]; then
					printf "\n\t\t%s\n" "## Referenced by the following sources ##"
					oldIFS=${IFS}; IFS=$'\n'
					current_key_value=( $( /usr/libexec/PlistBuddy -c "Print '""${missing_external_dependencies[i]}""'" "${path_tmp_relational_plist}" | grep -Ev [{}] | sed -E 's/^[ $( printf '\t' )]*//' 2>&1 ) )
					IFS=${oldIFS}
					for ((j=0; j<${#current_key_value[@]}; j++)); do
						printf "\t\t%s\n" "${current_key_value[j]}"
					done
					printf "\n"
				fi
			done
		else
			printf "\n%s\n" "[${1##*/} - All Dependencies Exist]"
		fi
	fi
else
	if [[ ${outputAll} == yes ]]; then
		if [[ ${#external_dependencies[@]} -ne 0 ]]; then
			for ((i=0; i<${#external_dependencies[@]}; i++)); do
				if [[ -n ${outputIgnoreRegex} && ${external_dependencies[i]} =~ ${outputIgnoreRegex} ]]; then
					continue
				fi
				dependency_folder=${external_dependencies[i]%/*}
				dependency_item=$( sed 's/[+]/\\&/g' <<< "${external_dependencies[i]##*/}" )
				if [[ ( ${outputAbsolutePath} == yes || ${dependency_folder} =~ ${outputAbsolutePathForRegex} ) && ${dependency_folder} =~ .framework ]]; then
					printf "%s\n" ".*/$( sed -nE 's/^.*\/(.*.framework(\/.*$|$))/\1/p' <<< ${dependency_folder} )/${dependency_item}.*"
				else
					printf "%s\n" ".*/${dependency_folder##*/}/${dependency_item}.*"
				fi
			done
		fi
	else
		if [[ ${missing_external_dependencies_count} -ne 0 ]]; then
			for ((i=0; i<missing_external_dependencies_count; i++)); do
				if [[ -n ${outputIgnoreRegex} && ${missing_external_dependencies[i]} =~ ${outputIgnoreRegex} ]]; then
					continue
				fi
				dependency_folder=${missing_external_dependencies[i]%/*}
				dependency_item=$( sed 's/[+]/\\&/g' <<< "${missing_external_dependencies[i]##*/}" )
				if [[ ${outputAbsolutePath} == yes || ${dependency_folder} =~ ${outputAbsolutePathForRegex} ]]; then
					printf "%s\n" ".*/$( sed -nE 's/^.*\/(.*.framework(\/.*$|$))/\1/p' <<< ${dependency_folder} )/${dependency_item}.*"
				else
					printf "%s\n" ".*/${dependency_folder##*/}/${dependency_item}.*"
				fi
			done
		fi
	fi
fi

rm "${path_tmp_relational_plist}"

exit 0