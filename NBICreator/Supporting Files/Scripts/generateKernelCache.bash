#!/bin/bash
#
#  generateKernelCache.bash
#  NBICreator
#
#  Created by Erik Berglund.
#  Copyright (c) 2015 NBICreator. All rights reserved.
#

if [[ $# -ne 3 ]]; then
	printf "%s\n" "Script needs exactly 3 input variables"
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
	[8-9])
		/usr/sbin/kextcache -update-volume "${targetVolumePath}"
		/usr/sbin/kextcache -a x86_64 \
							-N \
							-L \
							-z \
							-K "${targetVolumePath}/mach_kernel" \
							-c "${nbiVolumePath}/i386/x86_64/kernelcache" \
							"${targetVolumePath}/System/Library/Extensions"
		/usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch x86_64 -force
	;;
	10)
		/usr/sbin/kextcache -update-volume "${targetVolumePath}"
		/usr/sbin/kextcache -a x86_64 \
							-N \
							-L \
							-z \
							-K "${targetVolumePath}/System/Library/Kernels/kernel" \
							-c "${nbiVolumePath}/i386/x86_64/kernelcache" \
							"${targetVolumePath}/System/Library/Extensions"
		/usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch x86_64 -force
	;;
	11)
        /usr/sbin/kextcache -update-volume "${targetVolumePath}"
        /usr/sbin/kextcache -a x86_64 \
                            -N \ # Only include extensions required for network disk boot
                            -L \ # Only include extensions required for local disk boot
                            -z \
                            -K "${targetVolumePath}/System/Library/Kernels/kernel" \
                            -c "${nbiVolumePath}/i386/x86_64/kernelcache" \
                            "${targetVolumePath}/System/Library/Extensions"
        /usr/bin/update_dyld_shared_cache -root "${targetVolumePath}" -arch x86_64 -force
	;;
	*)
	;;
esac

exit 0