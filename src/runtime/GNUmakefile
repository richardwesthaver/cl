# -*- makefile -*- for the C-level run-time support for CL

# This software is part of the CL system. See the README file for
# more information.
#
# This software is derived from the CMU CL system, which was
# written at Carnegie Mellon University and released into the
# public domain. The software is in the public domain and is
# provided with absolutely no warranty. See the COPYING and CREDITS
# files for more information.

.PHONY: all clean TAGS tags targets

all: targets tags
TARGET=cl

# Allow using paxctl(8) or similar programs to adjust PaX permissions
# of src/runtime/cl during the build.
CL_PAXCTL ?= :

# Defaults which might be overridden or modified by values in the
# Config file. Most of them are same on most systems right now.
# If you need to override one of these, do it in Config.
LINKFLAGS += -g
DEPEND_FLAGS = -MM
GREP = grep
LD = ld

# By default, don't make and use a library, just use the object files.
LIBCL = $(OBJS)
USE_LIBCL = $(OBJS)
__LDFLAGS__ =

include ../../output/prefix.def

CFLAGS += -g -Wall -Wundef -Wsign-compare -Wpointer-arith -O3
ASFLAGS += $(CFLAGS)
CPPFLAGS += -I.

# Give make access to the target Lisp features.
include genesis/Makefile.features

# The Config file is the preferred place for tweaking options which
# are appropriate for particular setups (OS, ARCH, whatever). Make a
# Config-foo file for setup foo, then arrange for Config to be a
# symlink to Config-foo.
# Commonly used variables in Config are: ARCH_SRC, ASSEM_SRC, GC_SRC,
# OS_SRC, OS_LIBS
DISABLE_PIE=yes
include Config

# Disable PIE by default.
# We mostly do not care any more where the C code is located, and would
# prefer that C toolchain default be used, however, the limited address
# space in 32-bit architectures make it tricky to permit the .text segment
# to be placed arbitrarily if there is any risk of not being able to
# allocate the lisp readonly and static spaces on account of collision.
ifeq ($(DISABLE_PIE),yes)
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]no-pie'),)
CFLAGS += -fno-pie
LINKFLAGS += -no-pie
LDFLAGS += -no-pie
__LDFLAGS__ += -no-pie
endif
ifneq ($(shell $(CC) -dumpspecs 2>/dev/null | grep -e '[^f]nopie'),)
CFLAGS += -fno-pie
LINKFLAGS += -nopie
LDFLAGS += -nopie
__LDFLAGS__ += -nopie
endif
endif

COMMON_SRC = alloc.c arena.c backtrace.c breakpoint.c coalesce.c	\
	coreparse.c dynbind.c funcall.c gc-common.c globals.c		\
	hopscotch.c interr.c interrupt.c largefile.c main.c		\
	math.c monitor.c murmur_hash.c os-common.c parse.c              \
	perfecthash.c print.c time.c                                    \
	regnames.c runtime.c safepoint.c save.c                         \
	sc-offset.c search.c stringspace.c thread.c stop-the-world.c    \
	validate.c var-io.c vars.c wrap.c

ifndef LISP_FEATURE_WIN32
COMMON_SRC += run-program.c sprof.c
endif

C_SRC = $(COMMON_SRC) ${ARCH_SRC} ${OS_SRC} ${GC_SRC}

SRCS = $(C_SRC) ${ASSEM_SRC}

OBJS = $(C_SRC:.c=.o) $(ASSEM_SRC:.S=.o) ../../tlsf-bsd/tlsf/tlsf.o

LIBS = ${OS_LIBS} $(LDLIBS) -lm

ifdef LISP_FEATURE_SB_SAFEPOINT
LDB_TARGET =
else
LDB_TARGET = ldb
endif

targets: $(TARGET) $(OBJTARGET) $(LDB_TARGET) sbcl.mk

LDB_OBJS = $(filter-out main.o interr.o runtime.o monitor.o thread.o stop-the-world.o safepoint.o,$(OBJS))
ldb: $(LIBCL)
	$(CC) -g $(CPPFLAGS) $(CFLAGS) -DSTANDALONE_LDB -c -o standalone-monitor.o monitor.c
	$(CC) -g $(CPPFLAGS) $(CFLAGS) -DSTANDALONE_LDB -c -o standalone-interr.o interr.c
	$(CC) $(LINKFLAGS) -o ldb standalone-monitor.o standalone-interr.o \
		$(LDB_OBJS) $(LIBS)

$(TARGET): $(LIBCL)
	$(CC) ${LINKFLAGS} -o $@ $(USE_LIBCL) $(LIBS)
	$(CL_PAXCTL) $@

# tests/heap-reloc/fake-mman.c assumes #+linux, so this recipe
# only works on linux.
heap-reloc-test: ../../tests/heap-reloc/fake-mman.c $(OBJS)
	$(CC) ${LINKFLAGS} -o $@ ../../tests/heap-reloc/fake-mman.c $(filter-out linux-mman.o,$(OBJS)) $(LIBS)

# Enable compiling gencgc with even more assertions and/or
# data collection, with COMPILING_TESTS. Not really used yet.
gc-unit-tests.o: CFLAGS=-g -DCOMPILING_TESTS
unit-tests: gc-unit-tests.o libcl.a
	$(CC) -g -no-pie -o $@ $^ -ldl -lpthread -lm

# ld -r -o cl.o works on Linux, but not on other platforms.
# On macOS, it fails to keep debug sections.
# On mingw64, it leads to an executable that cannot be executed.
cl.o: $(OBJS)
	$(LD) $(__LDFLAGS__) -r -o $@ $^

libcl.a: $(OBJS)
	rm -f $@ ; ar rcs $@ $^

PIC_OBJS = $(subst .o,.pic.o,$(OBJS))
libcl.so: $(PIC_OBJS)
	$(CC) -shared -o $@ $^ $(LIBS) $(SOFLAGS)
# for this to work, you must have with-gcc-tls in your build features already.
# can't define it here because then it conflicts if you have it in both places.
%.pic.o: %.c
	$(CC) -fPIC -c $(CPPFLAGS) $(filter-out -fno-pie,$(CFLAGS)) $< -o $@
%.pic.o: %.S # (-fPIC doesn't affect hand-written assembly source)
	$(CC) -c $(CPPFLAGS) $(CFLAGS) $< -o $@ -DLIBCL

SHRINKWRAP_DEPS = ../../output/cl.core ../../tools-for-build/elftool.lisp
shrinkwrap-cl.s shrinkwrap-cl-core.o: $(SHRINKWRAP_DEPS)
	../../run-sbcl.sh --script ../../tools-for-build/elftool.lisp split \
	--dynamic-space-size 256 ../../output/cl.core shrinkwrap-cl.s
pie-shrinkwrap-cl.s pie-shrinkwrap-cl-core.o: $(SHRINKWRAP_DEPS)
	../../run-sbcl.sh --script ../../tools-for-build/elftool.lisp split --pie \
		../../output/cl.core pie-shrinkwrap-cl.s
# "Commas ... cannot appear in the text of an argument as written"
# There can not be any space after the comma on the next line,
# or else it becomes part of the expansion of $(comma)
comma := ,
shrinkwrap-cl: shrinkwrap-cl.s shrinkwrap-cl-core.o $(LIBCL)
	$(CC) -no-pie $(filter-out -Wl$(comma)--export-dynamic, $(LINKFLAGS)) \
 $(CFLAGS) -o $@ $^ $(filter-out -ldl, $(LIBS))
pie-shrinkwrap-cl: pie-shrinkwrap-cl.s pie-shrinkwrap-cl-core.o $(PIC_OBJS)
	$(CC) -pie -o $@ $^ $(LIBS)
semiwrap-cl: shrinkwrap-cl.s $(LIBCL)
	$(CC) $(LINKFLAGS) $(CFLAGS) -o $@ $^ $(LIBS)

# simpler version of core embedding where the core is just a section of the ELF file.
# tools-for-build/elftool could kinda do this but it didn't work as well as it
# does using the ELF writer from C, because firstly the interface is less
# polished and secondly it did not remove the need for -Wl,--export-dynamic.
# Note about $(LIBS) - we don't really need -ldl except os-common does reference it
# so removing it would break that. Also certain platforms need -lm and -lpthread
# to get in there so using the same link options as for the ordinary "cl"
# is just easiest.
embedcore-cl: $(LIBCL)
	../../run-sbcl.sh --eval '(save-lisp-and-die "wrappedcore.o" :executable :elf-object)'
	$(CC) -no-pie $(filter-out -Wl$(comma)--export-dynamic, $(LINKFLAGS)) \
 $(CFLAGS) -o $@ wrappedcore.o $^ $(LIBS)

sbcl.mk: Config
	( echo 'CC=$(CC)' ; \
	  echo 'LD=$(LD)' ; \
	  echo 'CFLAGS=$(CFLAGS)' ; \
	  echo 'ASFLAGS=$(ASFLAGS)' ; \
	  echo 'LINKFLAGS=$(LINKFLAGS)' ; \
	  echo 'LDFLAGS=$(LDFLAGS)' ; \
	  echo '__LDFLAGS__=$(__LDFLAGS__)' ; \
	  echo 'LIBS=$(LIBS)' ; \
	  if [ -n '$(LISP_FEATURE_SB_LINKABLE_RUNTIME)' ] ; then \
	    echo 'LIBCL=$(LIBCL)' ; \
	    echo 'USE_LIBCL=$(USE_LIBCL)' ; \
	  fi ; \
	  : ) > $@

# || true because we don't want the build to break if etags isn't there.
# ...but it's still nice to have it done by default.
HEADERS=$(wildcard *.h genesis/*.h)
INC=$(wildcard *.inc)
TAGS tags: $(SRCS) $(HEADERS) $(INC)
	@etags --language=c $(SRCS) $(HEADERS) $(INC) || true

clean:
	-rm -f *.[do] ../../tlsf-bsd/tlsf/tlsf.o $(TARGET) *.tmp libcl.a \
 ldb unit-tests libcl.a shrinkwrap-cl* sbcl.mk core

%.d: %.c
	@$(CC) $(DEPEND_FLAGS) $(CPPFLAGS) $< > $@.tmp; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.tmp > $@; \
	rm -f $@.tmp

%.d: %.S
	@$(CC) $(DEPEND_FLAGS) $(CPPFLAGS) $< > $@.tmp; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.tmp > $@; \
	rm -f $@.tmp

# By including those files, we cause GNU make to automatically re-make
# all dependencies of the .c file if necessary.
ifneq ($(MAKECMDGOALS),clean)
-include $(C_SRC:.c=.d) $(ASSEM_SRC:.S=.d)
endif
