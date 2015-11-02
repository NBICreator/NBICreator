#!/bin/bash
#
#  generateKernelCache.bash
#  NBICreator
#
#  Created by Erik Berglund.
#  Copyright (c) 2015 NBICreator. All rights reserved.
#

if [[ $# -lt 3 ]] || [[ $# -gt 4 ]]; then
	printf "%s\n" "Script needs 3 or 4 input variables"
	exit 1
fi

targetVolumePath="${1}"
if [[ -z ${targetVolumePath} ]] || ! [[ -d ${targetVolumePath} ]]; then
    printf "%s\n" "Input variable 1 targetVolumePath=${targetVolumePath} is not valid!";
    exit 1
fi

nbiVolumePath="${2}"
if [[ -z ${nbiVolumePath} ]] || ! [[ -d ${nbiVolumePath} ]]; then
    printf "%s\n" "Input variable 2 nbiVolumePath=${nbiVolumePath} is not valid!";
    exit 1
fi

osVersionMinor="${3}"
if [[ -z ${osVersionMinor} ]]; then
    printf "%s\n" "Input variable 3 (osVersionMinor=${osVersionMinor}) cannot be empty";
    exit 1
fi

dyldArchi386="${4}"

case ${osVersionMinor} in
	6)
		/usr/sbin/kextcache -a i386 \
							-N \
							-L \
							-m "${nbiVolumePath}/i386/mach.macosx.mkext" \
							-K "${nbiVolumePath}/i386/booter" \
							"${targetVolumePath}/System/Library/Extensions"
	
		/usr/sbin/kextcache -a x86_64 \
							-N \
							-L \
							-m "${sourceVolumePath}/i386/x86_64/mach.macosx.mkext" \
							-K "${nbiVolumePath}/i386/x86_64/booter" \
							"${targetVolumePath}/System/Library/Extensions"
	;;
	7)
		/usr/sbin/kextcache -a i386 \
							-N \
							-L \
							-z \
							-K "${targetVolumePath}/mach_kernel" \
							-c "${nbiVolumePath}/i386/kernelcache" \
							"${targetVolumePath}/System/Library/Extensions"
		
		/usr/sbin/kextcache -a x86_64 \
							-N \
							-L \
							-z \
							-K "${targetVolumePath}/mach_kernel" \
							-c "${nbiVolumePath}/i386/x86_64/kernelcache" \
							"${targetVolumePath}/System/Library/Extensions"
	;;
	8|9)
        if [[ -d ${targetVolumePath} ]]; then
            /bin/rm -f "${targetVolumePath}/var/db/dyld/dyld_"*
            /bin/rm -f "${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"
#/bin/rm -f "${targetVolumePath}/usr/standalone/bootcaches.plist"
        fi

#/usr/sbin/kextcache -update-volume "${targetVolumePath}"
		/usr/sbin/kextcache -a x86_64 \
							-N \
							-L \
							-z \
							-K "${targetVolumePath}/mach_kernel" \
							-c "${nbiVolumePath}/i386/x86_64/kernelcache" \
							"${targetVolumePath}/System/Library/Extensions"
		/usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch x86_64 -force
		
		if [[ ${dyldArchi386} == yes ]]; then
			/usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch i386 -force
		fi

        if [[ -f ${nbiVolumePath}/i386/x86_64/kernelcache ]]; then
            if [[ ! -d ${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup ]]; then
                /bin/mkdir -p "${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup"
            fi
            /bin/cp "${nbiVolumePath}/i386/x86_64/kernelcache" "${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"
        fi
	;;
	10|11)
        if [[ -d ${targetVolumePath} ]]; then
            /bin/rm -f "${targetVolumePath}/var/db/dyld/dyld_"*
            /bin/rm -f "${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"
#/bin/rm -f "${targetVolumePath}/usr/standalone/bootcaches.plist"
        fi

#/usr/sbin/kextcache -update-volume "${targetVolumePath}" -verbose 2
		/usr/sbin/kextcache -a x86_64 \
                            -verbose 2 \
							-N \
                            -L \
							-z \
							-K "${targetVolumePath}/System/Library/Kernels/kernel" \
                            -c "${nbiVolumePath}/i386/x86_64/kernelcache" \
							"${targetVolumePath}/System/Library/Extensions"
		/usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch x86_64 -force
		sleep 60
		if [[ ${dyldArchi386} == yes ]]; then
			/usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch i386 -force
		fi

        if [[ -f ${nbiVolumePath}/i386/x86_64/kernelcache ]]; then
            if [[ ! -d ${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup ]]; then
                /bin/mkdir -p "${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup"
            fi
            /bin/cp "${nbiVolumePath}/i386/x86_64/kernelcache" "${targetVolumePath}/System/Library/Caches/com.apple.kext.caches/Startup/kernelcache"
        fi
	;;
	*)
        printf "%s\n" "Unsupported OS Version: 10.${osVersionMinor}"
	;;
esac

exit 0