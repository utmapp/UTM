Mac OS 9 3D (OpenGL and RAVE) for UTM
=====================================

OpenGLLibrary replaces Apple's OpenGLLibrary so OpenGL games run on the
host GPU. "UTM RAVE Loader" adds the UTM RAVE engine, a RAVE drawing engine
on top of that OpenGL, so RAVE and QuickDraw 3D games are accelerated too. Both need
a UTM VM with the "VGA" display (Mac OS 9, mac99) and this UTM version's
qemu_vga driver. Tested with GLQuake, Quake III Arena demo, Nanosaur and
Blokz RAVE.

Install
1. Open your System Folder, then the Extensions folder.
2. Find Apple's "OpenGLLibrary". Drag it into the folder
   "Extensions (Disabled)" (create that folder in the System Folder
   if it does not exist).
3. Drag OpenGLLibrary and UTM RAVE Loader from this folder into
   Extensions.
4. Restart the Mac.

Apple's own files (Classic RAVE, QuickDraw 3D RAVE, OpenGLUtility) stay as
they are; nothing of Apple's is modified.

Use
- Several OpenGL programs can run at the same time; windows in front of
  an OpenGL window are respected.
- Full screen and windowed modes work.
- RAVE games use the "UTM RAVE" engine; Apple's software RAVE engine is
  switched off while the loader is installed. To compare with Apple's
  Classic RAVE engine ("RAVEOGL"), put an empty file named "UTM RAVE.classic"
  in the System Folder and restart.
- Diagnostics: an empty file named "OpenGLLibrary.debug" in the System
  Folder writes a detailed OpenGLLibrary.log there. Remove it afterwards.

Uninstall
- Move OpenGLLibrary and UTM RAVE Loader out of Extensions, put Apple's
  OpenGLLibrary back, restart.

If a file looks like a plain document, use the .bin copy instead and
expand it with StuffIt Expander.

ATI Radeon 7000 display (Mac OS 9, mac99)
=========================================

The "ATI Radeon 7000" display card uses ATI's own Mac OS 9 drivers, not
the qemu_vga driver. UTM RAVE Loader and this folder's OpenGLLibrary are
for the "VGA" card only; with the Radeon 7000 keep Apple's OpenGLLibrary
and do not install UTM RAVE Loader.

Install
1. Install ATI's "OS 9 Drivers (January 2005)" in the guest.
2. In System Folder > Extensions, move these into "Extensions (Disabled)"
   (they crash the boot with this card): the Rage 128, Rage Pro and
   Radeon 8500 extensions, and ATI's "Video" extensions of those cards.
3. Keep: ATI Extension, ATI Graphics Accelerator, ATI ROM Xtender,
   ATI Radeon 3D Accelerator, ATI Resource Manager, ATI Video Memory
   Manager and ATI Monitor.
4. Restart. The size is picked in Monitors; UTM starts the card at the
   host window size.
