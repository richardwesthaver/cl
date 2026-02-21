# We need to extend flags to the C compiler and the linker
# here. sb-posix, sb-grovel, and sb-bsd-sockets depends upon these
# being set on x86_64. Setting these in their Makefiles is not
# adequate since, while we're building contrib, they can be compiled
# directly via ASDF from a non-C-aware module which has these tricky
# ones as dependencies.

UNAME:=$(shell uname -s)
# no trailing slash on DEST. Don't want a "//" in FASL and ASD
DEST=$(CL_TOP)/obj/cl-home/contrib
FASL=$(DEST)/$(SYSTEM).fasl
ASD=$(DEST)/$(SYSTEM).asd

ifeq (SunOS,$(UNAME))
  EXTRA_CFLAGS+=-D_XOPEN_SOURCE=500 -D__EXTENSIONS__
  PATH:=/usr/xpg4/bin:${PATH}
endif
ifeq (Linux,$(UNAME))
  EXTRA_CFLAGS+=-D_GNU_SOURCE
endif

export CC CL EXTRA_CFLAGS

all: $(FASL)

# The explicit use of $wildcard is necessary here. While rules do expand
# wildcards implicitly (so that just "$(FASL): *.lisp" mostly works),
# that specification would fail on the contribs which have no .lisp file
# in the current directory.
# The prerequisite of sb-grovel might be spurious, but I don't want to detect
# whether sb-grovel is actually needed.
# This produces $(ASD) as a side-effect.
$(FASL): $(CL_TOP)/output/cl.core $(wildcard *.lisp) $(wildcard */*.lisp) \
 ../sb-grovel/*.lisp
	$(CL)	--load ../make-contrib.lisp "$(SYSTEM)" $(MODULE_REQUIRES) </dev/null
