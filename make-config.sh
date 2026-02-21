#!/bin/sh
set -e

# The make-config.sh script uses information about the target machine
# to set things up for compilation. It's vaguely like a stripped-down
# version of autoconf. It's intended to be run as part of make.sh. The
# only time you'd want to run it by itself is if you're trying to
# cross-compile the system or if you're doing some kind of
# troubleshooting.

# This software is part of the SBCL system. See the README file for
# more information.
#
# This software is derived from the CMU CL system, which was
# written at Carnegie Mellon University and released into the
# public domain. The software is in the public domain and is
# provided with absolutely no warranty. See the COPYING and CREDITS
# files for more information.

print_help="no"

CL_PREFIX="/usr"
CL_XC_HOST="cl --no-userinit --no-sysinit"

# Parse command-line options.
bad_option() {
  echo $1
  echo "Enter \"$0 --help\" for list of valid options."
  exit 1
}

WITH_FEATURES=""
WITHOUT_FEATURES=""
FANCY_FEATURES=":sb-core-compression :sb-xref-for-internals :sb-after-xc-core"
CONTRIBS=""
for dir in `cd contrib ; echo *`; do
  if [ -d "contrib/$dir" -a -f "contrib/$dir/Makefile" ]; then
    CONTRIBS="$CONTRIBS ${dir}"
  fi
done
CL_CONTRIB_BLOCKLIST=${CL_CONTRIB_BLOCKLIST:-""}

perform_host_lisp_check=no
fancy=false
some_options=false
android=false
if [ -z "$ANDROID_API" ]; then
  ANDROID_API=21
fi
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
    --with*)
      optarg=`expr "X$option" : 'X--[^-]*-\(.*\)'` \
        || bad_option "Malformed feature toggle: $option"
      option=`expr "X$option" : 'X\(--[^-]*\).*'`
      ;;
    *)
      optarg=""
      ;;
  esac

  case $option in
    --help | -help | -h)
      print_help="yes" ;;
    --prefix=)
    $optarg_ok && CL_PREFIX=$optarg
    ;;
    --arch=)
    $oparg_ok && CL_ARCH=$optarg
    ;;
    --xc-host=)
    $optarg_ok && CL_XC_HOST=$optarg
    ;;
    --host-location=)
    $optarg_ok && CL_HOST_LOCATION=$optarg
    ;;
    --target-location=)
    $optarg_ok && CL_TARGET_LOCATION=$optarg
    ;;
    --dynamic-space-size=)
    $optarg_ok && CL_DYNAMIC_SPACE_SIZE=$optarg
    ;;
    --with)
      WITH_FEATURES="$WITH_FEATURES :$optarg"
      if [ "$optarg" = "android" ]
      then
        android=true
      fi
      ;;
    --without)
      WITHOUT_FEATURES="$WITHOUT_FEATURES :$optarg"
      case $CONTRIBS
      in *"$optarg"*)
           CL_CONTRIB_BLOCKLIST="$CL_CONTRIB_BLOCKLIST $optarg"
      ;; esac
      ;;
    --android-api=)
    $optarg_ok && ANDROID_API=$optarg
    ;;
    --ndk=)
    $optarg_ok && NDK=$optarg
    ;;
    --fancy)
      WITH_FEATURES="$WITH_FEATURES $FANCY_FEATURES"
      # Lower down we add :sb-thread for platforms where it can be built.
      fancy=true
      ;;
    --check-host-lisp)
      perform_host_lisp_check=yes
      ;;
    -*)
      bad_option "Unknown command-line option to $0: \"$option\""
      ;;
    *)
      if $some_options
      then
        bad_option "Unknown command-line option to $0: \"$option\""
      else
        CL_XC_HOST=$option
      fi
      ;;
  esac
  some_options=true
done

if (test -f customize-target-features.lisp && \
      (test -n "$WITH_FEATURES" || test -n "$WITHOUT_FEATURES"))
then
  # Actually there's no reason why it would not work, but it would
  # be confusing to say --with-thread only to have it turned off by
  # customize-target-features.lisp...
  echo "ERROR: Both customize-target-features.lisp, and feature-options"
  echo "to make.sh present -- cannot use both at the same time."
  exit 1
fi

if test "$print_help" = "yes"
then
  cat <<EOF
\`make.sh' drives the CL build.

Usage: $0 [OPTION]...

  Important: make.sh does not currently control the entirety of the
  build: configuration file customize-target-features.lisp and certain
  environment variables play a role as well. see file INSTALL for
  details.

Options:
  -h, --help           Display this help and exit.

  --prefix=<path>      Specify the install location.

      Script install.sh installs CL under the specified prefix
      path: runtime as prefix/bin/cl, additional files under
      prefix/lib/cl, and documentation under prefix/share.

      This option also affects the binaries: built-in default for
      CL_HOME is: prefix/lib/cl/

      Default prefix is: /usr

  --dynamic-space-size=<size> Default dynamic-space size for target.

      This specifies the default dynamic-space size for the CL
      being built. If you need to control the dynamic-space size
      of the host CL, use the --xc-host option.

      If not provided, the default is platform-specific. <size> is
      taken to be megabytes unless explicitly suffixed with Gb in
      order to specify the size in gigabytes.

  --with-<feature>     Build with specified feature.
  --without-<feature>  Build wihout the specfied feature.

  --fancy              Build with several optional features:

                           $FANCY_FEATURES

                       Plus threading on platforms which support it.

  --arch=<string>      Specify the architecture to build for.

      Mainly for doing x86 builds on x86-64.

  --xc-host=<string>   Specify the Common Lisp compilation host.

      The string provided should be a command to invoke the
      cross-compilation Lisp system in such a way, that it reads
      commands from standard input, and terminates when it reaches end
      of file on standard input.

      Examples:

       "cl --disable-debugger --no-sysinit --no-userinit"
                  Use an existing CL binary as a cross-compilation
                  host even though you have stuff in your
                  initialization files which makes it behave in such a
                  non-standard way that it keeps the build from
                  working. Also disable the debugger instead of
                  waiting endlessly for a programmer to help it out
                  with input on *DEBUG-IO*. (This is the default.)

       "cl"
                  Use an existing CL binary as a cross-compilation
                  host, including your initialization files and
                  building with the debugger enabled. Not recommended
                  for casual users.

       "lisp -noinit -batch"
                  Use an existing CMU CL binary as a cross-compilation
                  host when you have weird things in your .cmucl-init
                  file.

  --host-location=<string> Location of the source directory on compilation host

      The string is passed to the command rsync to transfer the
      necessary files between the target and host directories during
      the make-target-*.sh steps of cross-compilation (cf. make.sh)

      Examples:

       user@host-machine:/home/user/cl
                  Transfer the files to/from directory /home/user/cl
                  on host-machine.

EOF
  exit 1
fi

mkdir -p output
echo "CL_TEST_HOST=\"$CL_XC_HOST\"" > output/build-config
. output/build-config # may come out differently due to escaping

if [ $perform_host_lisp_check = yes ]
then
  if echo '(lisp-implementation-type)' | $CL_TEST_HOST; then
    :
  else
    echo "No working host Common Lisp implementation."
    echo 'See ./INSTALL, the "SOURCE DISTRIBUTION" section'
    exit 1
  fi
fi

# Running make.sh with different options without clean.sh in the middle
# can break things.
sh clean.sh

# Save prefix for make and install.sh.
echo "CL_PREFIX='$CL_PREFIX'" > output/prefix.def
echo "$CL_DYNAMIC_SPACE_SIZE" > output/dynamic-space-size.txt

# FIXME: Tweak this script, and the rest of the system, to support
# a second bootstrapping pass in which the cross-compilation host is
# known to be CL itself, so that the cross-compiler can do some
# optimizations (especially specializable arrays) that it doesn't
# know how to implement how in a portable way. (Or maybe that wouldn't
# require a second pass, just testing at build-the-cross-compiler time
# whether the cross-compilation host returns suitable values from
# UPGRADED-ARRAY-ELEMENT-TYPE?)

# ./generate-version.sh

# Now that we've done our option parsing and found various
# dependencies, write them out to a file to be sourced by other
# scripts.

echo "CL_XC_HOST=\"$CL_XC_HOST\"; export CL_XC_HOST" >> output/build-config
if [ -n "$CL_HOST_LOCATION" ]; then
  echo "CL_HOST_LOCATION=\"$CL_HOST_LOCATION\"; export CL_HOST_LOCATION" >> output/build-config
fi
if [ -n "$CL_TARGET_LOCATION" ]; then
  echo "CL_TARGET_LOCATION=\"$CL_TARGET_LOCATION\"; export CL_TARGET_LOCATION" >> output/build-config
fi
echo "android=$android; export android" >> output/build-config

# And now, sorting out the per-target dependencies...

case `uname` in
  Linux)
    cl_os="linux"
    ;;
  *BSD)
    case `uname` in
      FreeBSD)
      cl_os="freebsd"
        ;;
      GNU/kFreeBSD)
        cl_os="gnu-kfreebsd"
        ;;
      OpenBSD)
        cl_os="openbsd"
        ;;
      NetBSD)
        cl_os="netbsd"
        ;;
      *)
        echo unsupported BSD variant: `uname`
        exit 1
        ;;
    esac
    ;;
  DragonFly)
    cl_os="dragonflybsd"
    ;;
  Darwin)
    cl_os="darwin"
    ;;
  SunOS)
    cl_os="sunos"
    ;;
  Haiku)
    cl_os="haiku"
    ;;
  *)
    echo unsupported OS type: `uname`
    exit 1
    ;;
esac

link_or_copy() {
  if $android ; then
    # adb push doesn't like symlinks on unrooted devices.
    cp -r "$1" "$2"
  else
    ln -s "$1" "$2"
  fi
}

remove_dir_safely() {
  if [ -h "$1" ] ; then
    rm "$1"
  elif [ -w "$1" ] ; then
    echo "I'm afraid to replace non-symlink $1 with a symlink."
    exit 1
  fi
}

echo //entering make-config.sh

echo //ensuring the existence of output/ directory
if [ ! -d output ] ; then mkdir output; fi

echo //guessing default target CPU architecture from host architecture
if $android
then
  uname_arch=`adb shell uname -m`
else
  uname_arch=`uname -m`
fi

case $uname_arch in
  *86) guessed_cl_arch=x86 ;;
  i86pc) guessed_cl_arch=x86 ;;
  *x86_64) guessed_cl_arch=x86-64 ;;
  amd64) guessed_cl_arch=x86-64 ;;
  sparc*) guessed_cl_arch=sparc ;;
  sun*) guessed_cl_arch=sparc ;;
  *powerpc|*ppc) guessed_cl_arch=ppc ;;
  ppc64) guessed_cl_arch=ppc ;;
  ppc64le) guessed_cl_arch=ppc64 ;; # is ok because there was never 32-bit LE
  Power*Macintosh) guessed_cl_arch=ppc ;;
  ibmnws) guessed_cl_arch=ppc ;;
  mips*) guessed_cl_arch=mips ;;
  arm64) guessed_cl_arch=arm64 ;;
  *arm*) guessed_cl_arch=arm ;;
  aarch64) guessed_cl_arch=arm64 ;;
  riscv32) guessed_cl_arch=riscv xlen=32;;
  riscv64) guessed_cl_arch=riscv xlen=64;;
  loongarch64) guessed_cl_arch=loongarch64;;
  *)
    # If we're not building on a supported target architecture, we
    # we have no guess, but it's not an error yet, since maybe
    # target architecture will be specified explicitly below.
    guessed_cl_arch=''
    ;;
esac

# Under Solaris, uname -m returns "i86pc" even if CPU is amd64.
if [ "$cl_os" = "sunos" ] && [ `isainfo -k` = "amd64" ]; then
  guessed_cl_arch=x86-64
fi

# Under Darwin, uname -m returns "i386" even if CPU is x86_64.
# (I suspect this is not true any more - it reports "x86_64 for me)
if [ "$cl_os" = "darwin" ] && [ "`/usr/sbin/sysctl -n hw.optional.x86_64`" = "1" ]; then
  guessed_cl_arch=x86-64
fi

# Under NetBSD, uname -m returns "evbarm" even if CPU is arm64.
if [ "$cl_os" = "netbsd" ] && [ `uname -p` = "aarch64" ]; then
  guessed_cl_arch=arm64
fi

# Under FreeBSD, uname -m returns "powerpc" even if CPU is powerpc64.
if [ "$cl_os" = "freebsd" ] && [ `uname -p` = "powerpc64" ]; then
  guessed_cl_arch=ppc64
fi

# Under FreeBSD, uname -m returns "powerpc" even if CPU is powerpc64le.
if [ "$cl_os" = "freebsd" ] && [ `uname -p` = "powerpc64le" ]; then
  guessed_cl_arch=ppc64
fi

echo //setting up CPU-architecture-dependent information
if test -n "$CL_ARCH"
then
  # Normalize it.
  CL_ARCH=`echo $CL_ARCH | tr '[A-Z]' '[a-z]' | tr _ -`
  case $CL_ARCH in
    riscv*)
      case $CL_ARCH in
        riscv32) CL_ARCH=riscv xlen=32;;
        riscv64) CL_ARCH=riscv xlen=64;;
        *)
          echo "Please choose between riscv32 and riscv64."
          exit 1
      esac
  esac
fi
cl_arch=${CL_ARCH:-$guessed_cl_arch}
echo cl_arch=\"$cl_arch\"
if [ "$cl_arch" = "" ] ; then
  echo "can't guess target CL architecture, please specify --arch=<name>"
  exit 1
fi

if $android
then
  case $cl_arch in
    arm64) TARGET_TAG=aarch64-linux-android ;;
    arm) TARGET_TAG=armv7a-linux-androideabi
         echo "Unsupported configuration"
         exit 1
         ;;
    x86) TARGET_TAG=i686-linux-android
         echo "Unsupported configuration"
         exit 1
         ;;
    x86-64) TARGET_TAG=x86_64-linux-android ;;
  esac
  HOST_TAG=$cl_os-x86_64
  TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/$HOST_TAG
  export CC=$TOOLCHAIN/bin/$TARGET_TAG$ANDROID_API-clang
  echo "CC=$CC; export CC" >> output/build-config
  echo "NDK=$NDK" > output/ndk-config
  echo "HOST_TAG=$HOST_TAG" >> output/ndk-config
  echo "TARGET_TAG=$TARGET_TAG" >> output/ndk-config
  echo "TOOLCHAIN=$TOOLCHAIN" >> output/ndk-config
  echo "ANDROID_API=$ANDROID_API" >> output/ndk-config
fi

if $fancy
then
  # If --fancy, enable threads on platforms where they can be built.
  case $cl_arch in
    x86|x86-64|ppc|arm64|riscv|loongarch64)
      if [ "$cl_os" = "dragonflybsd" ]
      then
	echo "No threads on this platform."
      else
	WITH_FEATURES="$WITH_FEATURES :sb-thread"
	echo "Enabling threads due to --fancy."
      fi
      ;;
    *)
      echo "No threads on this platform."
      ;;
  esac
else
  case $cl_arch in
    x86|x86-64)
      case $cl_os in
        linux|darwin)
          WITH_FEATURES="$WITH_FEATURES :sb-thread"
      esac
  esac
  case $cl_arch in
    arm64|riscv|loongarch64)
      WITH_FEATURES="$WITH_FEATURES :sb-thread"
  esac
fi

case "$cl_os" in
  netbsd)
    # default to using paxctl to disable mprotect restrictions
    if [ "x$(sysctl -n security.pax.mprotect.enabled 2>/dev/null)" = x1 -a \
                                                                   "x$CL_PAXCTL" = x ]; then
      echo "CL_PAXCTL=\"/usr/sbin/paxctl +m\"; export CL_PAXCTL" \
           >> output/build-config
    fi
    ;;
  openbsd)
    # openbsd 6.0 and newer restrict mmap of RWX pages
    if [ `uname -r | tr -d .` -gt 60 ]; then
      rm -f tools-for-build/mmap-rwx
      LDFLAGS="$LDFLAGS -Wl,-zwxneeded" make -C tools-for-build mmap-rwx -I ../src/runtime
      if ! ./tools-for-build/mmap-rwx; then
        echo "Can't mmap() RWX pages!"
        echo "Is the current filesystem mounted with wxallowed?"
        exit 1
      fi
    fi
    ;;
esac

ltf=`pwd`/local-target-features.lisp-expr
echo //initializing $ltf
echo ';;;; This is a machine-generated file.' > $ltf
echo ';;;; Please do not edit it by hand.' >> $ltf
echo ';;;; See make-config.sh.' >> $ltf
echo "(lambda (features) (set-difference (union features (list :${cl_arch}$WITH_FEATURES" >> $ltf

# Automatically block sb-simd on non-x86 platforms, at least for now.
case "$cl_arch" in
  x86-64) ;; *) CL_CONTRIB_BLOCKLIST="$CL_CONTRIB_BLOCKLIST sb-simd" ;;
esac
case "$cl_os" in
  linux) ;; *) CL_CONTRIB_BLOCKLIST="$CL_CONTRIB_BLOCKLIST sb-perf" ;;
esac

echo //setting up OS-dependent information

original_dir=`pwd`
cd ./src/runtime/
rm -f Config target-arch-os.h target-arch.h target-os.h target-lispregs.h
rm -f cl.mk cl.o libcl.a
# KLUDGE: these two logically belong in the previous section
# ("architecture-dependent"); it seems silly to enforce this in terms
# of the shell script, though. -- CSR, 2002-02-03
link_or_copy $cl_arch-arch.h target-arch.h
link_or_copy $cl_arch-lispregs.h target-lispregs.h
case "$cl_os" in # all but 2 unconditionally have clock-gettime
  darwin) ;;
  *) printf ' :os-provides-clock-gettime' >> $ltf ;;
esac
case "$cl_os" in
  linux)
    printf ' :unix :linux :elf' >> $ltf
    case "$cl_arch" in
      arm64 | ppc64 | x86 | x86-64)
	printf ' :gcc-tls' >> $ltf
    esac
    case "$cl_arch" in
      arm | arm64 | ppc | ppc64 | x86 | x86-64)
	printf ' :use-sys-mmap' >> $ltf
    esac

    # If you add other platforms here, don't forget to edit
    # src/runtime/Config.foo-linux too.
    case "$cl_arch" in
      mips | arm | x86 | x86-64)
	printf ' :largefile' >> $ltf
	;;
    esac
    if $android
    then
      link_or_copy Config.$cl_arch-android Config
      link_or_copy $cl_arch-android-os.h target-arch-os.h
      link_or_copy android-os.h target-os.h
    else
      link_or_copy Config.$cl_arch-linux Config
      link_or_copy $cl_arch-linux-os.h target-arch-os.h
      link_or_copy linux-os.h target-os.h
    fi
    ;;
  haiku)
    printf ' :unix :haiku :elf :int4-breakpoints' >> $ltf
    link_or_copy Config.$cl_arch-haiku Config
    link_or_copy $cl_arch-haiku-os.h target-arch-os.h
    link_or_copy haiku-os.h target-os.h
    ;;
  *bsd)
    printf ' :unix :bsd :elf' >> $ltf
    # FIXME: can we enable :gcc-tls across all variants?
    link_or_copy $cl_arch-bsd-os.h target-arch-os.h
    link_or_copy bsd-os.h target-os.h
    case "$cl_os" in
      *freebsd)
        printf ' :freebsd' >> $ltf
        printf ' :gcc-tls' >> $ltf
        if [ $cl_os = "gnu-kfreebsd" ]; then
          printf ' :gnu-kfreebsd' >> $ltf
        fi
        link_or_copy Config.$cl_arch-$cl_os Config
        ;;
      openbsd)
        printf ' :openbsd' >> $ltf
        case "$cl_arch" in
          arm64 | x86 | x86-64)
            printf ' :gcc-tls' >> $ltf
        esac
        link_or_copy Config.$cl_arch-openbsd Config
        ;;
      netbsd)
        printf ' :netbsd' >> $ltf
        link_or_copy Config.$cl_arch-netbsd Config
        ;;
      dragonflybsd)
        printf ' :dragonfly' >> $ltf
        link_or_copy Config.$cl_arch-dragonfly Config
        ;;
      *)
        echo unsupported BSD variant: `uname`
        exit 1
        ;;
    esac
    ;;
  darwin)
    printf ' :unix :bsd :darwin :mach-o' >> $ltf
    darwin_version=`uname -r`
    darwin_version_major=${DARWIN_VERSION_MAJOR:-${darwin_version%%.*}}
    if (( 10 > $darwin_version_major )) || [ $cl_arch = "ppc" ]; then
      printf ' :use-darwin-posix-semaphores' >> $ltf
    else
      printf ' :os-provides-pthread-setname-np' >> $ltf
    fi
    if (( $darwin_version_major >= 15 )); then
      printf ' :os-provides-clock-gettime' >> $ltf
    fi
    if [ $cl_arch = "x86-64" ]; then
      if (( 8 < $darwin_version_major )); then
	printf ' :inode64' >> $ltf
      fi
      printf ' :gcc-tls' >> $ltf
    fi
    if [ $cl_arch = "arm64" ]; then
      printf ' :darwin-jit :gcc-tls' >> $ltf
    fi
    if $android; then
      echo "Android build is unsupported on darwin"
    fi
    link_or_copy $cl_arch-darwin-os.h target-arch-os.h
    link_or_copy bsd-os.h target-os.h
    link_or_copy Config.$cl_arch-darwin Config
    ;;
  sunos)
    printf ' :unix :sunos :elf' >> $ltf
    link_or_copy Config.$cl_arch-sunos Config
    link_or_copy $cl_arch-sunos-os.h target-arch-os.h
    link_or_copy sunos-os.h target-os.h
    ;;
  *)
    echo unsupported OS type: `uname`
    exit 1
    ;;
esac
cd "$original_dir"

if $android
then
  . tools-for-build/android_run.sh
fi

case "$cl_arch" in
  x86)
    if [ "$cl_os" = "openbsd" ]; then
      rm -f src/runtime/openbsd-sigcontext.h
      sh tools-for-build/openbsd-sigcontext.sh > src/runtime/openbsd-sigcontext.h
    fi
    ;;
  x86-64)
    printf ' :sb-simd-pack :sb-simd-pack-256 :avx2' >> $ltf # not mandatory

    if $android; then
      make -C tools-for-build avx2 2> /dev/null
      if ! android_run tools-for-build/avx2 ; then
        CL_CONTRIB_BLOCKLIST="$CL_CONTRIB_BLOCKLIST sb-simd"
      fi
    else
      if ! make -C tools-for-build avx2 2> /dev/null || tools-for-build/avx2 ; then
        CL_CONTRIB_BLOCKLIST="$CL_CONTRIB_BLOCKLIST sb-simd"
      fi
    fi

    case "$cl_os" in
      linux | darwin | *bsd)
        printf ' :immobile-space' >> $ltf
    esac
    ;;
  ppc)
    if [ "$cl_os" = "darwin" ]; then
      # We provide a dlopen shim, so a little lie won't hurt
      printf ' :os-provides-dlopen' >> $ltf
      # The default stack ulimit under darwin is too small to run PURIFY.
      # Best we can do is complain and exit at this stage
      if [ "`ulimit -s`" = "512" ]; then
        echo "Your stack size limit is too small to build CL."
        echo "See the limit(1) or ulimit(1) commands and the README file."
        exit 1
      fi
    fi
    ;;
  ppc64)
    ;;
  riscv)
    if [ "$xlen" = "64" ]; then
      printf ' :64-bit' >> $ltf
    elif [ "$xlen" = "32" ]; then
      :
    else
      echo 'Architecture word width unspecified. (Either 32-bit or 64-bit.)'
      exit 1
    fi
    ;;
  loongarch64)
    ;;
esac

if [ "$cl_os" = darwin -a  "$cl_arch" = arm64 ]
then
  # Launching new executables is pretty slow on macOS, but this configuration is pretty uniform
  echo ' :little-endian :os-provides-dlopen :os-provides-dladdr' >> $ltf
  echo ' :os-provides-blksize-t :os-provides-suseconds-t :os-provides-posix-spawn' >> $ltf
else
  # Use a little C program to try to guess the endianness.  Ware
  # cross-compilers!
  #
  # FIXME: integrate to grovel-features, mayhaps
  if $android
  then
    $CC tools-for-build/determine-endianness.c -o tools-for-build/determine-endianness
    android_run tools-for-build/determine-endianness >> $ltf
  else
    make -C tools-for-build determine-endianness -I ../src/runtime
    tools-for-build/determine-endianness >> $ltf
  fi
  export cl_os cl_arch android
  sh tools-for-build/grovel-features.sh >> $ltf
fi


echo //finishing $ltf
printf " %s" "`cat crossbuild-runner/backends/${cl_arch}/features`" >> $ltf
echo ")) (list$WITHOUT_FEATURES)))" >> $ltf

echo "CL_CONTRIB_BLOCKLIST=\"$CL_CONTRIB_BLOCKLIST\"; export CL_CONTRIB_BLOCKLIST" >> output/build-config

# FIXME: The version system should probably be redone along these lines:
#
# echo //setting up version information.
# versionfile=version.txt
# cp base-version.txt $versionfile
# echo " (built `date -u` by `whoami`@`hostname`)" >> $versionfile
# echo 'This is a machine-generated file and should not be edited by hand.' >> $versionfile

# Make a unique ID for this build (to discourage people from
# mismatching cl and *.core files).
if [ `uname` = "SunOS" ] ; then
  # use /usr/xpg4/bin/id instead of /usr/bin/id
  PATH=/usr/xpg4/bin:$PATH
fi

if [ -n "$SOURCE_DATE_EPOCH" ]; then
  echo '"'hostname-id-"$SOURCE_DATE_EPOCH"'"' > output/build-id.inc
else
  echo '"'`hostname`-`id -un`-`date +%Y-%m-%d-%H-%M-%S`'"' > output/build-id.inc
fi

if [ -n "$CL_HOST_LOCATION" ]; then
  echo //setting up host configuration
  rsync --delete-after -a output/ "$CL_HOST_LOCATION/output/"
  rsync -a local-target-features.lisp-expr version.lisp-expr "$CL_HOST_LOCATION/"
fi
