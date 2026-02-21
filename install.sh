#!/bin/sh
set -e

# Install CL files into the usual places.

umask 022

bad_option() {
    echo $1
    echo "Enter \"$0 --help\" for list of valid options."
    exit 1
}

for option
do
  optarg_ok=true
  # Split --foo=bar into --foo and bar.
  case $option in
      *=*)
        # For ease of scripting skip valued options with empty
        # values.
        optarg=`expr "X$option" : '[^=]*=\(.*\)'` || optarg_ok=false
        option=`expr "X$option" : 'X\([^=]*=\).*'`
        ;;
      *)
        optarg=""
        ;;
  esac

  case $option in
      --prefix=)
      $optarg_ok || bad_option "Bad argument for --prefix="
      INSTALL_ROOT=$optarg
      ;;
      --help | -help | -h)
  cat <<EOF
 --prefix=<path>      Specify the install location.

See ./INSTALL for more information
EOF
          exit 0
        ;;
      *)
            bad_option "Unknown command-line option to $0: \"$option\""
        ;;
  esac

done

ensure_dirs ()
{
    for j in "$@"; do
         test -d "$j" || mkdir -p "$j"
    done;
}

RUNTIME=cl
OLD_RUNTIME=cl.old

# Before doing anything else, make sure we have an CL to install
#if [ -f src/runtime/$RUNTIME ]; then
if [ -f output/cl.core ]; then
  true
else
  echo "output/cl.core not found, aborting installation."
  echo 'See ./INSTALL, the "SOURCE DISTRIBUTION" section'
  exit 1
fi
# else
#     echo "src/runtime/$RUNTIME not found, aborting installation."
#     echo 'See ./INSTALL, the "SOURCE DISTRIBUTION" section'
#     exit 1
# fi

. output/prefix.def
DEFAULT_INSTALL_ROOT=$CL_PREFIX

INSTALL_ROOT=${INSTALL_ROOT:-$DEFAULT_INSTALL_ROOT}
# MAN_DIR=${MAN_DIR:-"$INSTALL_ROOT"/share/man}
# INFO_DIR=${INFO_DIR:-"$INSTALL_ROOT"/share/info}
# DOC_DIR=${DOC_DIR:-"$INSTALL_ROOT"/share/doc/cl}
echo $INSTALL_ROOT
# Does the environment look sane?
if [ -n "$CL_HOME" -a "$INSTALL_ROOT/lib/cl" != "$CL_HOME" ];then
   echo CL_HOME environment variable is set, and conflicts with INSTALL_ROOT.
   echo Aborting installation.  Unset one or reset the other, then try again
   echo INSTALL_ROOT="$INSTALL_ROOT"
   echo CL_HOME="$CL_HOME"
   exit 1
fi

CL_HOME="$INSTALL_ROOT"/lib/cl
export CL_HOME INSTALL_ROOT
ensure_dirs "$BUILD_ROOT$INSTALL_ROOT" "$BUILD_ROOT$INSTALL_ROOT"/bin \
    "$BUILD_ROOT$INSTALL_ROOT"/lib "$BUILD_ROOT$CL_HOME"
    # "$BUILD_ROOT$MAN_DIR" "$BUILD_ROOT$MAN_DIR"/man1 \
    # "$BUILD_ROOT$INFO_DIR" "$BUILD_ROOT$DOC_DIR" \
    # "$BUILD_ROOT$DOC_DIR"/html \
    

# move old versions out of the way.  Safer than copying: don't want to
# break any running instances that have these files mapped
test -f "$BUILD_ROOT$INSTALL_ROOT"/bin/$RUNTIME && \
 mv "$BUILD_ROOT$INSTALL_ROOT"/bin/$RUNTIME \
    "$BUILD_ROOT$INSTALL_ROOT"/bin/$OLD_RUNTIME
test -f "$BUILD_ROOT$CL_HOME"/cl.core && \
    mv "$BUILD_ROOT$CL_HOME"/cl.core "$BUILD_ROOT$CL_HOME"/cl.core.old

# cp src/runtime/$RUNTIME "$BUILD_ROOT$INSTALL_ROOT"/bin/
cp src/runtime/cl "$BUILD_ROOT$INSTALL_ROOT"/bin/cl
cp output/cl.core "$BUILD_ROOT$CL_HOME"/cl.core
test -f src/runtime/libcl.so && \
    cp src/runtime/libcl.so "$BUILD_ROOT$INSTALL_ROOT"/lib/

cp src/runtime/cl.mk "$BUILD_ROOT$CL_HOME"/cl.mk
for i in $(grep '^LIBCL=' src/runtime/cl.mk | cut -d= -f2-) ; do
    cp "src/runtime/$i" "$BUILD_ROOT$CL_HOME/$i"
done

# installing contrib
ensure_dirs "$BUILD_ROOT$CL_HOME/contrib/"
cp obj/cl-home/contrib/* "$BUILD_ROOT$CL_HOME/contrib/"

echo
echo "CL has been installed:"
echo " binary $BUILD_ROOT$INSTALL_ROOT/bin/$RUNTIME"
echo " core and contribs in $BUILD_ROOT$INSTALL_ROOT/lib/cl/"

# Installing manual & misc bits of documentation
#
# Locations based on FHS 2.3.
# See: <http://www.pathname.com/fhs/pub/fhs-2.3.html>
#
# share/       architecture independent read-only things
# share/man/   manpages, should be the same as man/
# share/info/  info files
# share/doc/   misc documentation
