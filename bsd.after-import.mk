# $Id: bsd.after-import.mk,v 1.2 2012/06/01 06:43:24 sjg Exp $

# This makefile is for use when integrating bmake into a BSD build
# system.  Use this makefile after importing bmake.
# It will bootstrap the new version,
# capture the generated files we need, and add an after-import
# target to allow the process to be easily repeated.

# The goal is to allow the benefits of autoconf without
# the overhead of running configure.

all: ${.CURDIR}/Makefile
all: after-import

# we rely on bmake
_this := ${MAKEFILE:tA} 
BMAKE_SRC := ${.PARSEDIR}

# it helps to know where the top of the tree is.
.if !defined(SRCTOP)
srctop := ${.MAKE.MAKEFILES:M*src/share/mk/sys.mk:H:H:H}
.if !empty(srctop)
SRCTOP := ${srctop}
.endif
.endif

# This lets us match what boot-strap does
.if !defined(HOST_OS)
HOST_OS!= uname
.endif

# .../share/mk will find ${SRCTOP}/share/mk
# if we are within ${SRCTOP}
DEFAULT_SYS_PATH= .../share/mk:/usr/share/mk

BOOTSTRAP_ARGS = \
	--with-default-sys-path='${DEFAULT_SYS_PATH}' \
	--prefix /usr \
	--share /usr/share \
	--mksrc none

# run boot-strap with minimal influence
bootstrap:	${BMAKE_SRC}/boot-strap ${MAKEFILE}
	HOME=/ ${BMAKE_SRC}/boot-strap ${BOOTSTRAP_ARGS}
	touch ${.TARGET}

# Makefiles need a little more tweaking than say config.h
MAKEFILE_SED = 	sed -e '/^MACHINE/d' \
	-e '/^PROG/s,bmake,${.CURDIR:T},' \
	-e 's,${SRCTOP},$${SRCTOP},g'

# These are the simple files we want to capture
configured_files= config.h unit-tests/Makefile

after-import: bootstrap ${MAKEFILE}
.for f in ${configured_files:N*Makefile}
	@echo Capturing $f
	@cmp -s ${.CURDIR}/$f ${HOST_OS}/$f || \
	    cp ${HOST_OS}/$f ${.CURDIR}/$f
.endfor
.for f in ${configured_files:M*Makefile}
	@echo Capturing $f
	@${MAKEFILE_SED} ${HOST_OS}/$f > ${.CURDIR}/$f
.endfor

# this needs the most work
${.CURDIR}/Makefile:	bootstrap ${MAKEFILE} .PRECIOUS
	@echo Generating ${.TARGET:T}
	@(echo '# This is a generated file, do NOT edit!'; \
	echo '# See ${_this:S,${SRCTOP}/,,}'; \
	echo; echo '# look here first for config.h'; \
	echo 'CFLAGS+= -I$${.CURDIR}'; echo; \
	${MAKEFILE_SED} ${HOST_OS}/Makefile; \
	echo; echo '# override some simple things'; \
	echo 'BINDIR= /usr/bin'; \
	echo 'MANDIR= /usr/share/man'; \
	echo; echo '# make sure we get this'; \
	echo 'CFLAGS+= $${COPTS.$${.IMPSRC:T}}'; \
	echo 'CLEANFILES+= bootstrap'; \
	echo; echo 'after-import: ${_this:S,${SRCTOP},\${SRCTOP},}'; \
	echo '	cd $${.CURDIR} && $${.MAKE} -f ${_this:S,${SRCTOP},\${SRCTOP},}'; \
	echo ) > ${.TARGET:T}.new
	@mv ${.TARGET:T}.new ${.TARGET}

.include <bsd.obj.mk>
