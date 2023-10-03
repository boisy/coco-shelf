# This is Makefile for the coco-shelf.
#
#        https://github.com/strickyak/coco-shelf
#
# The coco-shelf helps you build packages associated with Nitros9
# (especially strick's frobio networking packages)
# in a standard and (mostly) repeatable way on modern Linux machines.

# You can edit version numbers in here, to upgrade to newer packages:
include conf.mk

# For calling make from a subdirectory, with coco-shelf as HOME and limited PATH.
# We use coco-shelf as HOME to avoid differences due to personal dot-files.
# We fix the PATH to avoid differences due to a personal non-standard PATH.
RUN_MAKE = HOME="`cd .. && pwd`" PATH="`cd .. && pwd`/bin:/usr/bin:/bin" make

TARGETS = mirror-stuff done-lwtools done-cmoc
ifeq ($(UNAME),"Darwin")
TARGETS += done-gccretro
endif
TARGETS += done-toolshed done-nitros9
ifeq ($(UNAME),"Darwin")
TARGETS += done-frobio
endif

all: $(TARGETS)

run-lemma: all
	make -C build-frobio run-lemma

# If you already have tarballs of lwtools, cmoc, and gcc-4.6.4
# you can "mkdir mirror" yourself and put the tarballs in it,
# to avoid using wget over the internet.  If you already have a
# "mirror" directory somewhere else, you can make a symlink to it.

mirror-stuff:
	make -C mirror

mirror-pull:
	make -C mirror pull

$(COCO_LWTOOLS_VERSION):
	set -x; test -d $@ || tar -xzf mirror/$(COCO_LWTOOLS_TARBALL)
$(COCO_CMOC_VERSION):
	set -x; test -d $@ || tar -xzf mirror/$(COCO_CMOC_TARBALL)
$(COCO_GCCRETRO_VERSION):
	set -x; test -d $@ || tar -xjf mirror/$(COCO_GCCRETRO_TARBALL) && \
	      (cd $@ && patch -p1 < ../$(COCO_LWTOOLS_VERSION)/extra/gcc6809lw-4.6.4-9.patch)
	mkdir -p bin
	cp $(COCO_LWTOOLS_VERSION)/extra/as bin/m6809-unknown-as
	cp $(COCO_LWTOOLS_VERSION)/extra/ld bin/m6809-unknown-ld
	cp $(COCO_LWTOOLS_VERSION)/extra/ar bin/m6809-unknown-ar
	set -x; test -s bin/m6809-unknown-ranlib || ln -s /bin/true bin/m6809-unknown-ranlib
	set -x; test -s bin/makeinfo || ln -s /bin/true bin/makeinfo
toolshed:
	set -x; test -s $@ || cp -a mirror/$@ .
nitros9:
	set -x; test -s $@ || cp -a mirror/$@ .
frobio:
	set -x; test -s $@ || cp -a mirror/$@ .

done-frobio: frobio
	test -s bin/gcc6809 || ln -s m6809-unknown-gcc-4.6.4 bin/gcc6809
	mkdir -p build-frobio
	SHELF=`pwd`; cd build-frobio && HOME=/dev/null PATH="$$SHELF/bin:/usr/bin:/bin" ../frobio/frob3/configure --nitros9="$$SHELF/nitros9"
	SHELF=`pwd`; cd build-frobio && $(RUN_MAKE)
	date > done-frobio

done-toolshed: toolshed
	test -d usr || ln -s . usr
	SHELF=`pwd`; cd toolshed && $(RUN_MAKE) -C build/unix DESTDIR="$$SHELF" all
	SHELF=`pwd`; cd toolshed && $(RUN_MAKE) -C build/unix DESTDIR="$$SHELF" install
	date > done-toolshed

done-nitros9: nitros9
	cd nitros9 && NITROS9DIR=`pwd` $(RUN_MAKE) PORTS=coco1 dsk
	cd nitros9 && NITROS9DIR=`pwd` $(RUN_MAKE) PORTS=coco3 dsk
	cd nitros9 && NITROS9DIR=`pwd` $(RUN_MAKE) PORTS=coco3_6309 dsk
	date > done-nitros9

done-lwtools: $(COCO_LWTOOLS_VERSION)
	set -x; SHELF=`pwd`; (cd $< && $(RUN_MAKE) PREFIX="$$SHELF" all)
	set -x; SHELF=`pwd`; (cd $< && $(RUN_MAKE) PREFIX="$$SHELF" install)
	date > done-lwtools

done-cmoc: $(COCO_CMOC_VERSION)
	set -x; SHELF=`pwd`; (cd $< && PATH="$(PATH)" ./configure --prefix="$$SHELF")
	set -x; SHELF=`pwd`; (cd $< && $(RUN_MAKE) PREFIX="$$SHELF" all)
	set -x; SHELF=`pwd`; (cd $< && $(RUN_MAKE) PREFIX="$$SHELF" install)
	date > done-cmoc

done-gccretro: $(COCO_GCCRETRO_VERSION)
	echo PATH -- $$PATH -- PATH
	which makeinfo
	mkdir -p build-$(COCO_GCCRETRO_VERSION)
	SHELF=`pwd`; cd build-$< && PATH="$(PATH)" ../gcc-4.6.4/configure \
      --prefix="$$SHELF" \
      --enable-languages=c \
      --target=m6809-unknown \
      --disable-libada \
      --program-prefix=m6809-unknown- \
      --enable-obsolete \
      --disable-threads \
      --disable-nls \
      --disable-libssp \
      --with-as="$$SHELF/bin/m6809-unknown-as" \
      --with-ld="$$SHELF/bin/m6809-unknown-ld" \
      --with-ar="$$SHELF/bin/m6809-unknown-ar"
	cd build-$< && $(RUN_MAKE) MAKEINFO=true all-gcc
	cd build-$< && echo "// This is a kludge, not the real limits.h" > gcc/include-fixed/limits.h
	cd build-$< && $(RUN_MAKE) MAKEINFO=true all-target-libgcc
	cd build-$< && $(RUN_MAKE) MAKEINFO=true install-gcc
	cd build-$< && $(RUN_MAKE) MAKEINFO=true install-target-libgcc
	date > done-gccretro

clean-shelf:
	rm -rf build-* done-*
	rm -rf bin share lib libexec usr include .cache
	rm -rf cmoc-*/ frobio gcc-4.6.*/ lwtools-*/ m6809-unknown nitros9 toolshed
