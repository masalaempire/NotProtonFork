# NotProton 1.1.2: Sequoia and CrossOver 26.1 compatibility fork

This fork carries the changes from NotProton **1.1.2**, including its launch hotfix,
multiple compatibility tools, APFS prefix cloning, Steam Input changes and Linux-style
launch options. The app targets **macOS Sequoia 15.0+** on Apple Silicon.

The added retail runner is **CrossOver 26.1, exact build 26.1.0.39808**. All five
upstream 1.1.2 runner records remain: CrossOver 26.3.0.39832, plus Rosetta and FEX
variants of Preview builds 27.0.0.40921 and 27.0.0.41069. Future unknown builds still
need their own binary hashes and patch validation. Retaining a runner record does
not lower that CrossOver runtime's own macOS requirement; FEX on Sequoia is untested.

## Using the update

1. Quit Steam and open `out/NotProton.app`.
2. Use **Install** to update the integration and its components.
3. Use **Set Up Compatibility Tool** for CrossOver 26.1 to update its copied runner.
4. Restart Steam. A fresh setup exposes **CrossOver 26.1** in Compatibility settings.
   Existing installs from our 1.0.3 fork retain the legacy `notproton` tool name on
   the 26.1 runner, preserving existing Steam game mappings.

This build does not reset existing game prefixes or reinstall game files. Normal
setup patches a copied runner; this development work does not modify the installed
CrossOver app or deploy changes to the user's Steam installation. CrossOver's
activation check and Steam signature matching remain required.

The upstream Sparkle updater is disabled, preventing an official update from
replacing this compatibility fork. Update this fork manually.

## Compatibility changes relative to upstream 1.1.2

- macOS deployment target and plist minimum are 15.0.
- Use ordinary SwiftUI toolbars and the existing classic ICNS for Xcode 26.2.
- Resolve packaged resources relative to the app before SwiftPM's build fallback;
  packaging accepts both SwiftPM resource bundle layouts.
- Add exact 26.1 loader, clean DLL and patched DLL hashes, plus a named Steam tool.
- Allow the old 26.1 runner to retain its legacy Steam mapping during migration.
- Apply 1.1.2's 64-bit loader hotfix to 26.1. The old 26.1 patched hash is intentionally
  replaced. The new code returns success from the stub DLL entry point and does not
  call lsteamclient's DllMain in the wrong loading context.
- Independently resolved 26.1 hook, cave and required export addresses match 26.3;
  rebuilt detours are byte-identical to the checked-in `detour2-cx26.bin` and
  `detour32-cx26.bin`. Each build retains separate clean/patched DLL hashes.
- Set MACOSX_DEPLOYMENT_TARGET=15.0 in Wine and Unix bridge build scripts.

The new run script, Steam shim, Steam Input sources and launch-option hooks are
preserved from 1.1.2. Its 26.3/Preview patch records and payloads are preserved.

## Build provenance

The runtime payload starts with the official
[NotProton v1.1.2 release](https://github.com/NotProtonNot/NotProton/releases/tag/v1.1.2).
Downloaded `NotProton.zip` SHA-256:

    8322e72aa172c95924d6295f830f68ee5a748cd30ce2da597243d0a133b1285e

All runtime files are from that release except `bridge/x86_64-unix-lsteamclient.so`,
which is the earlier source rebuild targeting macOS 15.0. All lsteamclient authored
sources, its Makefile.in and pinned Proton baseline are unchanged in 1.1.2, verified
by source comparison. The official Unix bridge targets macOS 27.0, so using it
unchanged would not support Sequoia. The official ARM64 bridge is retained and also
requires macOS 27.0; this fork does not establish FEX support on earlier systems.

The source rebuild uses Wine 11.15 at
`2df1ee28039cf84776eb1421ed90bd154cebb65f` and Valve Proton at
`164e0ccd2ea2b1ec2e5d08dc97f65b184c2539ca`, with this project's lsteamclient overlays.
Staged payload and downloaded dependencies are ignored build artifacts.

## Reproduction

Stage the verified official payload under
`app/Sources/NotProtonApp/Resources/payload`, then replace its x86_64 Unix bridge with
a source rebuild targeting 15.0. Install MinGW-w64, bison, flex and Capstone first.

```sh
WINE_URL=https://github.com/wine-mirror/wine.git \
  WINE_SRC="$PWD/scratch/wine-github" sh bridge/setup-wine-tree.sh
WINE_SRC_REL=../wine-github sh lsteamclient/build.sh --unix
cp scratch/wine-build-dual/dlls/lsteamclient/lsteamclient.so \
  app/Sources/NotProtonApp/Resources/payload/bridge/x86_64-unix-lsteamclient.so
make app-staged
NP_TEST_CROSSOVER_261=/Applications/CrossOver.app swift test --package-path app --no-parallel
```

Regenerate and validate the 26.1 DLL patches without installing them:

```sh
CX_ROOT=/Applications/CrossOver.app/Contents/SharedSupport/CrossOver \
  sh ntdll-patch/build-ntdll.sh
```

The resolver and build scripts pin exact clean inputs and output hashes. Do not
reuse object directories built for macOS 26/27 or change pins to bypass a mismatch.

## Validation on October 9, 2026

- All **475 Swift tests in 56 suites** passed, including real 26.1 DLL patches
  applied in memory, pinned output hashes, second-patch refusal, tool coexistence
  and upgrade mapping preservation.
- The 26.1 resolver self-tests reproduced every pinned value; the complete
  build-ntdll script regenerated and hash-checked both outputs without installation.
- The runtime checks passed: compatibility registration/service, environment,
  prefix seed/build/settings/routing/bridge/game-drive behavior, launch shell and
  spawn environment. The Node compatibility panel and launch-options tests passed.
- The x86_64 bridge loaded with RTLD_NOW against the installed CrossOver 26.1
  ntdll.so and exposed the Wine Unix entry table. This is a linking check, not
  proof of every Wine ABI or Steam feature.
- The Release app built; executable and x86_64 bridge declare macOS 15.0.
- The app passed codesign --verify --strict with ad-hoc signing, and its ZIP
  passed unzip -t. Every packaged payload and detour matches the staged input.
- Installed CrossOver's loader and both clean ntdll DLL hashes are unchanged.
- No end-to-end Steam or game launch was performed by the assistant. Elite
  Dangerous, MinEdLauncher, 26.3 runtime behavior and FEX remain untested.
