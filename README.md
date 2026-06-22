# chdman

Unofficial Termux installer for building MAME's `chdman` on Android, with a small helper script for converting `.iso`, `.cue`, and `.gdi` files to `.chd`.

## Install

Run inside Termux:

```bash
curl -sSL "https://raw.githubusercontent.com/snwkkj/chdman/main/chdman-install.sh" | bash
```

The installer builds `chdman` from the official MAME source and installs the command globally:

```bash
chdman
```

It also creates:

```text
~/storage/shared/CHDMan/
  iso2chd.sh
  chdman-install.log
```

## Convert

Copy your disc images into `~/storage/shared/CHDMan`, then run:

```bash
cd ~/storage/shared/CHDMan
bash iso2chd.sh
```

Or convert a specific file/folder:

```bash
bash iso2chd.sh /sdcard/Download/game.iso
bash iso2chd.sh /sdcard/Download/ISOS
```

Converted files are saved to:

```text
~/storage/shared/CHDMan/converted
```

## Options

```bash
JOBS=1 bash chdman-install.sh                 # lower memory usage
MAME_REF="mame0280" bash chdman-install.sh    # build a specific MAME tag
CHDMAN_CLEAN_BUILD=0 bash chdman-install.sh   # keep build files
CHDMAN_OUT_DIR=/sdcard/CHD bash iso2chd.sh    # custom output folder
```

## Credits

`chdman` is part of the official [MAME](https://github.com/mamedev/mame) project, developed by MAMEdev and contributors.

This repository is not affiliated with or endorsed by the MAME project. It only provides a Termux installer and helper script.

## License

This repository is licensed under the MIT License. See [LICENSE](LICENSE).

For MAME licensing, see the official MAME license documentation: https://docs.mamedev.org/license.html
