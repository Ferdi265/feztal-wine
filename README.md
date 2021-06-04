# `feztal-wine`

A simple script that manages a wine prefix for FEZTAL.

## Usage

```
usage: feztal-wine.sh [command]

commands:
 - run ............. run FEZTAL
 - install ......... download FEZTAL and prepare wine prefix
 - update .......... update FEZTAL to the latest version
 - uninstall ....... remove FEZTAL wine prefix
 - install-dxvk .... install DXVK into the wine prefix
 - update-dxvk ..... update DXVK in the wine prefix
 - uninstall-dxvk .. uninstall DXVK from the wine prefix
```

## Installation

Just put the script anywhere you would like to run it from. The default
installation directory is `~/.local/share/feztal`.

Then, run `feztal-wine.sh install` to set up the prefix and install FEZTAL.
Updated versions (if any updates are released) can be installed by running
`feztal-wine.sh update`.

The download is currently manual, the script will pause and tell you where to
place FEZTAL.zip

## Updating

You can update FEZTAL with `feztal-wine.sh update`. This will
update the game if a newer version exists.

The download is currently manual, the script will pause and tell you where to
place FEZTAL.zip

DXVK can be updated by running `feztal-wine.sh update-dxvk`.

## Uninstalling

FEZTAL can be uninstalled by running
`feztal-wine.sh uninstall`. This removes the whole wine prefix.

DXVK can be uninstalled separately with `feztal-wine.sh uninstall-dxvk`, though
this can be done more cleanly by just uninstalling and reinstalling using
`feztal-wine uninstall && feztal-wine.sh install`.

## Environment Variables

`feztal-wine` can be configured via several environment variables:

- `FEZTAL_INSTALL_DIR` controls where the game's files will be stored (defaults to
  `~/.local/share/feztal`)
- `FEZTAL_LOG_DEBUG` controls whether `debug` log messages are displayed (defaults
  to `1`)

There are also several advanced configuration variables that shouldn't normally
be needed:

- `FEZTAL_FORCE_INSTALL` disables checking whether a new version is available when
  set to `1` and always reinstalls the latest version (defaults to `0`)
- `DXVK_RELEASE_URL` controls the URL where the version information JSON for new
  releases of DXVK is retrieved from (defaults to
  https://api.github.com/repos/doitsujin/dxvk/releases/latest)

## Dependencies

This script needs the following programs to work:

- `wine`
- `curl`
- `jq`
- `tar`
- `unzip`
- `mktemp` (part of GNU coreutils)
