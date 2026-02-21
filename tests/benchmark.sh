#!/bin/sh

# This is copy-and-pasted from parallel-exec, removing:
# - use of SB-APROF, SB-SPROF
# - vop usage counts, GC stop-the-world timing
# - shell tests
# - anything else extraneous to running the tests.
# Obviously it would be better if some of this
# logic could be shared, especially the
# CHOOSE-ORDER function.

if [ $# -ne 1 ]
then
    echo $0: Need arg
    exit 1
fi

logdir=${CL_PAREXEC_TMP:-$HOME}/cl-test-logs-$$
echo ==== Writing logs to $logdir ====
junkdir=${CL_PAREXEC_TMP:-/tmp}/junk
mkdir -p $junkdir $logdir

export TEST_DIRECTORY CL_HOME
TEST_DIRECTORY=$junkdir CL_HOME=../obj/cl-home exec ../src/runtime/cl \
  --noinform --core ../output/cl.core \
  --no-userinit --no-sysinit --noprint --disable-debugger $logdir $* \
  < benchmark.lisp
