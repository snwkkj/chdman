# chdman

`chdman` is a small unofficial Termux installer for building MAME's `chdman` tool on Android and converting disc images to CHD.

It installs the required build tools, downloads the MAME source code, compiles `chdman`, and creates a ready-to-use `iso2chd.sh` converter script.

## Features

- Builds `chdman` directly inside Termux
- Converts `.iso`, `.cue`, and `.gdi` files to `.chd`
- Supports converting one file or a whole folder
- Stores converted files in a dedicated output directory
- Lets you use the installer and converter as separate scripts
- Works well with `curl -sSL ... | bash`

## Requirements

- Android with Termux installed
- Internet connection
- Enough free storage for the MAME source and build files
- Patience: compiling on a phone can take a while

The installer installs the build dependencies it needs, including Clang, Make, Ninja, Fontconfig, Git, Python, compression libraries, and SDL2 from the Termux X11 repository.

Install Termux from F-Droid or the official GitHub releases. The Play Store version is outdated and may not work correctly.

## Quick Install

Run this inside Termux:

```bash
curl -sSL "https://raw.githubusercontent.com/snwkkj/chdman/main/chdman-install.sh" | bash
```

After installation, this project creates:

```text
~/storage/shared/CHDMan/
  iso2chd.sh
  chdman-install.log
```

It also creates a global Termux command:

```text
chdman
```

The global `chdman` command is copied into Termux's binary directory, not symlinked from shared storage. This avoids Android shared-storage execution restrictions.

The install directory is based on where you run the installer:

- If you run it from a folder, it creates `CHDMan` inside that folder.
- If you run it from Termux home or `~/storage`, it uses `~/storage/shared/CHDMan`.
- It does not install in the Termux home directory by default.

## Usage

Copy your disc images into `~/storage/shared/CHDMan`, then run:

```bash
cd ~/storage/shared/CHDMan
bash iso2chd.sh
```

Convert a single file:

```bash
cd ~/storage/shared/CHDMan
bash iso2chd.sh /sdcard/Download/game.iso
```

Convert multiple files:

```bash
bash iso2chd.sh /sdcard/Download/game1.iso /sdcard/Download/game2.cue
```

Convert every supported file inside a folder:

```bash
bash iso2chd.sh /sdcard/Download/ISOS
```

Converted files are saved by default in:

```text
~/storage/shared/CHDMan/converted
```

The `converted/` folder is created only when `iso2chd.sh` runs.

The installer writes a full log to:

```text
~/storage/shared/CHDMan/chdman-install.log
```

If you run the installer from another folder, the log is saved inside the `CHDMan` folder created there.

## Download Only the Converter

If you already have `chdman`, you can download only `iso2chd.sh`:

```bash
curl -sSL "https://raw.githubusercontent.com/snwkkj/chdman/main/iso2chd.sh" -o iso2chd.sh
chmod +x iso2chd.sh
```

By default, the converter looks for `chdman` at:

```text
Termux's global chdman command
```

You can point it to another binary with `CHDMAN_BIN`:

```bash
CHDMAN_BIN=/path/to/chdman bash iso2chd.sh game.iso
```

## Custom Output Folder

Use `CHDMAN_OUT_DIR` to choose where converted files are saved:

```bash
CHDMAN_OUT_DIR=/sdcard/CHD bash iso2chd.sh /sdcard/Download/game.iso
```

## Custom Install Paths

The installer supports a few environment variables:

```bash
CHDMAN_DIR="$HOME/storage/shared/CHDMan" # Final install directory
CHDMAN_BUILD_DIR="$PREFIX/tmp/chdman-build" # Build directory
MAME_REF="master"                      # MAME branch or tag
JOBS="2"                               # Parallel build jobs
CHDMAN_CLEAN_BUILD="1"                 # Remove build files after install
```

Example:

```bash
MAME_REF="mame0280" JOBS=2 bash chdman-install.sh
```

## Supported Input Formats

`iso2chd.sh` currently accepts:

- `.iso`
- `.cue`
- `.gdi`

It uses:

```bash
chdman createcd -i input -o output.chd
```

## Notes

This project builds `chdman` from the official MAME source code. `chdman` itself is part of MAME.

This repository is not affiliated with, endorsed by, or maintained by the MAME project.

Large builds can fail if your device runs out of memory. If that happens, try lowering the number of jobs:

```bash
JOBS=1 bash chdman-install.sh
```

Build files are removed after a successful install by default. To keep them for debugging:

```bash
CHDMAN_CLEAN_BUILD=0 bash chdman-install.sh
```

If Termux shows `CANNOT LINK EXECUTABLE "curl"` or `git-remote-https` errors, your packages are likely partially upgraded. Fix Termux first, then run the installer again:

```bash
apt update
apt full-upgrade -y
```

If `apt full-upgrade` stops at a configuration file prompt such as `openssl.cnf`, use a non-interactive upgrade:

```bash
DEBIAN_FRONTEND=noninteractive dpkg --configure -a \
  --force-confdef \
  --force-confold

DEBIAN_FRONTEND=noninteractive apt full-upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"
```

If you see `No rule to make target 'chdman'` or `No rule to make target 'tools'`, update `chdman-install.sh` from this repository and run the installer again. Older installer versions used outdated MAME build targets.

## Credits

- `chdman` is part of the official [MAME](https://github.com/mamedev/mame) project.
- MAME is developed by MAMEdev and contributors.
- This repository only provides a Termux installer and helper script around the official MAME source.

For MAME licensing details, see the official MAME license documentation: https://docs.mamedev.org/license.html

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
