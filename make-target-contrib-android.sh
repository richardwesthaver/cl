#!/bin/sh
set -e

export CL_TOP="../.."
export CL_HOME="$CL_TOP/obj/cl-home"
export CL="$CL_TOP/src/runtime/cl --noinform --core $CL_TOP/output/cl.core \
    --lose-on-corruption --disable-debugger --no-sysinit --no-userinit"
export UNAME=Linux
export DEST=$CL_TOP/obj/cl-home/contrib

build_asdf () {
    export ASDF_FASL=$DEST/asdf.fasl
    export UIOP_FASL=$DEST/uiop.fasl
    FROB_READTABLE="(setf (sb-ext:readtable-base-char-preference *readtable*) :both)"
    export FASL="$ASDF_FASL $UIOP_FASL"

    cd contrib/asdf
    mkdir -p $DEST

    $CL --eval "$FROB_READTABLE" \
          --eval "(compile-file #p\"SYS:CONTRIB;ASDF;UIOP.LISP\" \
                    :print nil :output-file (merge-pathnames (parse-native-namestring \"$UIOP_FASL\")))" </dev/null
    $CL --eval "$FROB_READTABLE" \
          --eval "(compile-file #p\"SYS:CONTRIB;ASDF;ASDF.LISP\" \
                    :print nil :output-file (merge-pathnames (parse-native-namestring \"$ASDF_FASL\")))" </dev/null
    # if [ -d asdf-upstream ] ; then rm -rf asdf-upstream ; fi FIXME

    cd $CL_TOP
}

build_system () {
    SYSTEM="$1"
    MODULE_REQUIRES="$2 $3"

    export FASL=$DEST/$SYSTEM.fasl
    export ASD=$DEST/$SYSTEM.asd

    cd contrib/$SYSTEM
    $CL --load ../make-contrib.lisp "$SYSTEM" $MODULE_REQUIRES </dev/null

    cd $CL_TOP
}

build_asdf

build_system sb-posix
build_system sb-bsd-sockets

build_system sb-introspect
build_system sb-cltl2
build_system sb-aclrepl
build_system sb-sprof
if [ -f android-libs/libcapstone.so ]; then
    build_system sb-capstone
fi
build_system sb-rotate-byte
build_system sb-md5 sb-rotate-byte
build_system sb-executable
if [ -f android-libs/libgmp.so ]; then
    build_system sb-gmp
    if [ -f android-libs/libmpfr.so ]; then
        build_system sb-mpfr sb-gmp
    fi
fi
build_system sb-concurrency
build_system sb-queue sb-concurrency
build_system sb-rt
build_system sb-simple-streams sb-posix sb-bsd-sockets
build_system sb-cover sb-md5
# build_system sb-simd
build_system sb-grovel asdf
