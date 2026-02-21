#!/bin/sh

logdir=${CL_PAREXEC_TMP:-$HOME}/cl-test-logs-$$
echo ==== Writing logs to $logdir ====
# FIXME: junkdir isn't getting removed
junkdir=${CL_PAREXEC_TMP:-/tmp}/junk
mkdir -p $junkdir $logdir

case `uname` in
    CYGWIN* | WindowsNT | MINGW* | MSYS*)
        if [ $# -ne 1 ]
        then
            echo $0: Need arg
            exit 1
        fi
        echo ";; Using -j$1"
        echo "LOGDIR=$logdir" >$logdir/Makefile
        ../run-cl.sh --script genmakefile.lisp >>$logdir/Makefile
        exec make -k -j $1 -f $logdir/Makefile
        ;;
esac

export TEST_LOGDIR TEST_DIRECTORY CL_HOME
TEST_LOGDIR=$logdir TEST_DIRECTORY=$junkdir CL_HOME=../obj/cl-home \
  exec ../src/runtime/cl \
  --noinform --core ../output/cl.core \
  --no-userinit --no-sysinit --noprint --disable-debugger $* < parallel-exec.lisp

