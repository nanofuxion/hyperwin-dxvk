# hyperwin-dxvk

Android arm64 HwD3D DXVK build harness for **HyperWin** (ABI 1).

Supports building HyperWin-ready `.zip` bundles from both **upstream DXVK (2.1+)** and **DXVK-Sarek** by tag/version or custom fork URL.

## Requirements

- Android NDK (r27+ recommended; set `ANDROID_NDK` or `ANDROID_HOME`)
- `git`, `meson`, `ninja`, `zip`, `python3`

## Building

### Upstream DXVK 2.1+
```bash
./build.sh upstream v2.7.1
./build.sh upstream v2.4.1 https://github.com/doitsujin/dxvk.git
```

### DXVK-Sarek
```bash
./build.sh sarek v1.14.1
./build.sh sarek v1.14.1 https://github.com/pythonlover02/DXVK-Sarek.git
```

Both commands clone the requested tag into `work/`, apply the HyperWin Android WSI / HwD3D patches (`patches/dxvk-android.patch` for upstream, `overlays/sarek/` + `patches/sarek-android.patch` for Sarek), cross-compile for Android `arm64-v8a`, and output a HyperWin-ready zip in `out/` containing `meta.json` (`abi: 1`) and 16 KB page-aligned stripped `libdxvk_*.so` libraries.

## Installing in HyperWin

Either import the generated `.zip` directly in HyperWin (**Settings → Graphics → DXVK → Import**), or push it over `adb` to a debug build:

```bash
./install-to-phone.sh out/dxvk-sarek-v1.14.1.zip
```
