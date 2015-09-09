#!/bin/sh

# Sergey Senozhatsky, 2015
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

xmin_range=0
xmax_range=0
size="1500,700"
data_file=""
mode=""

function usage
{
	echo "Usage: gnuplotter.sh -t FILE1[,FILE2,...] [-l FILE] [-s W,H] [-r XRANGE_MIN,XRANGE_MAX]"
	echo "FILEs must be preprocess with -p"
	echo "-t FILE1[,FILE2,...]	- plot totals for FILE1[, FILE2, ...]"
	echo "-l FILE			- plot slabs file"
	echo "-p FILE1[,FILE2,...]	- pre-process RECORD file(-s)"
	echo "-s %d,%d			- set generated image width and height"
	echo "-r %d,%d			- use only XRANGE_MIN,XRANGE_MAX lines range from the files"
}

function do_preprocess
{
	file=$1
	lines=`head -3 $file | grep slabs_pertable | sed s/slabs_pertable://`

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
	`cat $file | grep -A $lines 'Slabs sorted by loss' | egrep -iv '\-\-|Name|Slabs'\
		 | awk '{print $1" "$4+$2*$3" "$4}' > gnuplot_slabs-by-loss-$file`
	if [ $? == 0 ]; then
		echo "File gnuplot_slabs-by-loss-$file"
	fi

	let lines=$lines+1
	`cat $file | grep -A $lines 'Slabs sorted by size' | egrep -iv '\-\-|Name|Slabs'\
		| awk '{print $1" "$4" "$4-$2*$3}' > gnuplot_slabs-by-size-$file`
	if [ $? == 0 ]; then
		echo "File gnuplot_slabs-by-size-$file"
	fi

	`cat $file | grep "Memory used" | awk '{print $3" "$7}' > gnuplot_totals-$file`
	if [ $? == 0 ]; then
		echo "File gnuplot_totals-$file"
	fi
}

function do_slabs_plotting
{
	range="every ::$xmin_range"

	if [ $xmax_range != 0 ]; then
		range="$range::$xmax_range"
	fi

gnuplot -p << EOF
#!/usr/bin/env gnuplot

set terminal png enhanced size $size
set output '${data_files[0]}.png'
set autoscale xy
set xlabel 'samples'
set ylabel 'bytes'
set style histogram columnstacked title textcolor lt -1
set style fill solid 0.30 border lt -1
set xtic rotate 90

plot "${data_files[0]}" $range u 2:xtic(1) title 'SIZE' with boxes, '' $range u 3 title 'LOSS' with boxes
EOF
}

function do_totals_plotting
{
	gnuplot_cmd=""
	range="every ::$xmin_range"
	output=""

	if [ $xmax_range != 0 ]; then
		range="$range::$xmax_range"
	fi

	# have no idea how to force `plot for loop' to do the same
	for i in ${data_files[@]}; do
		output="$output$i"
		gnuplot_cmd="$gnuplot_cmd '$i' $range using 1 title '$i Memory usage' with lines,"
		gnuplot_cmd="$gnuplot_cmd '' $range using 2 title '$i Loss' with lines,"
	done

gnuplot -p << EOF
#!/usr/bin/env gnuplot

set terminal png enhanced size $size
set autoscale xy
set output '$output.png'
set xlabel 'samples'
set ylabel 'bytes'

plot $gnuplot_cmd
EOF
}

while getopts "p::r::s::t::l::" opt; do
	case $opt in
		p)
			data_files=(${OPTARG//,/ })
			for i in ${data_files[@]}; do
				do_preprocess $i
			done
			exit 0
			;;
		t)
			mode=totals
			data_files=(${OPTARG//,/ })
			;;
		l)
			mode=slabs
			data_files=(${OPTARG//,/ })
			;;
		s)
			size=$OPTARG
			;;
		r)
			array=(${OPTARG//,/ })
			xmin_range=${array[0]}
			xmax_range=${array[1]}
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

if [ "z${data_files[0]}" = "z" ]; then
	usage
	exit 1
fi

case $mode in
	totals)
		do_totals_plotting
		;;
	slabs)
		do_slabs_plotting
		;;
	\?)
		echo "Invalid option $mode" >&2
		usage
		;;
esac
