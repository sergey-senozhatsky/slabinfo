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

function usage
{
	echo "Usage: gnuplot-totals.sh [-s W,H] [-r XRANGE_MIN,XRANGE_MAX] -f FILE"
	echo "FILE must be preprocess with slabinfo-plotter.sh -p"
	echo "-s	- set generated image width and height"
	echo "-r	- use only XRANGE_MIN,XRANGE_MAX lines range from the FILE"
}

function do_plotting
{
	range="every ::$xmin_range"

	if [ $xmax_range != 0 ]; then
		range="$range::$xmax_range"
	fi

gnuplot -p << EOF
#!/usr/bin/env gnuplot

set terminal png enhanced size $size
set autoscale xy
set output '$data_file.png'
set xlabel 'samples'
set ylabel 'bytes'

plot "$data_file" $range using 1 title "memory used" with lines, '' $range using 2 title "loss" with lines
EOF
}

while getopts "r::s::f:" opt; do
	case $opt in
		f)
			data_file=$OPTARG
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

if [ "z$data_file" = "z" ]; then
	usage
	exit 1
fi

do_plotting
