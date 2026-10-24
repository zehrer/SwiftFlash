# Flash Card Reader Support (SD Card Readers)

## Overview
- Goal: Add first-class support for detecting and managing SD/flash card readers in SwiftFlash, alongside existing USB/external drives.
- Scope: Reader presence detection, card presence detection, basic capability reporting (e.g., SD/SDHC/SDXC, UHS), and UI surfacing; no advanced operations (e.g., card firmware or vendor-specific commands).
- Platform: macOS 26 target. Uses `DiskArbitration` and `IOKit` for on-device detection; optional JSON catalog for model enrichment.

## Why This Feature
- Some readers present as generic USB storage devices only when a card is inserted, making proactive reader identification valuable.
- Built-in Mac SD slots (Apple SDXC) can be detected even without a card; third-party readers vary by driver and exposure.
- Distinguishing “reader” from “drive” improves UX (e.g., showing a reader even if no card is inserted) and enables reader-specific messaging.

## Detection Strategy
### 1) DiskArbitration (Card presence via media)
- Enumerate `DADisk` objects to detect inserted media.
- Key properties to inspect:
  - `kDADiskDescriptionMediaRemovable` → `true` indicates removable media (likely SD).
  - `kDADiskDescriptionDeviceModel` and `kDADiskDescriptionDeviceVendor` → heuristics for known readers.
  - `kDADiskDescriptionDeviceProtocol` → may reveal `USB`, sometimes `Secure Digital` depending on driver.
- Pros: Stable, already used in app. Cons: Only shows a “device” when card is inserted; misses reader-only presence.

### 2) IOKit (Reader presence via IORegistry)
- Traverse IORegistry to identify services that correspond to SD/flash readers.
- Likely class names / paths (examples, may vary by hardware):
  - Built-in: `AppleSDXC` (common on Macs with SD slot) under `IOService` tree.
  - Generic USB readers: `IOUSBHostDevice` → child services for storage bridge; properties include `idVendor`, `idProduct`, `USB Product Name`.
  - Storage stack: `IOBlockStorageDevice`, `IOMedia` appear when a card is inserted; use these to correlate with DiskArbitration.
- Reader identification heuristics:
  - If a device exposes `AppleSDXC` or `IOSDHostDevice`-like classes → mark as card reader.
  - If `IOUSBHostDevice` vendor/product matches known reader catalog → mark as card reader.
  - If no card is present but a known reader service is visible → show reader with `isCardPresent = false`.

### 3) Fallback tooling (optional)
- `system_profiler SPUSBDataType -json`: parse to identify USB devices labeled as card readers; avoid frequent polling (expensive).
- `diskutil list -plist`: correlate inserted removable media with likely reader source.

## Reader Model Catalog (JSON)
Use a curated JSON file to enrich detection with human-friendly names and capabilities. Store under `Resources/CardReaderCatalog.json`.

### JSON Schema (example)
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "readers": [
    {
      "vendor_id": "0x05AC",
      "product_id": "0xXXXX",
      "vendor_name": "Apple",
      "product_name": "Apple SDXC Slot",
      "class_match": ["AppleSDXC", "IOSDHostDevice"],
      "capabilities": {
        "protocols": ["SD", "SDHC", "SDXC"],
        "max_speed": "UHS-II",
        "hotplug": true
      },
      "notes": "Built-in SD reader on certain Mac models"
    },
    {
      "vendor_id": "0xXXXX",
      "product_id": "0xYYYY",
      "vendor_name": "Generic",
      "product_name": "USB SD Card Reader",
      "class_match": ["IOUSBHostDevice"],
      "capabilities": {"protocols": ["SD", "SDHC"], "max_speed": "UHS-I"}
    }
  ]
}
```

### Loader and Matching
- Add `CardReaderCatalogLoader` to read and parse the JSON from app bundle.
- Matching logic:
  - Prefer exact `vendor_id` + `product_id` match from IORegistry properties (`idVendor`, `idProduct`).
  - Fallback to `class_match` on IOService class names when IDs are missing.
  - Merge catalog capabilities onto detected reader objects.

### Optional AI Enrichment
- For unknown readers (no catalog match):
  - Collect `idVendor`, `idProduct`, `USB Product Name`, and class names.
  - Use an offline enrichment step that queries public databases (e.g., `usb-ids`) or an AI helper to propose metadata.
  - Cache enriched entries locally and prompt the user to contribute updates (opt-in).

## Proposed Code Changes (High-Level)
These notes explain what to change; actual implementation is separate.

### New Models
- `CardReader`:
  - `id: UUID`
  - `name: String` (catalog/product name)
  - `vendorName: String?`
  - `vendorId: UInt16?`, `productId: UInt16?`
  - `isBuiltIn: Bool`
  - `isCardPresent: Bool`
  - `capabilities: CardReaderCapabilities?` (protocols, max speed)
  - `associatedDevices: [Device]` (correlated inserted media)
- `CardReaderCapabilities`:
  - `protocols: [String]` (e.g., SD/SDHC/SDXC)
  - `maxSpeed: String` (UHS-I/UHS-II)
  - `hotplug: Bool`

### Service Layer
- `CardReaderDetectionService` (new):
  - Imports `IOKit`.
  - Scans IORegistry for card-reader services on launch and on periodic refresh.
  - Publishes `[CardReader]` via `@Published` or `Combine`.
  - Correlates `DADisk` removable media to readers to set `isCardPresent` and populate `associatedDevices`.
  - Integrates `CardReaderCatalogLoader` for enrichment.

### Model Integration
- `DeviceType`:
  - Add `case cardReader` OR keep readers separate from `Device` to avoid mixing storage semantics with reader hardware.
  - Recommendation: Keep a parallel reader model (`CardReader`) separate from `Device`.
- `DeviceInventory`:
  - Track readers in parallel to devices: `@Published var cardReaders: [CardReader]`.
  - Provide helper to find reader by vendor/product/class for correlation.

### AppModel Wiring
- Add `@Published var cardReaders: [CardReader] = []`.
- Instantiate `CardReaderDetectionService`.
- Bridge service publisher: `cardReaderService.$readers.assign(to: &self.$cardReaders)`.
- Update refresh logic to call both drive and reader detection.

### UI Surfacing (no implementation here; for docs)
- New list view: `CardReaderListView` – shows reader name, vendor, and card presence state.
- Inspector view: `CardReaderInspectorView` – shows capabilities (protocols/max speed), reader class/ID match, and any associated devices.
- Sidebar grouping: “Drives” and “Card Readers” sections to clarify roles.

### Permissions & Security
- No special entitlements needed for enumeration via `IOKit` and `DiskArbitration`.
- Detection is read-only; no personal data from the card is accessed.

## Detection Heuristics (Details)
- Built-In SD Slot:
  - Look for `AppleSDXC` services under IORegistry.
  - Mark `isBuiltIn = true` and `isCardPresent` based on presence of `IOMedia` child or DiskArbitration media for the slot.
- USB Readers:
  - Inspect `IOUSBHostDevice` properties: `idVendor`, `idProduct`, `USB Product Name`.
  - Match against catalog; if no card, reader may still be visible (depends on power and driver).
  - When a card is inserted, `IOBlockStorageDevice` and `IOMedia` appear; reconcile with DiskArbitration `DADisk` entries.
- DiskArbitration Correlation:
  - For each removable `DADisk`, map `BSDName`/`DeviceModel` to candidate readers.
  - Prefer IORegistry-based correlation for accuracy.

## JSON Catalog Lifecycle
- Location: `SwiftFlash/Resources/CardReaderCatalog.json` bundled with the app.
- Loader: lazily loads and caches entries on app start.
- Updates: allow replacing or extending the JSON file; consider versioning.
- Unknown devices: create ephemeral entries and optionally persist enhanced metadata.

## Testing Strategy
- Unit tests:
  - Mock IORegistry queries (provide fake entries with `idVendor`, `idProduct`, class names).
  - Mock DiskArbitration results to simulate card insertion/removal.
  - Verify correlation logic populates `isCardPresent` and `associatedDevices`.
- UI tests:
  - Snapshot tests for empty, single reader, multiple readers, and card present/absent states.
- Hardware considerations:
  - Real-device tests are optional; rely on mocks to keep CI deterministic.

## Migration Plan
- Phase 1: Introduce `CardReaderDetectionService`, models, and basic UI list/inspector; ship initial JSON catalog.
- Phase 2: Correlate readers with devices in `DeviceInventory`; unify presentation in the sidebar/toolbars.
- Phase 3: Optional AI enrichment pipeline for unknown readers; user opt-in to share anonymized device metadata.

## macOS 26 Notes
- `DiskArbitration` and `IOKit` remain viable for user-space detection.
- Avoid heavy polling of `system_profiler`; prefer event-driven or periodic lightweight refresh via IORegistry.
- If future deprecations arise, consider `DriverKit`-based metadata exposure; for now, user-space IORegistry traversal suffices.

## Implementation Checklist (for developers)
- Add new files:
  - `Services/CardReaderDetectionService.swift`
  - `Models/CardReader.swift`, `Models/CardReaderCapabilities.swift`
  - `Resources/CardReaderCatalog.json`
  - `Services/CardReaderCatalogLoader.swift`
- Update existing:
  - `Models/DeviceInventory.swift` – track `cardReaders`.
  - `Models/DeviceType.swift` – optionally add `.cardReader`.
  - `Models/AppModel.swift` – wire the new service and publishers.
  - `Views/Components` – add list/inspector views.
- Add tests:
  - `SwiftFlashTests/CardReaderDetectionServiceTests.swift`
  - JSON loader tests with sample catalog.

---

This document describes the design and code changes needed to implement flash card reader support. It is safe to commit and iterate incrementally; no code changes are included here.

## Existing Code Behavior and Gaps
The current detection is centered in `Services/DriveDetectionService.swift` and the device data model in `Models/Device.swift`.

- What works now:
  - IOKit scans `kIOMediaClass` with `Removable` and `Ejectable` to find candidate media.
  - DiskArbitration enrichment pulls `DA` keys: vendor, revision, device model, media/volume names, protocol.
  - `DeviceInventory` persists devices with a stable `mediaUUID` and tracks last seen.
  - Partition enumeration provides volume name, filesystem, and mount point.
- What’s missing for SD card readers:
  - No explicit classification (`DeviceType`) is derived; most devices end up as `.unknown`.
  - Parent IORegistry traversal is used for product names but does not record vendor/product IDs for classification.
  - Readers often expose only reader info (vendor/product) and not card identity (CID/CSD). The app currently shows that reader info, which can be misleading when the goal is to identify the inserted SD card.

Conclusion: We cannot get true card identity on macOS for generic USB readers via public APIs. Instead, we should classify likely SD card media using reader heuristics and enrich from a vendor/product catalog.

## Classification Rules (Reader vs. Card Media)
Implement rule-based classification to set `DeviceType` and surface clear UI messaging.

1) IORegistry Parent Heuristics
- Walk parents of the `IOMedia` service:
  - If any parent class indicates SD (e.g., `AppleSDXC`, `IOSDHostDevice`) → mark as `cardReader`, and if media present → classify device as `.sdCard`.
  - If `IOUSBHostDevice` parent has `USB Product Name` containing keywords: `SD`, `Card Reader`, `Multi-Card`, `MMC` → classify as `.sdCard`.
  - Capture `idVendor` and `idProduct` for catalog matching.

2) DiskArbitration Hints
- If `DADeviceProtocol == "USB"` and `kDADiskDescriptionMediaRemovable == true`:
  - Combine with IOUSB parent hints to set `.sdCard`.
  - Use `DA` volume kind (`msdos`, `exfat`, `fat32`) and typical capacity ranges (8/16/32/64/128/256 GB) as weak signals.

3) Catalog Match (JSON)
- If parent `idVendor`+`idProduct` match an entry in `CardReaderCatalog.json`, set `.sdCard` and attach reader capabilities.
- If no match but parent name resembles a reader, set `.sdCard` with a “detected via heuristics” flag.

4) Built-in Slot (AppleSDXC)
- If `AppleSDXC` service is present even without media, show a reader entry with `isCardPresent = false` to clarify context.
  - When media appears (IOMedia), classify as `.sdCard` and associate with the built-in reader.

5) Negative Rules (avoid false positives)
- Large capacities with `externalHDD` connectors and no reader keywords → favor `.externalHDD`/`.externalSSD`.
- If DiskArbitration says `Device Model == "Disk Image"` → keep `isDiskImage = true`, never `.sdCard`.

UI messaging: clearly state when showing reader info versus card media info. Example: “SD Card in USB Reader (Vendor: XYZ)” and display volume label and file system for the card.

## Implementation Hooks in Current Code
Where to plug changes without destabilizing the app:

- `DriveDetectionService.getDeviceFromIOKit(service:)`:
  - After reading `props`, traverse parent chain once and capture:
    - `USB Product Name`, `idVendor`, `idProduct`, parent `IOClass` names.
  - Add a small classifier that returns a `DeviceType` based on the rules above and catalog match.
  - Pass the derived `deviceType` into `DeviceInventory.addOrUpdateDevice(...)` so the type persists.

- `Device` (model):
  - No structural changes required; use existing `deviceType` field.
  - Consider adding a non-persistent `readerHint` computed property derived from DA/IOKit to aid UI (“Likely SD reader: Generic XYZ”).

- `DeviceInventory`:
  - Already accepts `deviceType`; ensure we update it on detection rather than keeping `.unknown`.

- JSON Catalog Loader:
  - New `CardReaderCatalogLoader` in `Services` to parse `Resources/CardReaderCatalog.json`.
  - Provide a `match(vendorId:productId:classNames:) -> CardReaderCapabilities?` method for detection to use.

## Limitations and Honest Messaging
- True SD card identity (CID/CSD) is not exposed via standard USB Mass Storage APIs by most readers.
- Built-in Apple SDXC may expose IORegistry entries but typically not CID/CSD via public APIs.
- Therefore, the app should:
  - Classify media as “SD Card in Reader” using the heuristics above.
  - Display card-facing info we do have: capacity, filesystem, volume label, partition scheme.
  - Avoid claiming personal/device-unique identity unless we explicitly implement vendor-specific paths.

## Concrete Steps (Tie-back to Code)
1) Add parent traversal helpers to `DriveDetectionService`:
   - `getParentUSBInfo(service:) -> (vendorId: UInt16?, productId: UInt16?, productName: String?, classNames: [String])`
   - Cache in local scope during detection and feed into classifier.
2) Implement `classifyDeviceType(daDesc: [String:Any]?, parentInfo: ParentUSBInfo, size: Int64) -> DeviceType`.
3) Introduce `CardReaderCatalog.json` and `CardReaderCatalogLoader`.
4) Update inventory writes to persist `deviceType`.
5) Update views to reflect classification and reader context (no code in this note, but document changes in UI specs).

With these changes, detection remains lightweight and stateless, but classification conveys “reader vs. card” context and sets accurate expectations about available card metadata.