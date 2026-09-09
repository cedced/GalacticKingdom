# Third-party ship asset sources

Required by `assets/README.md` (Naming conventions): every asset taken from a
pack records its original filename here so it can be traced back.

## 3D_spaceships_pack

- Pack folder: `assets/dump/3D_spaceships_pack/` (previews remain there as numbered `.gif` files)
- Author: unknown — fill in
- License: **unknown — confirm redistribution is allowed before any exported build ships these models** (open question in `assets/README.md`)

| Original | Assigned ID | Milestone |
|---|---|---|
| `34.glb` | `merchant_mk1` | M0 starter hull |

Modifications to `merchant_mk1.glb` (applied to the source file, per the "fix at
source, not in the scene tree" rule):

- Root node rotated 180° around +Y (quaternion `[0, 1, 0, 0]`) because the pack
  models face +Z; glTF/Godot forward is -Z. The rest of the pack likely needs
  the same fix at M2 triage.

Remaining hulls in the pack are untriaged; triage happens at M2 when the
starbase shop needs a lineup (checklist in `assets/README.md`).
