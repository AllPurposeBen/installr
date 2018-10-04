#!/bin/bash

# installo.sh
# A script to (optionally) erase a volume and install macos and
# additional packagesfound in a packages folder in the same directory
# as this script
#
# Modified from munki's installr tool and Rich Trouton's First_Boot_Package_Install_Generator tool. All
# glory to those fine projects.
#
# Installr combines the above, rather than install/running pkgs/scripts from the recovery environment,
# we place the mechanism from First_Boot_Package to the new disk and drops your payload of items off 
# for it, eliminating the headaches of trying to install things from the gimped Recovery environment. 
# Other Changes include baking an OS install app (of your choosing) into the DMG so we can upgrade as 
# part of the (optional) nuke and pave step.
#
# Also adding some arguments to allow for both setting munki settings and host/computer name at installr time
# and detecting existing settings and re-using them.


if [[ $EUID != 0 ]] ; then
    echo "installr: Please run this as root, or via sudo."
    exit -1
fi

INDEX=0
OLDIFS=$IFS
IFS=$'\n'

# dirname and basename not available in Recovery boot
# so we get to use Bash pattern matching
BASENAME=${0##*/}
THISDIR=${0%$BASENAME}
PACKAGESDIR="${THISDIR}payload"
INSTALLMACOSAPP=$(echo "${THISDIR}Install macOS"*.app)
STARTOSINSTALL=$(echo "${THISDIR}Install macOS"*.app/Contents/Resources/startosinstall)

if [ ! -e "$STARTOSINSTALL" ]; then
    echo "Can't find an Install macOS app containing startosinstall in this script's directory!"
    exit -1
fi

## TODO validate options for munki and host/computer name, either passed or picked

echo "****** Welcome to installr! ******"
echo "macOS will be installed from:"
echo "    ${INSTALLMACOSAPP}"
echo "these additional packages will also be installed:"
for PKG in $(/bin/ls -1 "${PACKAGESDIR}"/*.pkg); do
    echo "    ${PKG}"
done
echo
## TODO, add echo of detected hostname/munki settings

# Detect target drive options.
# Will default to existing volume named "Macintosh HD" unless interrupted or not pressent 
if [[ -d "/Volumes/Macintosh HD" ]]; then
	SELECTEDVOLUME="/Volumes/Macintosh HD"
else
	# No Macintosh HD, lets ask
	for VOL in $(/bin/ls -1 /Volumes) ; do
		if [[ "${VOL}" != "OS X Base System" ]] ; then
			let INDEX=${INDEX}+1
			VOLUMES[${INDEX}]=${VOL}
			echo "    ${INDEX}  ${VOL}"
		fi
	done
	read -p "Install to volume # (1-${INDEX}): " SELECTEDINDEX
	SELECTEDVOLUME=${VOLUMES[${SELECTEDINDEX}]}
	# sanity check
	if [[ "${SELECTEDVOLUME}" == "" ]]; then
		exit 0
	fi
fi

# TODO, make moot if argument specifies to do so
read -p "Erase target volume before install (y/N)? " ERASETARGET

case ${ERASETARGET:0:1} in
    [yY] ) /usr/sbin/diskutil reformat "/Volumes/${SELECTEDVOLUME}" ;;
    * ) echo ;;
esac

# Prepare the first boot infrastructure 

# Copy the infrastructure files to the new disk

# Enumerate the items in the FBpayload folder into the fb_installers folder on disk, in numbered folders


echo
echo "Installing macOS to /Volumes/${SELECTEDVOLUME}..."

# build our startosinstall command
CMD="\"${STARTOSINSTALL}\" --agreetolicense --volume \"/Volumes/${SELECTEDVOLUME}\"" 


### Remove below, keep reference
for ITEM in "${PACKAGESDIR}"/* ; do
    FILENAME="${ITEM##*/}"
    EXTENSION="${FILENAME##*.}"
    if [[ -e ${ITEM} ]]; then
        case ${EXTENSION} in
            pkg ) CMD="${CMD} --installpackage \"${ITEM}\"" ;;
            * ) echo "    ignoring non-package ${ITEM}..." ;;
        esac
    fi
done

# kick off the OS install
eval $CMD

