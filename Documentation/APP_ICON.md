# AwakeCat application icon

## Direction

The selected icon is a calm, alert cat rendered as one softly geometric graphite form. Upright ears and two small open eyes preserve the same “eyes open = Awake” identity used by the menu-bar glyph, while the restrained material depth makes the full-size artwork suitable for Finder, Get Info, Launchpad, and login-item identity surfaces.

Two earlier directions were rejected: a light porcelain face read too much like an emoji, while a sharp negative-space mask looked aggressive and game-like. The final direction keeps the strong small-size silhouette of the latter but softens the contour and replaces the angled eyes with quiet circular eyes.

The artwork uses only black, off-white, charcoal, and neutral gray. Every exported PNG is flattened RGB with no alpha channel; the background is intentionally rendered across the full canvas.

## Assets

`Resources/Assets.xcassets/AppIcon.appiconset` contains the ten standard macOS icon slots:

- 16 pt at 1x and 2x
- 32 pt at 1x and 2x
- 128 pt at 1x and 2x
- 256 pt at 1x and 2x
- 512 pt at 1x and 2x

`AppIcon_512x512@2x.png` is the 1024-pixel master representation. All smaller representations were resampled directly from the selected generated master rather than successively downscaling one another.

## Appearance behavior

AwakeCat v0.1 uses one dark, opaque **Any appearance** icon. The same source is used in Light and Dark appearance. This is the deliberate fallback requested for a project where clean dynamic application-icon switching would add asset-pipeline complexity without improving reliability.

macOS 26 also has a separate system-wide **Icon & widget style** setting. When the user selects the system `Tinted` style, macOS may recolor application icons globally; that platform treatment is outside AwakeCat's asset palette. With the system icon style set to `Default`, the authored black/white/gray artwork is preserved in both Light and Dark appearance.

## Bundle integration

The canonical `script/build_and_run.sh` pipeline runs Xcode's supported `actool` against `Resources/Assets.xcassets`. It selects `AppIcon`, emits `Assets.car` and the compatibility `AppIcon.icns`, generates the partial icon Info.plist, and merges `CFBundleIconName` and `CFBundleIconFile` into the staged application's Info.plist before code signing.

The resulting bundle contains:

```text
AwakeCat.app/Contents/Resources/Assets.car
AwakeCat.app/Contents/Resources/AppIcon.icns
```

The app icon is independent from `CatStatusIcon.swift`. The menu-bar glyph remains a programmatic monochrome template image with its existing Normal, Awake, and Error eye states.

## Visual evidence

- [Finder, Light appearance](Screenshots/AppIcon_Finder_Light_Final.png)
- [Get Info, Light appearance](Screenshots/AppIcon_GetInfo_Light.png)
- [Get Info, Dark appearance with Default icon style](Screenshots/AppIcon_GetInfo_Dark.png)

The host's original appearance settings (`Appearance: Auto`, `Icon & widget style: Tinted`) were restored after capture.

## Validation

- Clean Debug bundle build: passed; `actool` emitted no warning or error.
- Clean Release bundle build: passed; `actool` emitted no warning or error.
- Runtime launch: passed for both configurations.
- Core tests: 8 passed, 0 failed.
- Bundle metadata: `CFBundleIconName = AppIcon` and `CFBundleIconFile = AppIcon`.
- Bundle resources: non-empty `Assets.car` and `AppIcon.icns` present before signing.
- Asset inspection: `assetutil` reported all ten `AppIcon` renditions as RGB and `Opaque: true`.
- ICNS inspection: `iconutil` successfully unpacked all ten standard representations.
- Signing: `codesign --verify --deep --strict` passed.
- Finder and Get Info: verified in Light and Dark appearance; the authored palette was checked in Dark with the system icon style temporarily set to `Default`.
- Menu-bar regression: the existing Debug UI hook clicked the real `NSStatusItem.button`; AwakeCat acquired both named assertions, and termination released both.

## Generation provenance

The final master was created with the built-in image generation tool, then exported into the deterministic asset-catalog size matrix. The selected revision used this edit prompt:

```text
Use case: precise-object-edit
Asset type: final macOS application icon master artwork, 1024 by 1024 square
Input image: edit target, the existing dark geometric cat icon
Primary request: Keep the centered dark graphite cat-head concept and full-bleed opaque dark background, but make the expression calm and quietly alert rather than aggressive. Replace the slanted glowing eye cutouts with two small, restrained, symmetrical off-white circular or softly oval open eyes, matching the AwakeCat menu-bar language. Soften the cat-head contour, ear corners, lower cheek and chin geometry into subtly rounded Apple-native utility forms. Reduce game-badge sharpness and heavy realism; use cleaner solid tonal layers with only restrained sculpted depth.
Constraints: change only expression, contour softness, and material restraint; keep black/white/neutral gray palette; preserve centered symmetry, generous optical padding, strong 16 px silhouette, fully opaque flattened square artwork with every pixel filled; no transparency, no text, no letters, no watermark, no whiskers, no fur, no mouth, no extra symbols.
Avoid: angry eyes, predatory expression, anime, emoji, childish mascot, sticker aesthetic, neon, color cast, excessive gloss, excessive texture, heavy shadow, mockup presentation, device frame.
```
