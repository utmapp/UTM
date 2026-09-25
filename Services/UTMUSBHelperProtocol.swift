//
// XPC protocol shared between the app and UTMUSBHelper (§ UTMUSBHelper/, a
// privileged LaunchDaemon registered through SMAppService — macOS 13+).
// Compiled into BOTH targets: only the shape of the contract lives here,
// never the logic (that is in USBRedirService.swift, on the daemon side).
//
// ── Why a daemon at all ─────────────────────────────────────────────────
// On macOS `libusb_claim_interface()` fails with LIBUSB_ERROR_ACCESS for any
// device already bound to a kernel driver. Measured with a controlled A/B
// comparison (same device, same unmount, same binary — only the uid
// changes): as a normal user libusb refuses with "USB device capture
// requires either an entitlement (com.apple.vm.device-access) or root
// privilege"; as root it succeeds. That entitlement is restricted, so root
// it is — but only for this very small daemon.
//
// ── Why running QEMU as root is not the answer ──────────────────────────
// Because root does not bypass TCC: TCC protects by process identity, not by
// privilege. A QEMU started from a LaunchDaemon can no longer open the VM
// files. Here QEMU stays an ordinary user process and only talks to us over
// a socket: no TCC problem, no storage migration, the group container stays
// where it is.
//

import Foundation

/// Name of the Mach service the daemon listens on — the same value appears
/// in the launchd plist Label, in its MachServices entry, and here for the
/// app-side NSXPCConnection.
let kUTMUSBHelperMachServiceName = "com.utmapp.UTMUSBHelper"

@objc protocol UTMUSBHelperProtocol {
    /// Diagnostic ping — checks that the daemon is actually reachable after
    /// registration, before trusting any other call.
    func ping(reply: @escaping (String) -> Void)

    /// Redirects `vendorId:productId` to the VM listening on `socketPath`
    /// (the `-chardev socket,server=on,wait=off` QEMU created at startup).
    ///
    /// SAFETY INVARIANT: if the device is a storage unit, the daemon
    /// unmounts its volumes with `diskutil unmountDisk` and proceeds ONLY if
    /// the unmount succeeded. Never in parallel, never afterwards: claiming
    /// a device while a volume is still mounted risks corruption.
    func attachDevice(vendorId: Int,
                      productId: Int,
                      socketPath: String,
                      reply: @escaping (Bool, String?) -> Void)

    /// Gives the device back to macOS: releases the interfaces, **resets it
    /// to force re-enumeration** and remounts the volumes.
    ///
    /// The reset is not a detail: verified live that without it macOS does
    /// not probe the device again, and it stays enumerated on the USB bus
    /// with no block device — `diskutil` hangs and the only remedy left to
    /// the user is unplugging the cable.
    func detachDevice(vendorId: Int,
                      productId: Int,
                      reply: @escaping (Bool, String?) -> Void)

    /// Detach everything. A safety net called when the app quits; the daemon
    /// also runs it on its own when the client's XPC connection is
    /// invalidated (app quit or crashed), because it owns the devices and
    /// outlives the client.
    func detachAll(reply: @escaping (Bool) -> Void)

    /// Currently redirected devices, as "vvvv:pppp" hex strings — the UI
    /// uses it to rebuild its state after an app restart instead of guessing.
    func listAttached(reply: @escaping ([String]) -> Void)
}
