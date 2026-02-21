#!/bin/bash

# Sourceforge username
SFUSER=${SFUSER:-$USER}

set -ex

## Parse command line arguments

usage () {
    if ! [ -z "$1" ]
    then
        echo $1
    fi
    cat <<EOF

usage: $0 [-s] VERSION-NUMBER [REV]

  This script frobs NEWS, makes a "release" commit + tag of the
  repository in \$PWD/release.sbcl .

  It then clones the repository to a new clean directory and does the
  following:
  - Builds source tarball
  - Builds a SBCL for self-build
  - Builds x86-64 binaries
  - Uploads binaries
  - Pushes the repository
  - Builds and uploads the documentation

  If -s is given, then use the gpg-sign mechanism of "git tag". You
  will need to have your gpg secret key handy.

  if REV is given, it is the git revision to build into a release.
  Default is origin/master.

  ENVIRONMENT:

  SFUSER: Sourceforge username. Defaults to \$USER
  CL_RELEASE_DIR: Absolute path to directory containing all the build
    artifacts. If not defined, a new build directory is created in \$PWD.

EOF
    exit 1
}

if [ "-s" = "$1" ] || [ "--sign" = "$1" ]
then
    sign="-s"; shift
else
    sign=""
fi

## Verify version number

if [ -z "$1" ]
then
    usage "No version number."
else
    VERSION=$1; shift
    echo $VERSION | perl -pe 'die "Invalid version number: $_\n" if !/^\d+\.\d+\.\d+$/'
fi

YEAR=$(date +%y)
MONTH=$(date +%-m)

if [ "$MONTH" = "12" ]
then
    MONTH=0
    YEAR=$((YEAR+1))
fi

EXPECTED_VERSION="${YEAR:0:1}.${YEAR:1:1}.${MONTH}"

if [ "$VERSION" \!= "$EXPECTED_VERSION" ]
then
    echo "Expected version '$EXPECTED_VERSION', got '$VERSION'"
    read -n 1 -p "Continue anyway? " A; echo
    if [ "$A" \!= "y" ]
    then
       exit 1
    fi
fi

if [ -z "$1" ]
then
    rev=origin/master
else
    rev=$1; shift
    type=$(git cat-file -t "$rev" 2> /dev/null || echo "unknown")
    if ([ "tag" != "$type" ] && [ "commit" != "$type" ])
    then
        usage "$rev is $type, not a tag or a commit."
    fi
fi

if ! [ -z "$@" ]
then
    usage "Extra command-line arguments: $@"
fi

CL_RELEASE_DIR=${CL_RELEASE_DIR:-$(mktemp -d $PWD/sbcl-release-dir-$(date +%Y%m%d)-XXXXXXXXX)}
CL_DIR=$CL_RELEASE_DIR/sbcl-$VERSION
GIT_DIR=$PWD/release.sbcl
LOGFILE=$CL_RELEASE_DIR/log.txt

## Frob the git repository, and clone the repo to a clean build directory.

if [ ! -d $CL_DIR ]; then
  cd $GIT_DIR

  sbcl_directory="$(cd "$(dirname $0)"; pwd)"

  branch_name="release-$(date '+%s')"
  original_branch="$(git describe --all --contains HEAD)"

  echo "Checking that the tree is clean."
  if ! [ $(git status --porcelain | wc -l) = 0 ]
  then
      echo "There are uncommitted / unpushed changes in this checkout!"
      git status
      exit 1
  fi

  ## Perform the necessary changes to the NEWS file:

  echo "Munging NEWS"
  sed -i.orig "/^changes relative to sbcl-.*:/ s/changes/changes in sbcl-$VERSION/ " NEWS
  rm -f NEWS.orig
  if ! grep "^changes in sbcl-$VERSION relative to" NEWS > /dev/null
  then
      echo "NEWS munging failed!"
      exit 1
  fi

  ## Commit

  cd "$sbcl_directory"

  echo "Committing release version."
  git add NEWS
  git commit -m "$VERSION: will be tagged as \"sbcl-$VERSION\""

  ## Make release notes

  if [ ! -f $CL_RELEASE_DIR/sbcl-$VERSION-release-notes.txt ]; then
    awk "BEGIN { state = 0 }
     /^changes in sbcl-/ { state = 0 } 
     /^changes in sbcl-$VERSION/ { state = 1 }
     { if(state == 1) print \$0 }" < $GIT_DIR/NEWS > $CL_RELEASE_DIR/sbcl-$VERSION-release-notes.txt
  fi

  ## Tag

  tag="sbcl-$VERSION"
  echo "Tagging as $tag"
  git tag $sign -F $CL_RELEASE_DIR/sbcl-$VERSION-release-notes.txt "$tag"

  git clone $GIT_DIR $CL_DIR
fi

## Make the source tarball.

if [ ! \( -f $CL_RELEASE_DIR/sbcl-$VERSION-source.tar -o -f $CL_RELEASE_DIR/sbcl-$VERSION-source.tar.bz2 \) ]; then
  cd $CL_DIR
  $CL_DIR/generate-version.sh
  mkdir -p CVS
  sh ./distclean.sh
  rm -rf .git

  cd $CL_RELEASE_DIR
  sh sbcl-$VERSION/source-distribution.sh sbcl-$VERSION

  mv $CL_DIR $CL_DIR.git

  tar xvf sbcl-$VERSION-source.tar
fi

## Build x86-64 binary for bootstrap.

if [ ! -d $CL_RELEASE_DIR/bin ]; then
  cd $CL_DIR
  nice -20 ./make.sh >$LOGFILE 2>&1

  cd tests
  nice -20 sh ./run-tests.sh >>$LOGFILE 2>&1
  mkdir -p $CL_RELEASE_DIR/bin
  cp $CL_DIR/src/runtime/cl $CL_RELEASE_DIR/bin/cl
  cp $CL_DIR/output/cl.core $CL_RELEASE_DIR/bin/cl.core
fi

## Build x86-64 release binary.

if [ ! -d $CL_RELEASE_DIR/cl-$VERSION-x86-64-linux ]; then
  cd $CL_DIR
  sh clean.sh
  nice -20 ./make.sh "$CL_RELEASE_DIR/bin/cl --core $CL_RELEASE_DIR/bin/cl.core --no-userinit" >> $LOGFILE 2>&1
  cd doc && sh ./make-doc.sh
  cd $CL_RELEASE_DIR

  ln -s $CL_DIR $CL_RELEASE_DIR/cl-$VERSION-x86-64-linux
  sh $CL_DIR/binary-distribution.sh cl-$VERSION-x86-64-linux
  sh $CL_DIR/html-distribution.sh cl-$VERSION
fi

## Build x86 release binary.

#if [ ! -d $CL_RELEASE_DIR/cl-$VERSION-x86-linux ]; then
#  cd $CL_DIR
#  sh clean.sh
#  export CL_ARCH=x86
#  export PATH=/scratch/src/release/x86-gcc-wrapper:$PATH
#  nice -20 ./make.sh "$CL_RELEASE_DIR/bin/cl --core $CL_RELEASE_DIR/bin/s#bcl.core --no-userinit" >> $LOGFILE 2>&1
#  cd tests
#  nice -20 sh ./run-tests.sh >>$LOGFILE 2>&

#  cd $CL_RELEASE_DIR
#  ln -s $CL_DIR $CL_RELEASE_DIR/cl-$VERSION-x86-linux
#  sh $CL_DIR/binary-distribution.sh cl-$VERSION-x86-linux
#fi

## Checksum

if [ ! -f $CL_RELEASE_DIR/cl-$VERSION-$SFUSER ]; then
  cd $CL_RELEASE_DIR
  echo "The SHA256 checksums of the following distribution files are:" > cl-$VERSION-$SFUSER
  echo >> cl-$VERSION-$SFUSER
  sha256sum cl-$VERSION*.tar >> cl-$VERSION-$SFUSER
  bzip2 cl-$VERSION*.tar
fi

## Bug closing email

if [ ! -f $CL_RELEASE_DIR/cl-$VERSION-bugmail.txt ]; then
  cd $CL_RELEASE_DIR
  echo Bugs fixed by cl-$VERSION release > cl-$VERSION-bugmail.txt
 for bugnum in $(egrep -o "#[1-9][0-9][0-9][0-9][0-9][0-9]+" cl-$VERSION-release-notes.txt | sed s/#// | sort -n); do 
    printf "\n bug %s\n status fixreleased" $bugnum >> cl-$VERSION-bugmail.txt
  done
  echo >> cl-$VERSION-bugmail.txt
fi

## Sign

if [ ! -f $CL_RELEASE_DIR/cl-$VERSION-$SFUSER.asc ]; then
  cd $CL_RELEASE_DIR
  gpg -sta $CL_RELEASE_DIR/cl-$VERSION-$SFUSER
fi

## Upload to sf.net

if [ ! -f $CL_RELEASE_DIR/uploaded ]; then

  read -n 1 -p "Ok to upload? " A; echo  
  if [ $A \!= "y" ]; then
    exit 1
  fi

  cd $CL_RELEASE_DIR
cat > $CL_RELEASE_DIR/sftp-batch <<EOF
cd /tmp/cl
mkdir $VERSION
chmod 775 $VERSION
cd $VERSION
put cl-$VERSION-$SFUSER.asc
put cl-$VERSION-x86-64-linux-binary.tar.bz2
put cl-$VERSION-source.tar.bz2
put cl-$VERSION-documentation-html.tar.bz2
put cl-$VERSION-release-notes.txt
put cl-$VERSION-release-notes.txt README
EOF
  sftp -b $CL_RELEASE_DIR/sftp-batch $SFUSER,sbcl@frs.sourceforge.net 
  touch uploaded
fi

## Push

if [ ! -f $CL_RELEASE_DIR/cl-git-pushed ]; then
  cd $GIT_DIR
  git diff origin || true
  
  read -n 1 -p "Ok? " A; echo  

  if [ $A = "y" ]; then
    git push
    git push --tags
    touch $CL_RELEASE_DIR/cl-git-pushed
  else
    exit 1
  fi
fi

set +x

echo TODO:
echo 
echo perform administrative tasks:
echo 
echo \* visit https://sourceforge.net/projects/sbcl/files/
echo \* select sbcl -> $VERSION -> "view details" for the source
echo \ \ tarball, "Select all" and Save
echo \* mail sbcl-announce
echo \* check and send sbcl-$VERSION-bugmail.txt to edit@bugs.launchpad.net
echo \ \ '(sign: C-c RET s p)'
