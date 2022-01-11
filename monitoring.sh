#!/bin/bash
: 'Gets architecture and kernel version'
architecture() {
	: 'uname
		s => kernel name
		n => hostname
		r => kernel release
		v => kernel version
		i => hardware platform
		o => operating system
	'
	uname -snrvio
}


cpu_info=$(cat /proc/cpuinfo)

get_cpu_info() {
	echo "$cpu_info" | \
		grep "$1" | \
		uniq | \
		wc -l
}

: 'Gets number of physical processors'
cpu_physical() {
	get_cpu_info "core id"
}

: 'Gets number of virtual processors'
vCPU() {
	get_cpu_info "processor"
}


: 'free
	m => values in mebibytes
'
memory=$(free -m | \
	grep Mem)

get_mem_info() {
	echo "$memory" | \
		awk -v mi=$1 '{print $mi}'
}

total_memory() {
	get_mem_info 2
}

used_memory() {
	get_mem_info 3
}

memory_percentage() {
	echo "" | \
		awk -v um=$1 -v tm=$2 '{printf("%.2f", um/tm*100)}'
}

: 'Gets available memory (RAM) and its utilization rate'
memory_usage() {
	local um=$(used_memory)
	local tm=$(total_memory)
	local mp=$(memory_percentage $um $tm)
	echo "${um}/${tm}MiB (${mp}%)"
}


get_dsk_info() {
	: '
		df
			BG
				block-size (B) is gibibytes (G)
			text4
				type (t) is ext4
			total
				total from disks listed
		grep
			total
				select total line
		awk
			v di=$1
				pass argument 1 ($1) as variable (v) di
		grep
			o
				show only match
			E
				regex to get numbers
	'
	df -BG -text4 --total | \
		grep total | \
		awk -v di=$1 '{print $di}' | \
		grep -oE "[0-9]*\.*[0-9]*"
}

total_disk() {
	get_dsk_info 2
}

used_disk() {
	get_dsk_info 3
}

disk_percentage() {
	get_dsk_info 5
}

: 'Gets available disk and its utilization rate'
disk_usage() {
	local ud=$(used_disk)
	local td=$(total_disk)
	local dp=$(disk_percentage)
	echo "${ud}/${td}GiB (${dp}%)"
}


: 'Gets utilization rate of all processors'
cpu_load() {
	echo \
		"$(top -ibn1 | \
		sed -n "8,$ p" | \
		awk 'BEGIN{sum=0}{sum+=$9}END{printf("%.1f", sum)}')%"
}


: 'Gets date and time of last boot'
last_boot() {
	who -b | \
		grep -oE "[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}"
}


USR_SBIN=/usr/sbin
LVSCAN=$USR_SBIN/lvscan
lvm_count() {
	${LVSCAN} | \
		grep ACTIVE | \
		wc -l
}

: 'Checks if lvm is active'
lvm_use() {
	local count=$(lvm_count)
	if (( $count > 0 )) ; then
		echo "yes"
	else
		echo "no"
	fi
}


SS=$USR_SBIN/ss
: 'Gets number of TCP connections'
tcp_connections() {
	echo "$(
		${SS} -s | \
		grep -oE "estab [0-9]*" | \
		grep -oE "[0-9]*") ESTABLISHED"
}


: 'Gets number of active users'
user_log() {
	who -u | \
		wc -l
}


IP=$USR_SBIN/ip
net_info=$(${IP} address show enp0s3)

get_net_info() {
	echo "$net_info" | \
		grep "$1" | \
		awk '{print $2}'
}

ipv4() {
	get_net_info 'inet ' | \
		sed 's/\/[0-9]*//'
}

mac() {
	get_net_info 'link/ether'
}

: 'Gets IPv4 and MAC addressess'
network() {
	echo "IP $(ipv4) ($(mac))"
}


: 'Gets number of commands executed as sudo'
sudo_count() {
	echo "$(
		sudoreplay -ld /var/log/sudo | \
		wc -l) cmd"
}


wall << .
#Architecture    : $(architecture)
#CPU physical    : $(cpu_physical)
#vCPU            : $(vCPU)
#Memory Usage    : $(memory_usage)
#Disk Usage      : $(disk_usage)
#CPU Load        : $(cpu_load)
#Last boot       : $(last_boot)
#LVM use         : $(lvm_use)
#Connections TCP : $(tcp_connections)
#User log        : $(user_log)
#Network         : $(network)
#Sudo            : $(sudo_count)
.
