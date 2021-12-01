#!/bin/bash
fstype=$(lsblk -o NAME,FSTYPE | grep 'b2br')
fstab="/etc/fstab"
db="/dev/b2br"
dmb="/dev/mapper/b2br"
todf="ext4	defaults	0	0"
directories=('/home' '/var' '/srv' '/tmp')
partitions=('home' 'var' 'srv' 'tmp')
_directories=('/var/log')
_partitions=('var-log')
_devices=('var--log')

now() {
	date +"%T"
}

log() {
	echo "$(now) -> $1 - $2"
}

log_start() {
	log "START" "$1"
}

log_end() {
	log "END  " "$1"
}

install_packages() {
	log_start "Installing $1"
	dnf install -qy "$1"
	log_end "Installing $1"
}

is_filesystem_type() {
	local partition=$(grep "$1 " <<< "$fstype")
	[ -z $(grep -o "$2" <<< "$partition") ]
}

is_ext4() {
	is_filesystem_type $1 "ext4"
}

format_partitions_to_ext4() {
	local -n l_partitions=$1
	local -n l_devices=$2
	log_start "Formating partitions to ext4 (${l_partitions[*]})"
	for idx in "${!l_partitions[@]}" ; do
		local p="$db/${l_partitions[idx]}"
		local d="${l_devices[idx]}"
		if is_ext4 $d ; then
			mkfs.ext4 -q "$p"
		fi
	done
	log_end "Formating partitions to ext4 (${l_partitions[*]})"
}

mount_temporary_partitions() {
	local -n l_partitions=$1
	local -n l_directories=$2
	log_start "Mounting temporary partitions (${l_partitions[*]})"
	for idx in "${!l_partitions[@]}" ; do
		local d="${l_directories[idx]}"
		local d_new="${d}_new"
		local mnt="/mnt$d_new"
		local p="$db/${l_partitions[idx]}"
		
		: 'Verify that d and mnt are not mountpoints'
		if ! mountpoint -q "$d" && ! mountpoint -q "$mnt" ; then
		
			: 'Create directory'
			mkdir -p "$mnt"
			
			: 'Mount partition p in directory mnt'
			mount "$p" "$mnt"
			
			: 'Copy everything from d to mnt'
			rsync -aqHPSAX "$d/" "$mnt/"
		fi
	done
	log_end "Mounting temporary partitions (${l_partitions[*]})"
}

mount_partitions() {
	local -n l_partitions=$1
	local -n l_directories=$2
	local -n l_devices=$3
	log_start "Mounting partitions (${l_partitions[*]})"
	for idx in "${!l_partitions[@]}" ; do
		local d="${l_directories[idx]}"
		local mnt="/mnt${d}_new"
		local p="$db/${l_partitions[idx]}"
		local entry="${dmb}-${l_devices[idx]}	$d	$todf"
		if ! mountpoint -q "$d" ; then
			mkdir -p "$d"
			
			: 'Insert device entry in fstab,
				the entry contains:
				- device location
				- mountpoint directory
				- filesystem type
				- options
				- dump option
				- fsck (filesystem check) order
			'
			echo "$entry" >> $fstab
			
			: 'Unmount temporary partition'
			umount "$mnt"
			
			: 'Mount partition on directory d according to fstab entry'
			mount "$d"
			
			: 'Restore SELinux default security context for partition'
			restorecon -R "$p"
			
			: 'Remove temporary partition directory'
			rm -fr "$mnt"
		fi
	done
	log_end "Mounting partitions (${l_partitions[*]})"
}

install_packages "rsync"

format_partitions_to_ext4 partitions partitions
mount_temporary_partitions partitions directories
mount_partitions partitions directories partitions

format_partitions_to_ext4 _partitions _devices
mount_temporary_partitions _partitions _directories
mount_partitions _partitions _directories _devices