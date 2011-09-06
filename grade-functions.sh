verbose=false

if [ "x$1" = "x-v" ]
then
	verbose=true
	out=/dev/stdout
	err=/dev/stderr
else
	out=/dev/null
	err=/dev/null
fi

if gmake --version >/dev/null 2>&1; then make=gmake; else make=make; fi

#
# QEMU
#

timeout=30
preservefs=n
qemu=`$make -s --no-print-directory print-qemu`
gdbport=`$make -s --no-print-directory print-gdbport`
qemugdb=`$make -s --no-print-directory print-qemugdb`
brkfn=readline

echo_n () {
	# suns can't echo -n, and Mac OS X can't echo "x\c"
	# assume argument has no doublequotes
	awk 'BEGIN { printf("'"$*"'"); }' </dev/null
}

# Run QEMU with serial output redirected to jos.out.  If $brkfn is
# non-empty, wait until $brkfn is reached or $timeout expires, then
# kill QEMU.
run () {
	qemuextra=
	if [ "$brkfn" ]; then
		qemuextra="-S $qemugdb"
	fi

	t0=`date +%s.%N 2>/dev/null`
	(
		ulimit -t $timeout
		exec $qemu -nographic $qemuopts -serial file:jos.out -monitor null -no-reboot $qemuextra
	) >$out 2>$err &
	PID=$!

	# Wait for QEMU to start
	sleep 1

	if [ "$brkfn" ]; then
		# Find the address of the kernel $brkfn function,
		# which is typically what the kernel monitor uses to
		# read commands interactively.
		brkaddr=`grep " $brkfn\$" obj/kern/kernel.sym | sed -e's/ .*$//g'`

		(
			echo "target remote localhost:$gdbport"
			echo "br *0x$brkaddr"
			echo c
		) > jos.in
		gdb -batch -nx -x jos.in > /dev/null 2>&1

		# Make sure QEMU is dead.  On OS X, exiting gdb
		# doesn't always exit QEMU.
		kill $PID > /dev/null 2>&1
	fi
}

#
# Scoring
#

pts=5
part=0
partpos=0
total=0
totalpos=0

showpart () {
	echo "Part $1 score: $part/$partpos"
	echo
	total=`expr $total + $part`
	totalpos=`expr $totalpos + $partpos`
	part=0
	partpos=0
}

showfinal () {
	total=`expr $total + $part`
	totalpos=`expr $totalpos + $partpos`
	echo "Score: $total/$totalpos"
	if [ $total -lt $totalpos ]; then
		exit 1
	fi
}

passfailmsg () {
	msg="$1"
	shift
	if [ $# -gt 0 ]; then
		msg="$msg,"
	fi

	t1=`date +%s.%N 2>/dev/null`
	time=`echo "scale=1; ($t1-$t0)/1" | sed 's/.N/.0/g' | bc 2>/dev/null`

	echo $msg "$@" "(${time}s)"
}

pass () {
	passfailmsg OK "$@"
	part=`expr $part + $pts`
	partpos=`expr $partpos + $pts`
}

fail () {
	passfailmsg WRONG "$@"
	partpos=`expr $partpos + $pts`
	if $verbose; then
		exit 1
	fi
}

