#!/bin/sh

# Sergey Senozhatsky, 2015
# sergey.senozhatsky.work@gmail.com
#
# This software is licensed under the terms of the GNU General Public
# License version 2, as published by the Free Software Foundation, and
# may be copied, distributed, and modified under those terms.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.


# This program is intended to plot a `slabinfo -X' stats, collected,
# for example, using the following command:
#   while [ 1 ]; do slabinfo -X >> stats; sleep 1; done
#
# Use `gnuplotter.sh -p stats' to pre-process collected records
# and generate graphs (totals, slabs sorted by size, slabs
# sorted by size).
#
# Graphs can be [individually] regenerate with different ranges and
# size (-r %d,%d and -s %d,%d options).
#
# To visually compare N `totals' graphs, do
# gnuplotter.sh -t FILE1-totals FILE2-totals ... FILEN-totals

xmin=0
xmax=0
width=1500
height=700

function usage
{
	echo "gnuplotter.sh [-s W,H] [-r MIN,MAX] -p|-t|-l FILE1 [FILE2 ..]"
	echo "FILEs must contain 'slabinfo -X' samples"
	echo "-p 			- pre-process RECORD FILE(s)"
	echo "-t 			- plot totals for FILE(s)"
	echo "-l 			- plot slabs stats for FILE(s)"
	echo "-s %d,%d		- set image width and height"
	echo "-r %d,%d		- use data samples from a given range"
}

function do_slabs_plotting
{
	inf=$1
	range="every ::$xmin"
	xtic=""

	if [ $xmax != 0 ]; then
		range="$range::$xmax"

		if [ $(($width / $(($xmax-$xmin)))) -gt 5 ]; then
			xtic=":xtic(1)"
		else
			echo "Output is too small, avoid printing slab names"
		fi
	fi

gnuplot -p << EOF
#!/usr/bin/env gnuplot

set terminal png enhanced size $width,$height
set output '$inf.png'
set autoscale xy
set xlabel 'samples'
set ylabel 'bytes'
set style histogram columnstacked title textcolor lt -1
set style fill solid 0.30
set xtic rotate 90
set key left above Left title reverse

plot "$inf" $range u 2$xtic title 'SIZE' with boxes,\
	'' $range u 3 title 'LOSS' with boxes
EOF
}

function do_totals_plotting
{
	gnuplot_cmd=""
	range="every ::$xmin"
	output=""

	if [ $xmax != 0 ]; then
		range="$range::$xmax"
	fi

	# have no idea how to force `plot for loop' to do the same
	for i in ${t_files[@]}; do
		output="$output$i"
		gnuplot_cmd="$gnuplot_cmd '$i' $range using 1 title\
			'$i Memory usage' with lines,"
		gnuplot_cmd="$gnuplot_cmd '' $range using 2 title \
			'$i Loss' with lines,"
	done

gnuplot -p << EOF
#!/usr/bin/env gnuplot

set terminal png enhanced size $width,$height
set autoscale xy
set output '$output.png'
set xlabel 'samples'
set ylabel 'bytes'
set key left above Left title reverse

plot $gnuplot_cmd
EOF
}

function do_preprocess
{
	if=$1

	# use only 'TOP' slab (biggest memory usage or loss)
	let lines=3
	of="$if-slabs-by-loss"
	`cat $if | grep -A $lines 'Slabs sorted by loss' |\
		egrep -iv '\-\-|Name|Slabs'\
		| awk '{print $1" "$4+$2*$3" "$4}' > $of`
	if [ $? = 0 ]; then
		do_slabs_plotting $of
	fi

	let lines=3
	of="$if-slabs-by-size"
	`cat $if | grep -A $lines 'Slabs sorted by size' |\
		egrep -iv '\-\-|Name|Slabs'\
		| awk '{print $1" "$4" "$4-$2*$3}' > $of`
	if [ $? = 0 ]; then
		do_slabs_plotting $of
	fi

	of="$if-totals"
	`cat $if | grep "Memory used" |\
		awk '{print $3" "$7}' > $of`
	if [ $? = 0 ]; then
		t_files[0]=$of
		do_totals_plotting
	fi
}

function parse_opts
{
	while getopts "ptlr::s::h" opt; do
		case $opt in
			p)
				mode=preprocess
				;;
			t)
				mode=totals
				;;
			l)
				mode=slabs
				;;
			s)
				array=(${OPTARG//,/ })
				width=${array[0]}
				height=${array[1]}
				;;
			r)
				array=(${OPTARG//,/ })
				xmin=${array[0]}
				xmax=${array[1]}
				;;
			h)
				usage
				exit 0
				;;
			\?)
				echo "Invalid option: -$OPTARG" >&2
				exit 1
				;;
			:)
				echo "-$OPTARG requires an argument." >&2
				exit 1
				;;
		esac
	done

	return $OPTIND
}

function parse_args
{
	idx=0

	for p in "$@"; do
		case $mode in
			preprocess)
				files[$idx]=$p
				idx=$idx+1
				;;
			totals)
				t_files[$idx]=$p
				idx=$idx+1
				;;
			slabs)
				files[$idx]=$p
				idx=$idx+1
				;;
		esac
	done
}

parse_opts "$@"
argstart=$?
parse_args "${@:$argstart}"

if [ ${#files[@]} = 0 ] && [ ${#t_files[@]} = 0 ]; then
	usage
	exit 1
fi

case $mode in
	preprocess)
		for i in ${files[@]}; do
			do_preprocess $i
		done
		;;
	totals)
		do_totals_plotting
		;;
	slabs)
		for i in ${files[@]}; do
			do_slabs_plotting $i
		done
		;;
	*)
		echo "Unknown mode $mode" >&2
		usage
		exit 1
	;;
esac
