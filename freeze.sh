#! /bin/bash

# Sourceforge username
SFUSER=${SFUSER:-$USER}

set -ex

usage() {
    if ! [ -z "$1" ]
    then
        echo $1
    fi
    cat <<EOF

usage: $0 VERSION

  This script performs a number of sanity checks on the current repository, and creates
  a lightweight tag for the revision in \$PWD/release.cl (or does it?).

  ENVIRONMENT:

  SFUSER: Sourceforge username. Defaults to \$USER
  CL_RELEASE_DIR: Absolute path to directory containing all the build
    artifacts. If not defined, a new build directory is created in \$PWD.
  CCL: Path to Clozure Common Lisp, suitable as an argument to make.sh
  CLISP: Path to CLISP, suitable as an argument to make.sh
EOF
    exit 1
}

if [ -z "$1" ]
then
    usage "No version number."
else
    VERSION="$1-rc"; shift
    echo $VERSION | perl -pe 'die "Invalid version number: $_\n" if !/^\d+\.\d+\.\d+-rc$/'
fi

if ! [ -z "$@" ]
then
    usage "Extra command-line arguments: $@"
fi

if [ -z "$CLISP" ]
then
    usage "CLISP environment variable not set"
fi

CL_RELEASE_DIR=${CL_RELEASE_DIR:-$(mktemp -d $PWD/cl-release-dir-$(date +%Y%m%d)-XXXXXXXXX)}
CL_DIR=$CL_RELEASE_DIR/cl-$VERSION
GIT_DIR=$PWD/release.cl
LOGFILE=$CL_RELEASE_DIR/log.txt

if [ ! -d $CL_DIR ]; then
    cl_directory="$(cd "$(dirname $0)"; pwd)"
    cd $GIT_DIR

    echo "Checking that the tree is clean."
    if ! [ $(git status --porcelain | wc -l) = 0 ]
    then
        echo "There are uncommitted / unpushed changes in this checkout!"
        git status
        exit 1
    fi

    ## Make draft release notes

    if [ ! -f $CL_RELEASE_DIR/cl-$VERSION-release-notes.txt ]; then
        awk "BEGIN { state = 0 }
     /^changes relative to cl-/ { state = 1 }
     /^changes in cl-/ { state = 0 }
     { if(state == 1) print \$0 }" < $GIT_DIR/NEWS > $CL_RELEASE_DIR/cl-$VERSION-release-notes.txt
    fi

    ## Tag

    # I'd like to use the same tag each time, but I can't convince
    # myself that that will do the right thing when pushed, and I don't
    # want to break all our mirrors for this.

    # echo "Tagging as release_candidate"
    # git tag release_candidate

    git clone $GIT_DIR $CL_DIR
fi

# check self-build (without float oracle)

## Build x86-64 binary for bootstrap.

if [ ! -d $CL_RELEASE_DIR/bin ]; then
    echo "Building bootstrap x86-64 binary"
    cd $CL_DIR
    nice -20 ./make.sh >$LOGFILE 2>&1

    cd tests
    nice -20 sh ./run-tests.sh >>$LOGFILE 2>&1
    mkdir -p $CL_RELEASE_DIR/bin
    cp $CL_DIR/src/runtime/cl $CL_RELEASE_DIR/bin/cl
    cp $CL_DIR/output/cl.core $CL_RELEASE_DIR/bin/cl.core
fi

## Build x86-64 release candidate binary.

if [ ! -d $CL_RELEASE_DIR/cl-$VERSION-x86-64-linux ]; then
    echo "Building release candidate x86-64 binary"
    cd $CL_DIR
    sh clean.sh
    nice -20 ./make.sh "$CL_RELEASE_DIR/bin/cl --core $CL_RELEASE_DIR/bin/cl.core --no-userinit" >> $LOGFILE 2>&1
    cd doc && sh ./make-doc.sh
    cd $CL_RELEASE_DIR

    ln -s $CL_DIR $CL_RELEASE_DIR/cl-$VERSION-x86-64-linux
    sh $CL_DIR/binary-distribution.sh cl-$VERSION-x86-64-linux
    bzip2 cl-$VERSION-x86-64-linux-binary.tar
    sh $CL_DIR/html-distribution.sh cl-$VERSION
    bzip2 cl-$VERSION-documentation-html.tar

    mv $CL_DIR/obj/from-xc obj_from-xc_cl
fi

# check build from ccl

if [ -n "$CCL" ]; then
    if [ ! -d $CL_RELEASE_DIR/obj_from-xc_ccl ]; then
        cd $CL_DIR
        sh clean.sh
        nice -20 ./make.sh "$CCL" >> $LOGFILE 2>&1
        cd $CL_RELEASE_DIR

        mv $CL_DIR/obj/from-xc obj_from-xc_ccl
    fi
fi

if [ ! -d $CL_RELEASE_DIR/obj_from-xc_clisp ]; then
   cd $CL_DIR
   sh clean.sh
   nice -20 ./make.sh "$CLISP" >> $LOGFILE 2>&1
   cd $CL_RELEASE_DIR

   mv $CL_DIR/obj/from-xc obj_from-xc_clisp
fi

# TODO: check binary-equality between ccl, clisp, cl objs

# TODO: check build from abcl, ecl

# upload rc build

if [ ! -f $CL_RELEASE_DIR/uploaded ]; then

  read -n 1 -p "Ok to upload? " A; echo
  if [ $A \!= "y" ]; then
    exit 1
  fi

  cd $CL_RELEASE_DIR
cat > $CL_RELEASE_DIR/sftp-batch <<EOF
cd /home/frs/project/s/sb/cl/cl-rc
put cl-$VERSION-x86-64-linux-binary.tar.bz2
put cl-$VERSION-documentation-html.tar.bz2
put cl-$VERSION-release-notes.txt
EOF
  sftp -b $CL_RELEASE_DIR/sftp-batch $SFUSER,sbcl@frs.sourceforge.net
  touch uploaded
fi

# TODO: check self-crossbuild on x86, arm, ppc


# TODO: find Fix Committed lp bugs for NEWS frobbery
