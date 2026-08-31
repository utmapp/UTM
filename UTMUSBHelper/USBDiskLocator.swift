//
// From `vid:pid` to the BSD disks that device exposes.
//
// Used to unmount EXACTLY the volumes of the device we are about to claim
// — never by guessing from a name or from a position in `diskutil list`,
// which changes on every re-enumeration (after a reset the same SSD can
// come back with a different identifier).
//
// If the device is not a storage unit (keyboard, dongle, webcam…) the list
// is simply empty and there is nothing to unmount: that is the normal case,
// not an error.
//

import Foundation
import IOKit

enum USBDiskLocator {
    /// Nomi BSD dei dischi INTERI (es. "disk4", mai "disk4s1") esposti dal
    /// device USB indicato. Vuoto se non è un dispositivo di archiviazione.
    static func wholeDisks(forVendorId vid: Int, productId pid: Int) -> [String] {
        guard let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary? else {
            return []
        }
        matching["idVendor"] = NSNumber(value: vid)
        matching["idProduct"] = NSNumber(value: pid)

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           matching as CFDictionary,
                                           &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var disks: [String] = []
        while case let device = IOIteratorNext(iterator), device != 0 {
            defer { IOObjectRelease(device) }
            disks.append(contentsOf: wholeDisksUnder(device))
        }
        // Lo stesso vid:pid potrebbe teoricamente comparire su più unità;
        // deduplica preservando l'ordine.
        var seen = Set<String>()
        return disks.filter { seen.insert($0).inserted }
    }

    /// Scende ricorsivamente nell'albero IORegistry sotto un device USB in
    /// cerca di nodi IOMedia che rappresentino un disco intero.
    private static func wholeDisksUnder(_ device: io_object_t) -> [String] {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(device,
                                            kIOServicePlane,
                                            IOOptionBits(kIORegistryIterateRecursively),
                                            &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var result: [String] = []
        while case let child = IOIteratorNext(iterator), child != 0 {
            defer { IOObjectRelease(child) }
            guard IOObjectConformsTo(child, "IOMedia") != 0 else { continue }

            // Solo il disco intero: smontare quello smonta tutte le sue
            // partizioni in un colpo solo (`diskutil unmountDisk`).
            let isWhole = (IORegistryEntryCreateCFProperty(child, "Whole" as CFString,
                                                           kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? NSNumber)?.boolValue ?? false
            guard isWhole else { continue }

            if let bsd = (IORegistryEntryCreateCFProperty(child, "BSD Name" as CFString,
                                                          kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? String) {
                result.append(bsd)
            }
        }
        return result
    }
}
