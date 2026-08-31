//
// Unmounting and remounting the volumes of a USB device around the claim.
// It lives in the privileged process because a forced unmount needs root,
// and because the order is an invariant of the protocol:
//
//   attach:  locate disks -> UNMOUNT (must succeed) -> claim
//   detach:  release + reset -> remount
//
// Never in parallel, never the other way round: a device claimed while
// macOS still has it mounted means two owners for the same disk.
//

import Foundation

enum USBDiskUnmounter {

    /// Smonta un disco intero preparandolo alla claim. Ritorna `nil` se ci è
    /// riuscito, altrimenti il messaggio da mostrare all'utente.
    ///
    /// `diskutil unmountDisk` chiede il permesso ai processi che tengono
    /// aperto il volume e accetta il loro veto. Sui dischi grandi il vetante
    /// abituale è l'indicizzazione Spotlight (`mdsync`/`mds_stores`), che da
    /// sé non molla in tempi utili: senza questa gestione il collegamento
    /// resta bloccato per sempre su "Unmount was dissented by…".
    ///
    /// La distinzione che conta, ed è il motivo per cui non si forza e
    /// basta: un vetante di SISTEMA (indicizzatori, fseventsd) non ha dati
    /// dell'utente in bilico, quindi dopo qualche tentativo educato lo si
    /// scavalca; un vetante che è un'APPLICAZIONE dell'utente può avere
    /// scritture non ancora sul disco — lì forzare significherebbe perdere
    /// dati, quindi ci si ferma e si dice quale programma chiudere.
    static func unmountForClaim(_ disk: String) -> String? {
        let device = "/dev/\(disk)"
        var lastOutput = ""

        for attempt in 0..<3 {
            let result = run("/usr/sbin/diskutil", ["unmountDisk", device])
            if result.status == 0 { return nil }
            lastOutput = result.output

            let dissenters = parseDissenters(result.output)
            if let userApp = dissenters.first(where: { !isSystemProcess($0.path) }) {
                let name = (userApp.path as NSString).lastPathComponent
                return "Smontaggio di \(device) rifiutato da \(name) (PID \(userApp.pid)), "
                     + "che sta usando il disco. Non forzo lo smontaggio per non rischiare "
                     + "la perdita di dati non ancora scritti: chiudi quel programma e riprova."
            }
            if dissenters.isEmpty && attempt == 0 {
                // Fallimento non dovuto a un veto: insistere non serve.
                break
            }
            Thread.sleep(forTimeInterval: 2.0)
        }

        // Restano solo vetanti di sistema (o un fallimento senza veto):
        // ultima risorsa, tracciata perché non sia una decisione invisibile.
        FileHandle.standardError.write(Data(
            "smontaggio educato di \(device) non riuscito (\(lastOutput.trimmingCharacters(in: .whitespacesAndNewlines))), forzo\n".utf8))
        let forced = run("/usr/sbin/diskutil", ["unmountDisk", "force", device])
        if forced.status == 0 { return nil }

        return "Smontaggio di \(device) fallito, non procedo: \(forced.output)"
    }

    /// Rimontaggio best-effort: dopo il reset macOS ri-sonda il device e
    /// spesso monta da sé, ma l'identificatore BSD può essere cambiato.
    /// Si concede qualche secondo perché la re-enumerazione non è istantanea.
    static func remount(_ disks: [String]) {
        guard !disks.isEmpty else { return }
        for disk in disks {
            var mounted = false
            for _ in 0..<10 {
                if run("/usr/sbin/diskutil", ["mountDisk", "/dev/\(disk)"]).status == 0 {
                    mounted = true
                    break
                }
                Thread.sleep(forTimeInterval: 1.0)
            }
            if !mounted {
                FileHandle.standardError.write(Data(
                    "/dev/\(disk) non rimontato; macOS potrebbe farlo da sé\n".utf8))
            }
        }
    }

    /// Estrae i vetanti dall'output di `diskutil`, che li elenca come
    /// "Unmount was dissented by PID 123 (/percorso/del/binario)".
    private static func parseDissenters(_ output: String) -> [(pid: Int, path: String)] {
        let pattern = #"dissented by PID (\d+) \(([^)]*)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        return regex.matches(in: output, range: range).compactMap { match in
            guard let pidRange = Range(match.range(at: 1), in: output),
                  let pathRange = Range(match.range(at: 2), in: output),
                  let pid = Int(output[pidRange]) else { return nil }
            return (pid, String(output[pathRange]))
        }
    }

    private static func isSystemProcess(_ path: String) -> Bool {
        ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/usr/bin/"]
            .contains { path.hasPrefix($0) }
    }

    @discardableResult
    private static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do { try task.run() } catch { return (-1, error.localizedDescription) }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (task.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }
}
