
# UTM virtual machine packager

> _or... a proof-of-concept using `pkl` to build macOS virtual machines, using RouterOS as the ginny pig._

[UTM](https://mac.getutm.app) is an open-source app enabling both Apple and QEMU-based machine virtualization for macOS.  In UTM, a virtual machine is just a folder ending in .utm (i.e. "package bundle"), with
a `config.plist` and subdirectory `Data` containing virtual disk(s) or other metadata like an icon.
This project produces a valid UTM document package bundle automatically based on [`pkl` files](https://pkl-lang.org).

The newly created bundle contains a virtualized OS that can be installed in a few ways:
  * via app URL, `utm://downloadVM?...`, which downloads and installs a VM into UTM's default store
  * download ZIP from GitHub, then just open the "document" in Finder -  this will create an "alias" in UTM app to the location where you opened the UTM package
  * `git clone` (or fork) this project and build locally - then copy or run as desired from the `Machines` directory. 


> **Links for ready-to-use RouterOS packages are in GitHub's [Releases](https://github.com/tikoci/mikropkl/releases)**

UTM supports two modes of virtualization:
  * [_QEMU_](https://docs.getutm.app/settings-qemu/settings-qemu/)
    - support both emulation and virtualization, so ARM can be emulated on Intel, or use direct virtualization if on the same platform.
    - USB device support and a wider range of network adapters available
    - images marked with "QEMU"
  * [_Apple Virtualization Framework_](https://docs.getutm.app/settings-apple/settings-apple/)
    - more limited support for devices and options
    - quicker startup than QEMU
    - images marked with "Apple" 

Additionally, there are two primary network modes:
  * _Shared_
    - virtual machine use network (subnet) local to macOS
    - internet connections from guest OSes are NATed by Apple/QEMU from the "shared" network to the real interface 
  * _Bridged_
    - virtual machine is bound to a macOS interface
    - still "shared" with macOS, but the machine presents its own MAC on the bridged network
    - can use ethernet dongle(s) as bridge interfaces to separate networks.

By default, all packages support UTM's [Headless Mode](https://docs.getutm.app/advanced/headless/). Two serial ports are added, the "built-in Terminal" and a "pseudo-tty" serial port.  These allow direct console access and serial-based automation, respectively.

All of UTM settings can be manifested by the `.pkl` scripts here. Essentially converting the friendly .pkl into the needed .plist file, with download disk images provided by the `Makefile`, and finally packaged by GitHub Action.  

## Installing UTM on macOS

This projects just build _UTM_ virtual machines, UTM has to be installed to actually run any packaged machines.
UTM is available from:
  * Mac App Store:  https://apps.apple.com/us/app/utm-virtual-machines/id1538878817?mt=12
  * GitHub: https://github.com/utmapp/UTM/releases/latest/download/UTM.dmg

See [UTM's documentation](https://docs.getutm.app) for more details.

## Download Machines

The framework here is pretty agnostic, so while a similar approach works for more common things like Alpine or Ubuntu.  There is only one class of machine today, RouterOS.

### Mikrotik RouterOS (`chr.*` and `rose.chr.*`)
 
> See [Releases](https://github.com/tikoci/mikropkl/releases) section on GitHub for downloads.  Installation instructions are in the release notes.

## Build on macOS 

The original intent was to use this as part of CI system, like GitHub Actions.
However, it will run on macOS desktops too.  You'll need the following packages installed first:
  * `make` (either from XCode or "brew install make")
  * `pkl` (either from https://pkl-lang.org or "brew install pkl")
  * `git` (optional, other than getting source, "brew install git" or XCode)
  * `qemu-img` (optional, unless building machines with extra disks, "brew install qemu")

With those tools, it is only a few steps:
  1. Use `git clone https://github.com/tikoci/mikropkl` (or download source from GitHub)
  2. Change to the directory with source, and run `make`
  3. In a few minutes, images will be built to the `./Machines` directory (on a one-to-one basis to files in `./Manifests`)
  4. To add it as an alias to UTM app, use `open ./Machines/<machine_name>`.

The `Makefile` supports some additional helpers to install and start all machines:
```
make utm-install
make utm-start
```

[UTM supports AppleScript](https://docs.getutm.app/scripting/scripting/) which can be used to further automate the virtual machines.  The `Makefile` has a function helper to send AppleScript commands to UTM from within a `make <target>`.  To view UTM's AppleScript "API", you can use "Script Editor" app's Library feature, see Apple's doc ["View an apps scripting dictionary"](https://support.apple.com/guide/script-editor/view-an-apps-scripting-dictionary-scpedt1126/2.11/mac/15.0), with the added detail you need to add UTM from `/Applications` in the library using (+).


## Creating new machines

While a bit complex behind the scenes, creating or re-build machines happens in `/Manifests`.  
This added layer of abstraction allows just a few simple lines to define a VM in this `pkl` approach, with the rest of UTM `.plist` calculated behind the scenes.

The provided `Makefile` will invoke `pkl` internally and create **_one bundle per file_** in `Manifests`,
with resulting virtual machines "building" to `Machines`.  The entire process is done with a simple `make`. 

All "manifests" are rooted in `./Pkl/utmzip.pkl` which defines the structure needed to produce images.  Pkl's `extends` can be used by any future "middleman" in `./Templates`, or a file in `./Manifests` may directly `amend "./Pkl/utmzip.pkl"` - without a "template" - for simple cases. 

If the goal is to just "tweak" an existing configuration, you should be able to either edit or copy an existing `.pkl` file in `./Manifests` without knowing any `pkl` specifics.  

But adapting to new machine types requires a better understanding of `pkl`.  See https://pkl-lang.org for examples and documentation `pkl` syntax and libraries.


## Understanding the project's structure

#### `Makefile` - runs `pkl` and handles final package processing
A classic Makefile is used to start `pkl`'s generation of virtual machine packages.  Since pkl-lang cannot deal with binary files, the Makefile also processes "placeholder" files, added by pkl code, to download disk and other files after `pkl` completes.  Running just `make` should build all packages, although it is recommended to run `make clean` before any fresh build.


> Running `make` multiple times is fine. However, it will rebuild all /Machines, and replace any disks.
> As the built machines are "runnable" from the build directory (`Machines`), any change will be lost on a `make`.
> `pkl` always produces files, even if unchanged, so `Makefile` mechanisms for partial rebuild are not
> supported. 


#### `./Pkl` - provides the basic framework needed by templates 
`UTM.pkl` is the main file here, and enables Pkl code to transform into UTM's `.plist` format.
UTM supports running VMs under either QEMU or Apple and is controlled via `backend` in Manifests and Templates.
Additional "application-specific" types, like `CHR.pkl`, know
download locations, icons, and other specific details of the application.
Any helpers like randomly generated UUID/MacAddress, live in `Utils.pkl`.  

#### `./Manifests` - defines the actual virtual machine images to be "built"
Each "manifest" will result in a new "machine", on a one-to-one basis.  Typically, by `amends`ing a "template", which allows varients to reuse an existing template or even another manifest as the "base" to modify.

#### `./Machines` - final output of images (_i.e._ "dist")
These are the ready-to-use packages produced.  GitHub Actions will make each a download item on a release.  Or, the machine can be added to UTM using `open ./Machine/<machine_name>` if used locally.

#### `./Templates` - provides `amends` "wrapper" around native types
Pkl code in `Templates` is "glue" between the .plist and a more "amends friendly" manifest.  The idea of a "machine class" is that it `extends` `./Pkl/utmzip.pkl`, adding OS/image specific details so that downstream manifests can use simple `amends` to a "template". For example, the `chr.utmzip.pkl` adds the downloading of a version-specific image, optional extra disks, and controlling colors in the SVG logo. 

#### `./Files` - non-Pkl files & media that may be needed in output (_i.e._ "static files")
Any files that may need to be included in a UTM package, that are not downloadable.  Currently, just `efi_vars.fd` is needed for Apple-based virtual machines.

