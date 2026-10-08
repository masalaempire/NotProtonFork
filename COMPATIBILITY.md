# Sequoia / CrossOver 26.1 compatibility port

This is an experimental Apple Silicon / Rosetta port of NotProton 1.0.3 for
macOS Sequoia 15.0+ and **CrossOver 26.1, build 26.1.0.39808**.
It is not yet verified by launching a Windows game through Steam.

## Delivered app

`out/NotProton.app` is an ad-hoc signed, self-contained release build.
`out/NotProton-Sequoia-CrossOver26.1.zip` contains that app.
Open the app, check that it recognizes CrossOver 26.1 Rosetta, and use its normal
Install / Set Up Compatibility Tool workflow. The existing CrossOver activation
check is retained. Steam must still be a build supported by NotProton's signature
database; this port does not make arbitrary Steam versions compatible.

The work here did not install the integration into Steam or modify the installed
CrossOver application. The app's setup workflow makes and patches a runner copy.

## What changed

- App deployment target and Info.plist minimum: macOS 15.0.
- Use ordinary SwiftUI toolbars, which build with the installed Xcode 26.2 SDK.
- Ship the upstream classic ICNS; newer Icon Composer metadata failed with this SDK.
- Resolve the resource bundle from Contents/Resources before SwiftPM's build-path
  fallback, and accept both old and new SwiftPM bundle layouts when packaging.
- Add exact loader, original DLL, patched DLL and detour SHA-256 pins for retail
  build 26.1.0.39808. Unknown builds remain rejected.
- Generate new 32-bit and 64-bit detours. Both DLLs need a new executable `.npdet`
  section rather than the Preview builds' padding caves.
- Retail Wine's 32-bit build_module argument uses DONT_RESOLVE_DLL_REFERENCES (1),
  distinct from LDR_DATA_TABLE_ENTRY.Flags' LDR_DONT_RESOLVE_REFS (2). The new
  detour uses the correct mask in each flag space. The resolver permits mask 1
  only for this exact retail DLL hash. Existing Preview payloads are unchanged.
- Explicitly export MACOSX_DEPLOYMENT_TARGET=15.0 when building Wine host code and
  lsteamclient. The official release's x86_64 lsteamclient.so declared macOS 27.0;
  changing the app's plist alone would not address this.
- Disable the upstream updater to prevent replacement with the incompatible
  upstream app. A future fork update feed must be configured deliberately.

Wine 11.0's flag handling can also be inspected in
[the upstream loader source](https://github.com/wine-mirror/wine/blob/wine-11.0/dlls/ntdll/loader.c).
The patch locations and register/frame choices were resolved from the installed
CrossOver binaries, not inferred from that source alone.

## Validation performed on October 8, 2026

- Release app builds; executable and rebuilt x86_64 bridge declare macOS 15.0.
- App passes `codesign --verify --strict` (ad-hoc signing, not notarization).
- All 371 Swift tests pass, including opt-in tests applying the real retail DLL
  patches in memory, checking exact output hashes, and refusing a second patch.
- Both resolver self-tests reproduce the pinned values.
- The rebuilt x86_64 bridge loads with RTLD_NOW against the installed retail
  CrossOver 26.1 ntdll.so on Sequoia, and exposes the Wine entry table.
- No end-to-end Steam game launch, overlay, achievement, controller or save test.
  The bridge-load check is only a dynamic-linking check, not full Wine ABI proof.
- FEX on Sequoia is outside this port's scope. Its upstream payload is retained.

## Build provenance and reproduction

The staged payload starts with the official
[NotProton v1.0.3 release](https://github.com/NotProtonNot/NotProton/releases/tag/v1.0.3).
The downloaded NotProton.zip SHA-256 is:

    972a5f41ab861b287ae173ef57fadc8ebcecd5e98cae0806e33ad1e57617ab24

Its payload directory was copied to `app/Sources/NotProtonApp/Resources/payload`.
The x86_64-unix-lsteamclient.so was then replaced with a source rebuild; the other
runtime components remain from that release. The classic ICNS is also from that
release. Payloads and downloaded sources are ignored build artifacts.

Source pins for the rebuilt bridge:

- Wine 11.15: `2df1ee28039cf84776eb1421ed90bd154cebb65f`
- Valve Proton: `164e0ccd2ea2b1ec2e5d08dc97f65b184c2539ca`
- Local lsteamclient overlays are applied by `lsteamclient/fetch.sh`.

For a fresh reproduction, extract the verified release and stage its payload as
above, install MinGW-w64, bison and flex, then run these commands from the repo:

```sh
WINE_URL=https://github.com/wine-mirror/wine.git \
  WINE_SRC="$PWD/scratch/wine-github" sh bridge/setup-wine-tree.sh
WINE_SRC_REL=../wine-github sh lsteamclient/build.sh --unix
cp scratch/wine-build-dual/dlls/lsteamclient/lsteamclient.so \
  app/Sources/NotProtonApp/Resources/payload/bridge/x86_64-unix-lsteamclient.so
make app-staged
NP_TEST_CROSSOVER_261=/Applications/CrossOver.app swift test --package-path app
```

Stage the payload before the first SwiftPM build; if a build was started without
it, use a fresh scratch directory so the cached conditional manifest is refreshed.
`make app` remains the full source-build route, including the FEX bridge and Dobby.
Do not reuse Wine/object build directories previously compiled for macOS 26/27.

The checked-in detour binaries can be regenerated with Python Capstone 5.0.9 and
MinGW-w64 (this build used Homebrew mingw-w64 14.0.0_3):

```sh
sh ntdll-patch/build.sh \
  /Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/x86_64-windows/ntdll.dll 39808
sh ntdll-patch/build32.sh \
  /Applications/CrossOver.app/Contents/SharedSupport/CrossOver/lib/wine/i386-windows/ntdll.dll 39808
```

The scripts check the generated payload hashes. A compiler change may alter them;
do not replace pins without inspecting and revalidating the new output.
`bridge/load-check.c` is the small read-only dlopen probe used for the bridge check.
