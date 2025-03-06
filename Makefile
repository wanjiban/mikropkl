
# Makefile for UTM pkl'er

# TL;DR: essentially builds the .pkl files /Manifests into UTM virtual machines in /Machines
#        each .pkl becomes a .utm directory, and will "open" in UTM App directly after build
#        a .zip file can be used with utm://downloadVM?url= to install a VM into UTM

# NOTE: No "partial" build - so a build will overwrite disks!
#   Thus, while VMs will run from the /Machines directory, any changes will be lost on next `make`. 

.PHONY: prereq deps all build pkl clean 
.SUFFIXES: 

# basic build "from" and "to" here...
PKL_RUN_DIR := Manifests
PKL_OUTPUT_DIR := Machines
PKL_FILES_DIR := Files

# machine specific properties
CHR_VERSION ?= stable

# options for `pkl` build
PKL_OPTIONS := --prop chrVersion=$(CHR_VERSION)


all: prereq deps 
	$(info all done)

prereq:
	pkl --version
	make --version
	qemu-img --version
	$(info prereq completed)
	
clean:
	$(info cleaning $(PKL_OUTPUT_DIR))
	rm -rf ./$(PKL_OUTPUT_DIR)

# pkl creates the initial files /Manifasts to kickstart a UTM ZIP
deps: pkl
	$(info debug URLFILES $(URLFILES))
	$(info debug URLTARGETS $(URLTARGETS))
	$(info debug SIZEFILE $(SIZEFILE))
	$(info debug SIZETARGETS $(SIZETARGETS))
	$(info debug ZIPIMGFILES $(ZIPIMGFILES))
	$(info debug ZIPIMGTARGETS $(ZIPIMGTARGETS))
	$(info recursively call make build now placeholder files are created)
	$(MAKE) build

pkl:
	$(info running pkl)
	pkl eval ./$(PKL_RUN_DIR)/*.pkl $(PKL_OPTIONS) -m ./$(PKL_OUTPUT_DIR)

# NOTES:  This Makefile is recursive. `pkl` is run first which produces
#	      some placeholder files like .url, then `make` is run again
#         to find those placeholders in PKL_OUTPUT_DIR ("/Machines").
#		  The found files become targets and deps, with make pattern rules
#         doing the heavy lifting to download, unzip, or run commands.

# pattern rules run the show
%.raw: %.raw.url
	wget -O $@ `cat $<`
%.img: %.img.zip.url
	wget -O $@.zip `cat $<`
	unzip $(subst .url,,$<) -d $(dir $@)
	rm $(subst .url,,$<)
%.qcow2: %.qcow2.zip.url
	wget -O $@.zip `cat $<`
	unzip $(subst .url,,$<) -d $(dir $@)
	rm $(subst .url,,$<)
%.qcow2: %.size
	qemu-img create -f qcow2 $@ `cat $<`M
%: %.localcp
	cp -f ./$(PKL_FILES_DIR)/`cat $<` $@

# search for placeholder files
#   note: these will only work AFTER `pkl`, and why Makefile is recursive
URLFILES := $(wildcard ./$(PKL_OUTPUT_DIR)/*/Data/*.raw.url)
URLTARGETS := $(URLFILES:.url=)
ZIPIMGFILES := $(wildcard ./$(PKL_OUTPUT_DIR)/*/Data/*img.zip.url)
ZIPIMGTARGETS := $(ZIPIMGFILES:.zip.url=)
SIZEFILE := $(wildcard ./$(PKL_OUTPUT_DIR)/*/Data/*.size)
SIZETARGETS := $(subst .size,.qcow2,$(SIZEFILE))
LOCALCPFILE := $(wildcard ./$(PKL_OUTPUT_DIR)/*/Data/*.localcp)
LOCALCPTARGETS := $(subst .localcp,,$(LOCALCPFILE))

# links all targets together from found placeholders
build: $(LOCALCPTARGETS) $(SIZETARGETS) $(URLTARGETS) $(ZIPIMGTARGETS)
	$(info ran build)
	$(info used deps: $?)

# download OS drive images
$(URLTARGETS): $(URLFILES)

# images may need unzip & handled seperately here
$(ZIPIMGTARGETS): $(ZIPIMGFILES)

# creates QEMU spare/empty disks
$(SIZETARGETS): $(SIZEFILE)

# converts a .localcp file into a file copy from /Files
$(LOCALCPTARGETS): $(LOCALCPFILE)

# macOS only

.PHONY: utm-version utm-install utm-uninstall utm-stop utm-start 

tellvm = osascript -e 'tell application "UTM" to $(2) virtual machine named "$(1)"'
doallvms = for i in $(subst .utm,,$(notdir $(wildcard ./$(PKL_OUTPUT_DIR)/*.utm))); do osascript -e "tell application \"UTM\" to $(1) virtual machine named \"$$i\"" ; done

utm-version:
	osascript -e 'get version of application "UTM"'

utm-install: $(wildcard ./$(PKL_OUTPUT_DIR)/*.utm)
	for i in $^; do open $$i; done

utm-uninstall:
	$(call doallvms, delete)

utm-stop:
	$(call doallvms, stop)

utm-start:
	$(call doallvms, start)