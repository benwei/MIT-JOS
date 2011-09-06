#!/bin/sh

qemuopts="-hda obj/kern/kernel.img"
. ./grade-functions.sh


$make

check () {
	pts=20
	echo_n "Printf: "
	if grep "6828 decimal is 15254 octal!" jos.out >/dev/null
	then
		pass
	else
		fail
	fi

	pts=10
	echo "Backtrace:"
	args=`grep "ebp f01.* eip f0100.* args" jos.out | awk '{ print $6 }'`
	cnt=`echo $args | grep '^00000000 00000000 00000001 00000002 00000003 00000004 00000005' | wc -w`
	echo_n "   Count "
	if [ $cnt -eq 8 ]
	then
		pass
	else
		fail
	fi

	cnt=`grep "ebp f01.* eip f0100.* args" jos.out | awk 'BEGIN { FS = ORS = " " }
{ print $6 }
END { printf("\n") }' | grep '^00000000 00000000 00000001 00000002 00000003 00000004 00000005' | wc -w`
	echo_n "   Args "
	if [ $cnt -eq 8 ]; then
		pass
	else
		fail "($args)"
	fi

	syms=`grep "kern/init.c:[0-9]*:  *test_backtrace[+]" jos.out`
	symcnt=`grep "kern/init.c:[0-9]*:  *test_backtrace[+]" jos.out | wc -l`
	echo_n "   Symbols "
	if [ $symcnt -eq 6 ]; then
		pass
	else
		fail "($syms)"
	fi
}

run
check

showfinal
