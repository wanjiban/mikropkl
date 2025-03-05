
# UTM virtual machine packager

> _or... a proof-of-concecpt using `pkl` to build macOS virtual machines, using RouterOS as the ginny pig._

[UTM](https://mac.getutm.app) is a open-source app enabling both Apple and QEMU-based machine virtualization for macOS.  In UTM, a virtual machine is just a folder ending in .utm (i.e. "package bundle"), with
a `config.plist` and subdirectory `Data` containing virtual disk(s) or other metadata like an icon.
This project produces a valid UTM document package bundle automatically based on [`pkl` files](https://pkl-lang.org).

The newly created bundled, containing a virtualized OS, can be installed in a few ways:
  * via app url, `utm://downloadVM?...`, - downloads and install a VM into UTM's default store
  * download ZIP from GitHub or other CI, and opening "document" in Finder -  will "alias" in UTM app to the location where you opened the UTM package
  * `git clone` (or fork) this project and build locally - then copy or run as desired from `Machines` directory. 


> **Links for ready-to-use RouterOS packages are in GitHub's [Releases](https://github.com/tikoci/mikropkl/releases)**

UTM supports two mode of virtualization:
  * [_QEMU_](https://docs.getutm.app/settings-qemu/settings-qemu/)
    - support both emulation and virtualization, so ARM can be emulated on Intel, or use direct virtualization if on same platform.
    - USB device support and wider range of network adapters available
    - images marked with "QEMU"
  * [_Apple Virtualization Framework_](https://docs.getutm.app/settings-apple/settings-apple/)
    - more limited support for devices and options
    - quicker startup than QEMU
    - images marked with "Apple" 

Additional their are two primary network modes:
  * _Shared_
    - virtual machine use network (subnet) local to macOS
    - internet connections from guest OSes are NATed by Apple/QEMU from the "shared" network to real interface 
  * _Bridged_
    - virtual machine is bound to a macOS interface
    - still "shared" with macOS, but machine presents it own MAC on the bridged network
    - can use ethernet dongle(s) to as bridge interfaces to seperate networks.

By default, all packages support UTM's [Headless Mode](https://docs.getutm.app/advanced/headless/).  Both the "built-in Terminal" and a "pseudo-tty" serial ports are enabled to allow both direct console access and serial-based automation repectively.

All of these UTM setting can be manifested by the `.pkl` scripts here. Essentially converting the friendly .pkl into needed .plist file, with download disk images provided by the `Makefile`, and finally packaged by GitHub Action.  

## Installing UTM on macOS

This projects just build _UTM_ virtual machines, UTM has to be installed to actually run any built machines.
UTM is available from:
  * Mac App Store:  https://apps.apple.com/us/app/utm-virtual-machines/id1538878817?mt=12
  * GitHub: https://github.com/utmapp/UTM/releases/latest/download/UTM.dmg

See [UTM's documentation](https://docs.getutm.app) for more details.

## Download Machines

The framework here is pretty agnostic, so while similar approach work for more common things like Alpine or Ubuntu.  There is only one class of machine today, RouterOS.

### Mikrotik RouterOS (`CHR.` and `ROSE.`)
 
> See [Releases](https://github.com/tikoci/mikropkl/releases) section on GitHub for downloads.  Installation instructions are in the release notes.

## Build on macOS 

The orginal intent was to use this as part of CI system, like GitHub Actions.
However, it will run on macOS desktop too.  You'll need the following packages install first:
  * `make` (either from XCode or "brew install make")
  * `pkl` (either from https://pkl-lang.org or "brew install pkl")
  * `git` (optional other than getting source, "brew install git" or XCode)

Basically, it only a few steps:
  1. Use `git clone https://github.com/tikoci/mikropkl` (or download source from GitHub)
  2. Change to directory with source, and run `make`
  3. In a few minutes, images will be built to the `./Machines` directory (on one-to-one basis to files in `./Manifests`)
  4. To add it as alias to UTM app, use `open ./Machines/<machine_name>`.

The `Makefile` supports some additional helpers to install and start all machines:
```
make utm-install
make utm-start
```

[UTM supports AppleScript](https://docs.getutm.app/scripting/scripting/) which can be used to further automate the virtual machines.  The `Makefile` has a function helper to send AppleScript commands to UTM from within a `make <target>`.  To view UTM's AppleScript "API", you can use "Script Editor" app's Library feature, see Apple's doc ["View an apps scripting dictionary"](https://support.apple.com/guide/script-editor/view-an-apps-scripting-dictionary-scpedt1126/2.11/mac/15.0), with the added detail you need to add UTM from `/Applications` in the library using (+).


## Creating new machines

While a bit complex behind the scenes, creating or re-build machines happens in `/Manifests`.  
This add layer of abstraction allow just a few simple lines to define a VM in this `pkl` approach, with the rest of UTM `.plist` calculated behind-the-scenes.

The provided `Makefile` will invoke `pkl` internally and create **_one bundle per file_** in `Manifests`,
with resulting virtual machines "building" to `Machines`.  The entire process is done with a simple `make`. 

All "manifests" are rooted in `./Pkl/utmzip.pkl` which defines the structure needed to produce images.  Pkl's `extends` can be used by any future "middleman" in `./Templates`, or a file in `./Manifests` may directly `amend "./Pkl/utmzip.pkl"` - without a "template" - for simple cases. 

If the goal is just "tweak" an existing configuration, you should be able to either edit on of the existing `.pkl` files in `./Manifests` without know any `pkl` specifics.  

But adapting to new machine types require a better understanding of `pkl`.  See https://pkl-lang.org for examples and documentation `pkl` syntax and libraries.


## Understanding project's structure

#### `Makefile` - runs `pkl` and handles final package processing
A classic Makefile is used to start `pkl`'s generation of virtual machine package.  Since pkl-lang cannot deal with binary files, the Makefile also processes "placeholder" files, added by pkl code, to download disk and other files after `pkl` completes.  Running just `make` should build all packages, although it recommended to run `make clean` before any fresh build.


> Running `make` multiple times is fine. However, it will rebuild all /Machines, and replace any disks.
> As the built machines are "runnable" from the build directory (`Machines`), any change will be lost on a `make`.
> `pkl` always produces files, even if unchanged, so `Makefile` mechanisms for partial rebuild is not
> supported. 


#### `./Pkl` - provides the basic framework needed by templates 
`UTM.pkl` is the main file here, and enables Pkl code to transform into UTM's `.plist` format.
UTM support running VMs under either QEMU or Apple, and controlled via `backend` in Manifests and Templates.
Additional "application specific" types, like `CHR.pkl`, have knowledge about
download locations, icons, and other specific details.
Any helpers like randomly generated UUID/MacAddress, live in `Utils.pkl`.  

#### `./Manifests` - defines the actual virtual machine images to be "built"
Each "manifest" will result in a new "machine", on a one-to-one basis.  Typically, by `amend`ing a "template" in simple form, which allows varients to reuses an existing template or even another manifast as the "base" to modify.

#### `./Machines` - final output of images (_i.e._ "dist")
These are the ready-to-use packages produced.  GitHub builder will make each their own download item from a release.  Or, machine can be added to UTM using `open ./Machine/<machine_name>`.

#### `./Templates` - provides `amend`-able "wrappers" around type system
Pkl code here is "glue" between the .plist and a more "amends friendly" manififest.  The idea of a "machine class" can be defined to more easily construct, with `./Pkl/utmzip.pkl` being the basis of most templates.
For example, the `chr.utmzip.pkl` deals with mainly with the specific of downloading a verison-specific image, and controlling colors in SVG used in icon. 

#### `./Files` - non-Pkl files & media that may be needed in output (_i.e._ "static files")
Any files that may need to be included in a UTM package, that are not downloadable.  Currently, just `efi_vars.fd` needed for Apple-based virtual machines.
