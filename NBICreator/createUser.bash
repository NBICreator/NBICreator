#!/bin/bash

if [[ $# -ne 5 ]]; then
	printf "%s\n" "Script needs exactly 6 input variables"
	exit 1
fi

nbiVolumePath="${1}"
if [[ -z ${nbiVolumePath} ]] || ! [[ -d ${nbiVolumePath} ]]; then
    printf "%s\n" "Input variable 1 nbiVolumePath=${nbiVolumePath} is not valid!";
    exit 1
fi

userShortName="${2}"
if [[ -z ${userShortName} ]]; then
    printf "%s\n" "Input variable 2 (userShortName=${userShortName}) cannot be empty";
    exit 1
fi

userPassword="${3}"
userUID="${4}"
userGroups="${5}"

nbiVolumeDatabasePath="/Local/Default/Users/${userShortName}"

# Create user record
printf "%s\n" "Creating user record in NBI user database: ${nbiVolumeDatabasePath}"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -create "${nbiVolumeDatabasePath}" )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Unable to create user record in NBI user database"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

# Add RealName
printf "%s\n" "Adding user RealName: ${userShortName}"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -append "${nbiVolumeDatabasePath}" RealName "${userShortName}" )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Failed to set RealName"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

# Add UniqueID
printf "%s\n" "Adding user UniqueID: ${userUID}"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -append "${nbiVolumeDatabasePath}" UniqueID ${userUID} )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Failed to set UniqueID"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

# Add PrimaryGroup
printf "%s\n" "Adding user PrimaryGroupID: 20"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -append "${nbiVolumeDatabasePath}" PrimaryGroupID 20 )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Failed to set PrimaryGroup"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

#Add NFSHomeDirectory
printf "%s\n" "Adding user NFSHomeDirectory: /tmp"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -append ${nbiVolumeDatabasePath} NFSHomeDirectory /tmp )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Failed to set NFSHomeDirectory"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

# Add UserShell
printf "%s\n" "Adding user UserShell: /bin/bash"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -append ${nbiVolumeDatabasePath} UserShell "/bin/bash" )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Failed to set UserShell"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

#Add Password
printf "%s\n" "Adding user Password: *******"
dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -passwd ${nbiVolumeDatabasePath} "${userPassword}" )
dscl_exit_status=${?}
if [[ ${dscl_exit_status} -ne 0 ]]; then
	printf "%s\n" "Failed to set Password"
	printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
	printf "%s\n" "dscl_output=${dscl_output}"
	exit ${dscl_exit_status}
fi

# Add user to selected groups
if [[ -n ${userGroups} ]]; then
	IFS=';' read -ra groupArray <<< "${userGroups}"
	for i in "${groupArray[@]}"; do
		groupName="${groupArray[i]}"
		groupFileName="${groupName}.plist"
		groupFilePath="${nbiVolumePath}/var/db/dslocal/nodes/Default/groups/${groupFileName}"
		groupDatabasePath="/Local/Default/Groups/${groupName}"

		if [[ -f ${groupFilePath} ]]; then
			dscl_output=$( /usr/bin/dscl -f "${nbiVolumePath}/var/db/dslocal/nodes/Default" localonly -append "${groupDatabasePath}" GroupMembership "${userShortName}" )
			dscl_exit_status=${?}
			if [[ ${dscl_exit_status} -ne 0 ]]; then
				printf "%s\n" "Failed to add user as admin"
				printf "%s\n" "dscl_exit_status=${dscl_exit_status}"
				printf "%s\n" "dscl_output=${dscl_output}"
				exit ${dscl_exit_status}
			fi
		else
			printf "%s\n" "Group ${groupName} does not exist!"
			printf "%s\n" "Skipping group..."
		fi
	done
fi

printf "%s\n" "Adding user: ${userShortName} was successful!"

exit 0