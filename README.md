# hyperwin-dxvk

Multi-version Android HwD3D DXVK build & port repository for **HyperWin**.

- **`main` branch**: Android NDK Meson cross-build harness, HwD3D ABI 1 patch (`patches/dxvk-android.patch`), and packaging scripts for any DXVK 2.1+ (`dxvk-native`) release or fork.
- **Version / fork branches** (e.g. `sarek`): Full Android `dxvk-native` + HwD3D ports for DXVK forks that don't ship `dxvk-native` upstream.

## Building

### Upstream DXVK 2.1+ (from `main`)
```bash
./build.sh upstream v2.7.1
./build.sh upstream v2.4.1 https://github.com/doitsujin/dxvk.git
```

### Ported branch (e.g. `sarek`)
```bash
git checkout sarek
./build.sh
```

Outputs a HyperWin-ready zip in `out/` containing `meta.json` (`abi: 1`) and 16 KB page-aligned stripped `libdxvk_*.so` libraries.

## Installing to a connected phone
```bash
./install-to-phone.sh out/dxvk-sarek-v1.14.1.zip
```
