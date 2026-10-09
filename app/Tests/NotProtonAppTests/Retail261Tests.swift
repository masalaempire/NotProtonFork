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

    @Test("26.1 coexists with newer tools without taking their names")
    func alongsideNewerTools() throws {
        let retail = try #require(SupportedRunners.build(id: "26.1.0.39808"))
        let release = try #require(SupportedRunners.build(id: "26.3.0.39832"))
        let preview = try #require(SupportedRunners.build(id: "27.0.0.41069-fex"))
        let tools = SupportedRunners.tools(for: [retail, release, preview])
        #expect(tools.map(\.name) == [
            "notproton-fex-41069", "notproton-fex-rosetta-41069",
            "notproton-26.3", "notproton-26.1",
        ])
        #expect(Set(tools.map(\.name)).count == tools.count)
        #expect(release.patchedNtdll[.x86_64Windows]
            == "c0e21a9a5250f0a97c08d3c3e1798566255387213e2553b1e555264fb9ded97e")
    }

    @Test("An existing 1.0.3 fork keeps its Steam tool mapping after upgrade")
    func preservesLegacyTool() throws {
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appending(path: "np-261-migrate-\(UUID().uuidString)")
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: directory) }
        let retail = try #require(SupportedRunners.build(id: "26.1.0.39808"))
        let release = try #require(SupportedRunners.build(id: "26.3.0.39832"))
        try fm.createSymbolicLink(
            atPath: directory.appending(path: "current").path,
            withDestinationPath: "crossover-26.1.0.39808/CrossOver"
        )
        let holder = CompatToolList.legacyHolder(builds: [retail, release], listed: nil, runners: directory)
        #expect(holder == .build(retail.id))
        let tools = SupportedRunners.tools(for: [retail, release], legacy: holder)
        #expect(tools.map(\.name) == ["notproton", "notproton-26.3"])
        #expect(tools.first?.build == retail.id)
        #expect(CompatToolList.legacyHolder(
            builds: [retail, release], listed: CompatToolList.contents(tools), runners: directory
        ) == holder)
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
