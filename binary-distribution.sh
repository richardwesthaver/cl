#!/bin/sh
set -e

# Create a binary distribution. (make.sh should be run first to create
# the various binary files.

# (Before sbcl-0.6.10, this was run in the sbcl/ directory and created
# a tar file with no directory prefixes. Since sbcl-0.6.10, we've
# switched over to trying to do this the way everyone else does.)

b=${1:?"missing base directory name argument"}

tar -cf $b-binary.tar \
    $b/output/sbcl.core $b/src/runtime/sbcl $b/output/prefix.def \
    $b/src/runtime/sbcl.mk \
    `grep '^LIBSBCL=' $b/src/runtime/sbcl.mk | cut -d= -f2- | while read lib; do echo $b/src/runtime/$lib; done` \
    $b/install.sh $b/sbcl-pwd.sh $b/run-sbcl.sh \
    $b/pubring.pgp \
    $b/contrib/asdf-module.mk \
    $b/obj/sbcl-home
