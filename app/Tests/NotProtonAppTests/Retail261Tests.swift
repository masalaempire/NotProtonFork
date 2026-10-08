import Foundation
import Testing

@testable import NotProtonApp

@Suite("Retail CrossOver 26.1")
struct Retail261Tests {
    @Test("Retail patches and resources remain complete")
    func registered() throws {
        let build = try #require(SupportedRunners.build(id: "26.1.0.39808"))
        #expect(build.displayVersion == "26.1 Rosetta")
        #expect(Set(NtdllPatcher.patches(for: build).map(\.arch)) == [.i386Windows, .x86_64Windows])
        for patch in NtdllPatcher.patches(for: build) {
            #expect(patch.placement == .section)
            #expect(try NtdllPatcher.payload(for: patch).count <= patch.caveSize)
        }
    }

    // Opt in with a clean retail bundle. Reads the source and patches in memory;
    // never writes into the installed app or starts Wine/Steam.
    @Test("Real retail DLLs produce the pinned hashes and reject a second patch",
          .enabled(if: ProcessInfo.processInfo.environment["NP_TEST_CROSSOVER_261"] != nil))
    func realImages() throws {
        let path = try #require(ProcessInfo.processInfo.environment["NP_TEST_CROSSOVER_261"])
        let bundle = URL(filePath: path)
        let build = try #require(SupportedRunners.build(id: "26.1.0.39808"))
        let install = CrossOverSource.inspect(bundle: bundle)
        #expect(install.support == .supported(build))
        try CrossOverSource.verifyPatchInputs(root: install.crossOverRoot, build: build)
        for patch in NtdllPatcher.patches(for: build) {
            let source = NtdllPatcher.cleanSource(inRoot: install.crossOverRoot, arch: patch.arch)
            let image = try Data(contentsOf: source)
            let payload = try NtdllPatcher.payload(for: patch)
            let output = try NtdllPatcher.apply(patch, to: image, payload: payload)
            #expect(Digest.sha256(of: output) == build.patchedNtdll[patch.arch])
            #expect(output.count > image.count)
            // Appending the section twice must fail closed.
            #expect(throws: StepFailure.self) {
                try NtdllPatcher.apply(patch, to: output, payload: payload)
            }
            #expect(try Data(contentsOf: source) == image)
        }
    }
}
