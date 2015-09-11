#!/bin/bash

# Sergey Senozhatsky, 2015
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

sleepts=1s
slabinfo=slabinfo
record_file=""
lines=1
mode=""

function usage
{
	echo "slabinfo-plotter.sh MODE [-s SLEEP TIMEOUT] PLOTTING_BACKEND"
	echo "MODE:"
	echo "-r FILE			- record samples to file RECORD"
	echo "-n %d			- print only N first slabs in stats"
	echo "-s %d			- samples recording timeout"
	exit 1
}

function do_record
{
	i=0

	echo `uname -r` >> $record_file
	echo `cat /proc/cmdline` >> $record_file
	echo "slabs_pertable:$lines" >> $record_file

	while [ 1 ]; do
		echo "Sample #$i" >> $record_file;
		$slabinfo -N $lines -X >> $record_file;
		sleep $sleepts;
		let i=$i+1;
	done
}

while getopts "r:s:n:" opt; do
	case $opt in
		r)
			record_file=$OPTARG
			;;
		s)
			sleepts=$OPTARG
			;;
		n)
			lines=$OPTARG
			if [ $lines -lt 1 ]; then
				let lines=5
			fi
			;;
		\?)
			echo "Invalid option: -$OPTARG" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			exit 1
			;;
	esac
done

shift $(( OPTIND - 1 ))

if [ "$zrecord_file" = "z" ]; then
	echo "Record file must be provided"
	usage
	exit 1
fi

do_record
