# Application icon

AwakeCat uses a dark graphite cat with two quiet open eyes, separate from the programmatic monochrome menu-bar glyph in `CatStatusIcon.swift`. The application icon is the same in Light and Dark appearance; macOS may apply its optional system-wide icon tint.

## Source and build pipeline

`Resources/Assets.xcassets/AppIcon.appiconset` contains the ten standard macOS slots: 16, 32, 128, 256, and 512 points, each at 1x and 2x. `AppIcon_512x512@2x.png` is the 1024-pixel master representation. Smaller images were resampled directly from the selected master. Every source PNG is opaque RGB.

`script/build_and_run.sh` uses Xcode's `actool` to produce `Assets.car`, `AppIcon.icns`, and a partial Info.plist. It merges `CFBundleIconName` and `CFBundleIconFile` into the app metadata before signing. No icon-generation service is needed to build or run AwakeCat.

## Provenance and licensing

The original implementation record identifies the master as artwork created for AwakeCat with OpenAI's built-in image generation tool, then refined from an earlier generated cat design. No stock image, external font, downloaded icon pack, or separately licensed reference asset is recorded or bundled. The generation request specified a symmetric graphite cat, restrained off-white eyes, an opaque background, and no text, watermark, or extra symbols.

The project makes its rights, if any, in the generated artwork available under the root [MIT License](../LICENSE). This does not claim ownership of third-party material or guarantee exclusive copyright in AI-generated imagery. OpenAI's [Terms of Use, Content section](https://openai.com/policies/row-terms-of-use/) describe the assignment of its rights, if any, in generated output to the user, subject to applicable law. The provenance audit found no identified incompatible third-party material.

Historical Finder/Get Info screenshots were removed from the current tree because they included machine-specific paths and added little to the build instructions. The original commits retain that visual validation history; Apple interface elements in those historical screenshots remain Apple's material, not project-owned artwork.

## Validation

The source size matrix, opacity, compiled asset renditions, ICNS representations, bundle metadata, and code signature are checked during publication validation. The original 2026-08-24 record also reports Finder/Get Info inspection in Light and Dark appearance. See [VALIDATION.md](VALIDATION.md) for current checks and historical boundaries.
