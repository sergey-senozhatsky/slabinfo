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
lines=5
mode=""
plotting_backend=gnuplot

function usage
{
	echo "slabinfo-plotter.sh MODE [-s SLEEP TIMEOUT] PLOTTING_BACKEND"
	echo "MODE:"
	echo "-r FILENAME	- record samples to file RECORD"
	echo "-p FILENAME	- pre-process RECORD file"
	echo "-b BACKEND	- plotting backend (gnuplot, etc.)"
	echo "-n %d		- print only N first slabs in stats"
	exit 1
}

function do_gnuplot_preprocess
{
	lines=`head -3 $record_file | grep slabs_pertable | sed s/slabs_pertable://`
	
	if [ "z$lines" = "z" ]; then
		echo "Unable to recognize file format"
		exit 1
	fi

	if [ $lines -lt 1 ]; then
		echo "Unable to recognize file format"
		exit 1
	fi

	#let lines=$lines+1
	# we extrct only 'TOP' slab
	let lines=2
	`cat $record_file | grep -A $lines 'Slabs sorted by loss' | egrep -iv '\-\-|Name|Slabs'\
		 | awk '{print $1" "$4+$2*$3" "$4}' > gnuplot_slabs-by-loss-$record_file`
	if [ $? == 0 ]; then
		echo "File gnuplot_slabs-by-loss-$record_file"
	fi

	let lines=$lines+1
	`cat $record_file | grep -A $lines 'Slabs sorted by size' | egrep -iv '\-\-|Name|Slabs'\
		| awk '{print $1" "$4" "$4-$2*$3}' > gnuplot_slabs-by-size-$record_file`
	if [ $? == 0 ]; then
		echo "File gnuplot_slabs-by-size-$record_file"
	fi

	`cat $record_file | grep "Memory used" | awk '{print $3" "$7}' > gnuplot_totals-$record_file`
	if [ $? == 0 ]; then
		echo "File gnuplot_totals-$record_file"
	fi
}

function do_record
{
	i=0

	echo `uname -r` >> $record_file
	echo `cat /proc/cmdline` >> $record_file
	echo "slabs_pertable:$lines" >> $record_file

	while [ 1 ]; do
		echo "Sample #$i" >> $record_file;
		$slabinfo -N $lines -R -X >> $record_file;
		sleep $sleepts;
		let i=$i+1;
	done
}

while getopts "r:p:s:n:b:" opt; do
	case $opt in
		r)
			mode=record
			record_file=$OPTARG
			;;
		p)
			mode=preprocess
			record_file=$OPTARG
			;;
		s)
			sleepts=$OPTARG
			;;
		b)
			plotting_backend=$OPTARG
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

case $mode in
	record)
		do_record
		;;
	preprocess)
		if [ "z$plotting_backend" = "zgnuplot" ]; then
			do_gnuplot_preprocess
		else
			echo "Unsupported b=plotting backend: $plotting_backend" >&2
			exit 1
		fi
		;;
	\?)
		echo "Invalid option $mode" >&2
		usage
		;;
esac
