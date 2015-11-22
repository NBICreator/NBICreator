#!/bin/bash
#
#  installCertificates.bash
#  NBICreator
#
#  Created by Erik Berglund.
#  Copyright (c) 2015 NBICreator. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

###
### VARIABLES
###

path_keychain_system="/Library/Keychains/System.keychain"
path_keychain_trust_plist="/Library/Security/Trust Settings/Admin.plist"
path_certificates_system="/usr/local/certificates"
path_certificates_netinstall="/Volumes/Image Volume/Packages/Certificates"

declare -a certificate_stores=( "${path_certificates_system}"\
                                "${path_certificates_netinstall}" )
certificate_stores_count=${#certificate_stores[@]}

###
### FUNCTIONS
###

get_certificates() {
    old_ifs=${IFS}; IFS=$'\n'
    certificates=( $( /usr/bin/find "${certificate_stores[@]}" -type f ) )
    certificates_count=${#certificates[@]}
    IFS=${old_ifs}
}

add_certificate() {
    local path_certificate="${1}"

    security_output=$( /usr/bin/security add-trusted-cert -r trustRoot -k "${path_keychain_system}" -i "${path_keychain_trust_plist}" -o "${path_keychain_trust_plist}" "${path_certificate}" 2>&1 )
    security_exit_status=${?}

    if [[ ${security_exit_status} -ne 0 ]]; then
        printf "%s\n" "Unable to add certificate ${path_certificate##*/} to kechain at path ${path_keychain_system}!"
        printf "%s\n" "security_output=${security_output}"
        printf "%s\n" "security_exit_status=${security_exit_status}"
    fi
}

###
### MAIN SCRIPT
###

if [[ ! -f ${path_keychain_system} ]]; then
    printf "%s\n" "System keychain not found, trying to create it!"
    systemkeychain_output=$( /usr/sbin/systemkeychain -fcC 2>&1 )
    systemkeychain_exit_status=${?}

    if [[ ${systemkeychain_exit_status} -ne 0 ]]; then
        printf "%s\n" "Unable to create system keychain!"
        printf "%s\n" "systemkeychain_output=${systemkeychain_output}"
        printf "%s\n" "systemkeychain_exit_status=${systemkeychain_exit_status}"
        exit ${systemkeychain_exit_status}
    fi
fi

if [[ ! -f ${path_keychain_trust_plist} ]]; then
    printf "%s\n" "System keychain trust plist file not found, trying to create it!"
    mkdir_output=$( /bin/mkdir -p "${path_keychain_trust_plist%/*}" )
    mkdir_exit_status=${?}

    if [[ ${mkdir_exit_status} -ne 0 ]]; then
        printf "%s\n" "Unable to create folder ${path_keychain_trust_plist%/*}"
        printf "%s\n" "mkdir_output=${mkdir_output}"
        printf "%s\n" "mkdir_exit_status=${mkdir_exit_status}"
        exit ${mkdir_exit_status}
    fi

    touch_output=$( /usr/bin/touch "${path_keychain_trust_plist}" 2>&1 )
    touch_exit_status=${?}

    if [[ ${touch_exit_status} -ne 0 ]]; then
        printf "%s\n" "Unable to create system keychain trust plist file!"
        printf "%s\n" "touch_output=${touch_output}"
        printf "%s\n" "touch_exit_status=${touch_exit_status}"
        exit ${touch_exit_status}
    fi
fi

get_certificates

if [[ ${certificates_count} -eq 0 ]]; then
    printf "%s\n" "Found no certificates to install..."
    exit 0
fi

for ((i=0; i<certificates_count; i++)); do
    add_certificate "${certificates[i]}"
done

exit 0