# Use tab to indent recipe lines, spaces to indent other lines, otherwise
# GNU make may get unhappy.

CC ?= gcc

PREFIX ?= /usr
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1
APPDIR ?= $(PREFIX)/share/applications

PACKAGES = x11 xcomposite xfixes xdamage xrender xext xrandr
LIBS = -lm -lrt
INCS =

OBJS = companion.o

# === Configuration flags ===
CFG = -std=c99

# ==== libconfig ====
ifeq "$(NO_LIBCONFIG)" ""
  CFG += -DCONFIG_LIBCONFIG
  PACKAGES += libconfig

  # libconfig-1.3* does not define LIBCONFIG_VER* macros, so we use
  # pkg-config to determine its version here
  CFG += $(shell pkg-config --atleast-version=1.4 libconfig || echo '-DCONFIG_LIBCONFIG_LEGACY')
endif

# ==== PCRE regular expression ====
ifeq "$(NO_REGEX_PCRE)" ""
  CFG += -DCONFIG_REGEX_PCRE
  LIBS += $(shell pcre-config --libs)
  INCS += $(shell pcre-config --cflags)
  ifeq "$(NO_REGEX_PCRE_JIT)" ""
    CFG += -DCONFIG_REGEX_PCRE_JIT
  endif
endif

# ==== DRM VSync ====
ifeq "$(NO_VSYNC_DRM)" ""
  INCS += $(shell pkg-config --cflags libdrm)
  CFG += -DCONFIG_VSYNC_DRM
endif

# ==== OpenGL VSync ====
ifeq "$(NO_VSYNC_OPENGL)" ""
  CFG += -DCONFIG_VSYNC_OPENGL
  # -lGL must precede some other libraries, or it segfaults on FreeBSD (#74)
  LIBS := -lGL $(LIBS)
  OBJS += opengl.o
  ifeq "$(NO_VSYNC_OPENGL_GLSL)" ""
    CFG += -DCONFIG_VSYNC_OPENGL_GLSL
  endif
endif

# ==== D-Bus ====
ifeq "$(NO_DBUS)" ""
  CFG += -DCONFIG_DBUS
  PACKAGES += dbus-1
  OBJS += dbus.o
endif

# ==== C2 ====
ifeq "$(NO_C2)" ""
  CFG += -DCONFIG_C2
  OBJS += c2.o
endif

# === Version string ===
COMPANION_VERSION ?= git-$(shell git describe --always --dirty)-$(shell git log -1 --date=short --pretty=format:%cd)
CFG += -DCOMPANION_VERSION="\"$(COMPANION_VERSION)\""

LDFLAGS ?= -Wl,-O1 -Wl,--as-needed

ifeq "$(DEV)" ""
  CFLAGS ?= -DNDEBUG -O2 -D_FORTIFY_SOURCE=2
else
  CC = clang
  export LD_ALTEXEC = /usr/bin/ld.gold
  OBJS += backtrace-symbols.o
  LIBS += -lbfd
  CFLAGS += -ggdb -Wshadow
  # CFLAGS += -Weverything -Wno-disabled-macro-expansion -Wno-padded -Wno-gnu
endif

LIBS += $(shell pkg-config --libs $(PACKAGES))
INCS += $(shell pkg-config --cflags $(PACKAGES))

CFLAGS += -Wall

BINS = companion bin/companion-trans
MANPAGES = man/companion.1 man/companion-trans.1
MANPAGES_HTML = $(addsuffix .html,$(MANPAGES))

# === Recipes ===
.DEFAULT_GOAL := companion

src/.clang_complete: Makefile
	@(for i in $(filter-out -O% -DNDEBUG, $(CFG) $(CFLAGS) $(INCS)); do echo "$$i"; done) > $@

%.o: src/%.c src/%.h src/common.h
	$(CC) $(CFG) $(CFLAGS) $(INCS) -c src/$*.c

companion: $(OBJS)
	$(CC) $(CFG) $(LDFLAGS) $(CFLAGS) -o $@ $(OBJS) $(LIBS)

man/%.1: man/%.1.asciidoc
	a2x --format manpage $<

man/%.1.html: man/%.1.asciidoc
	asciidoc $<

docs: $(MANPAGES) $(MANPAGES_HTML)

install: $(BINS) docs
	@install -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(MANDIR)" "$(DESTDIR)$(APPDIR)"
	@install -m755 $(BINS) "$(DESTDIR)$(BINDIR)"/ 
	@install -m644 $(MANPAGES) "$(DESTDIR)$(MANDIR)"/
	@install -m644 companion.desktop "$(DESTDIR)$(APPDIR)"/
ifneq "$(DOCDIR)" ""
	@install -d "$(DESTDIR)$(DOCDIR)"
	@install -m644 README.md companion.sample.conf "$(DESTDIR)$(DOCDIR)"/
	@install -m755 dbus-examples/cdbus-driver.sh "$(DESTDIR)$(DOCDIR)"/
endif

uninstall:
	@rm -f "$(DESTDIR)$(BINDIR)/companion" "$(DESTDIR)$(BINDIR)/companion-trans"
	@rm -f $(addprefix "$(DESTDIR)$(MANDIR)"/, companion.1 companion-trans.1)
	@rm -f "$(DESTDIR)$(APPDIR)/companion.desktop"
ifneq "$(DOCDIR)" ""
	@rm -f $(addprefix "$(DESTDIR)$(DOCDIR)"/, README.md companion.sample.conf cdbus-driver.sh)
endif

clean:
	@rm -f $(OBJS) companion $(MANPAGES) $(MANPAGES_HTML) .clang_complete

version:
	@echo "$(COMPANION_VERSION)"

.PHONY: uninstall clean docs version
