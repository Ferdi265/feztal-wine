#!/bin/bash

# script installation location
SCRIPT_FILE="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_FILE")"

# environment variable defaults
FEZTAL_INSTALL_DIR=${FEZTAL_INSTALL_DIR:-"$HOME/.local/share/feztal"}
FEZTAL_ARCH=${FEZTAL_ARCH:-}
FEZTAL_LOG_DEBUG=${FEZTAL_LOG_DEBUG:-1}
FEZTAL_FORCE_ARCH=${FEZTAL_FORCE_ARCH:-0}
FEZTAL_LOG_DEBUG=${FEZTAL_LOG_DEBUG:-1}
DXVK_RELEASE_URL=${DXVK_RELEASE_URL:-"https://api.github.com/repos/doitsujin/dxvk/releases/latest"}

# output color variables
# (see 'man console_codes', section 'ECMA-48 Set Graphics Rendition')
R=$'\e[1;31m'
G=$'\e[1;32m'
Y=$'\e[1;33m'
B=$'\e[1;34m'
W=$'\e[1;37m'
N=$'\e[0m'

# utility functions

log-error() {
    echo "${R}error:${N} $1"
}

log-warn() {
    echo "${Y}warn:${N} $1"
}

log-info() {
    echo "${W}info:${N} $1"
}

log-debug() {
    if [[ $FEZTAL_LOG_DEBUG -eq 1 ]]; then
        echo "${B}debug:${N} $1"
    fi
}

check-installed() {
    type -p "$1" >/dev/null
    if [[ $? -ne 0 ]]; then
        log-error "the '$1' command is missing!"
        MISSING_PROGRAMS=1
    fi
}

noisy-rm-dir() {
    if [[ -d "$1" ]]; then
        log-debug "removing '$1'"
        rm -rf "$1"
    fi
}

noisy-rm-empty-dir() {
    if [[ -d "$1" ]]; then
        log-debug "removing '$1'"
        rmdir "$1"
    fi
}

noisy-rm-file() {
    if [[ -f "$1" ]]; then
        log-debug "removing '$1'"
        rm -f "$1"
    fi
}

TEMP_DIR_LIST=()
create-temp-dir() {
    TEMP_DIR=$(mktemp -d -t 'feztal.tmp.XXXXXXXXXX')
    TEMP_DIR_LIST+=( "$TEMP_DIR" )
    trap cleanup-create-temp-dir EXIT

    log-debug "creating temporary directory '$TEMP_DIR'"
}

cleanup-create-temp-dir() {
    log-debug "removing temporary files"

    for TEMP_DIR in "${TEMP_DIR_LIST[@]}"; do
        noisy-rm-dir "$TEMP_DIR"
    done
}

make-workaround-reg() {
    cat > "$1" <<EOF
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Wine\X11 Driver]
"UseTakeFocus"="N"
EOF
}

check-wine-arch() {
    log-debug "checking wine architecture"

    if [[ -f "$FEZTAL_INSTALL_DIR/winearch" ]]; then
        INSTALLED_ARCH="$(cat "$FEZTAL_INSTALL_DIR/winearch")"

        if [[ -z "$FEZTAL_ARCH" ]]; then
            FEZTAL_ARCH="$INSTALLED_ARCH"
            log-debug "using installed architecture '$FEZTAL_ARCH'"
        elif [[ "$FEZTAL_ARCH" != "$INSTALLED_ARCH" ]]; then
            log-error "installed architecture '$INSTALLED_ARCH' doesn't match FEZTAL_ARCH '$FEZTAL_ARCH'"

            if [[ "$FEZTAL_FORCE_ARCH" -eq 1 ]]; then
                log-warn "forcing use of architecture from FEZTAL_ARCH '$FEZTAL_ARCH'"
            else
                exit 1
            fi
        fi
    elif [[ -z "$FEZTAL_ARCH" ]]; then
        FEZTAL_ARCH=win32
        log-debug "defaulting to architecture '$FEZTAL_ARCH'"
    else
        log-debug "using architecture from FEZTAL_ARCH '$FEZTAL_ARCH'"
    fi
}

fetch-feztal-zip() {
    log-debug "downloading FEZTAL"

    # TODO: find way to automatically download
    log-warn "automatic download not implemented!"
    while [[ ! -f "$1" ]]; do
        log-info "please download FEZTAL manually and move FEZTAL.zip to $1"
        log-info "press enter when done, write 'cancel' to cancel"

        read line
        if [[ "$line" == "cancel" ]]; then
            log-error "download canceled"
            exit 1
        elif [[ "$line" == "" || "$line" == "ok" ]]; then
            true
        else
            log-warn "unknown answer '$line', expected empty, 'ok', or 'cancel'"
        fi
    done
}

fetch-dxvk-installer() {
    log-debug "getting latest release URL"
    RELEASE_JSON="$(curl --silent "$DXVK_RELEASE_URL")"
    RELEASE_URL="$(jq -r '.assets[].browser_download_url' <<< "$RELEASE_JSON" | head -n1)"
    RELEASE_VERSION="$(jq -r '.tag_name' <<< "$RELEASE_JSON")"

    if [[ "$RELEASE_JSON" == "" ]]; then
        log-error "failed to get latest release information"
        exit 1
    fi

    if [[ "$RELEASE_URL" == "" ]]; then
        log-error "failed to extract release URL from latest release information"
        exit 1
    fi

    if [[ "$RELEASE_VERSION" == "" ]]; then
        log-error "failed to extract version number from latest release information"
        exit 1
    fi

    log-info "latest DXVK version is $RELEASE_VERSION"
    if [[ -f "$FEZTAL_INSTALL_DIR/dxvk-version" ]]; then
        CURRENT_VERSION="$(cat "$FEZTAL_INSTALL_DIR/dxvk-version")"

        log-info "current DXVK version is $CURRENT_VERSION"

        if [[ "$RELEASE_VERSION" == "$CURRENT_VERSION" ]]; then
            log-info "DXVK is up to date"

            if [[ "$FEZTAL_FORCE_INSTALL" -eq 1 ]]; then
                log-warn "forcing reinstallation"
            else
                exit 0
            fi
        fi
    fi

    log-debug "downloading latest release"
    curl -L -o "$1" "$RELEASE_URL"

    if [[ $? -ne 0 ]]; then
        log-error "failed to download latest release"
        exit 1
    fi
}

feztal-run-in-prefix() {
    mkdir -p "$FEZTAL_INSTALL_DIR/prefix"
    WINEARCH="$FEZTAL_ARCH" WINEPREFIX="$FEZTAL_INSTALL_DIR/prefix" "$@"
}

feztal-wine() {
    feztal-run-in-prefix wine "$@"
}

# check for needed programs

MISSING_PROGRAMS=0
check-installed wine
check-installed curl
check-installed jq
check-installed tar
check-installed unzip
check-installed mktemp

if [[ $MISSING_PROGRAMS -ne 0 ]]; then
    log-error "aborting due to missing required commands"
    exit 1
fi

# check variables for validity

if [[ -n "$FEZTAL_ARCH" && "$FEZTAL_ARCH" != "win32" && "$FEZTAL_ARCH" != "win64" ]]; then
    log-error "invalid wine architecture '$FEZTAL_ARCH'"
    exit 1
fi

# commands

feztal-run() {
    if [[ ! -d "$FEZTAL_INSTALL_DIR/prefix" ]]; then
        log-error "feztal-wine is not installed, please install first"
        exit 1
    fi

    log-info "running feztal-wine"

    check-wine-arch

    mkdir -p "$FEZTAL_INSTALL_DIR/cache"

    (
        cd "$FEZTAL_INSTALL_DIR/cache"
        feztal-wine "C:/FEZTAL/FEZTAL.exe"
    )
}

feztal-install() {
    if [[ -e "$FEZTAL_INSTALL_DIR/prefix" ]]; then
        log-error "feztal-wine is already installed"

        if [[ "$FEZTAL_FORCE_INSTALL" -eq 1 ]]; then
            log-warn "forcing reinstallation"
        else
            exit 1
        fi
    fi

    log-info "installing feztal-wine"

    check-wine-arch

    log-debug "creating wine prefix"
    feztal-wine wineboot

    log-debug "saving wine architecture"
    echo "$FEZTAL_ARCH" > "$FEZTAL_INSTALL_DIR/winearch"

    log-debug "setting windows version to win7"
    feztal-wine winecfg /v win7

    create-temp-dir

    log-debug "setting workaround registry keys"
    make-workaround-reg "$TEMP_DIR/workaround.reg"
    feztal-wine regedit /C "$TEMP_DIR/workaround.reg"

    fetch-feztal-zip "$TEMP_DIR/FEZTAL.zip"

    log-info "unpacking feztal zip"
    mkdir -p "$FEZTAL_INSTALL_DIR/prefix/drive_c/FEZTAL/"
    unzip -d "$FEZTAL_INSTALL_DIR/prefix/drive_c/FEZTAL" "$TEMP_DIR/FEZTAL.zip"

    log-info "finished installing feztal-wine"
}

feztal-update() {
    if [[ ! -d "$FEZTAL_INSTALL_DIR/prefix" ]]; then
        log-error "feztal-wine is not installed, please install first"
        exit 1
    fi

    log-info "updating feztal-wine"

    check-wine-arch

    create-temp-dir

    fetch-feztal-zip "$TEMP_DIR/FEZTAL.zip"

    log-info "unpacking feztal zip"
    mkdir -p "$FEZTAL_INSTALL_DIR/prefix/drive_c/FEZTAL/"
    unzip -d "$FEZTAL_INSTALL_DIR/prefix/drive_c/FEZTAL" "$TEMP_DIR/FEZTAL.zip"

    log-info "update infinished"
}

feztal-uninstall() {
    log-info "uninstalling feztal-wine"
    noisy-rm-dir "$FEZTAL_INSTALL_DIR/prefix"
    noisy-rm-dir "$FEZTAL_INSTALL_DIR/cache"
    noisy-rm-file "$FEZTAL_INSTALL_DIR/version"
    noisy-rm-file "$FEZTAL_INSTALL_DIR/dxvk-version"
    noisy-rm-file "$FEZTAL_INSTALL_DIR/winearch"
    noisy-rm-empty-dir "$FEZTAL_INSTALL_DIR"
}

feztal-install-dxvk() {
    if [[ ! -d "$FEZTAL_INSTALL_DIR/prefix" ]]; then
        log-error "feztal-wine is not installed, please install first"
        exit 1
    fi

    if [[ -f "$FEZTAL_INSTALL_DIR/dxvk-version" ]]; then
        log-error "DXVK is already installed"

        if [[ "$FEZTAL_FORCE_INSTALL" -eq 1 ]]; then
            log-warn "forcing reinstallation"
        else
            exit 1
        fi
    fi

    log-info "installing DXVK into feztal-wine"

    check-wine-arch

    create-temp-dir

    fetch-dxvk-installer "$TEMP_DIR/dxvk.tar.gz"

    log-debug "extracting latest release"
    tar -C "$TEMP_DIR" --strip-components=1 -xf "$TEMP_DIR/dxvk.tar.gz"

    if [[ $? -ne 0 ]]; then
        log-error "failed to extract latest release"
        exit 1
    fi

    log-info "running DXVK setup script"
    feztal-run-in-prefix "$TEMP_DIR/setup_dxvk.sh" install

    log-debug "saving current version"
    echo "$RELEASE_VERSION" > "$FEZTAL_INSTALL_DIR/dxvk-version"

    log-info "finished installing DXVK"
}

feztal-update-dxvk() {
    if [[ ! -d "$FEZTAL_INSTALL_DIR/prefix" ]]; then
        log-error "feztal-wine is not installed, please install first"
        exit 1
    fi

    if [[ ! -f "$FEZTAL_INSTALL_DIR/dxvk-version" ]]; then
        log-error "DXVK is not installed, please install first"
        exit 1
    fi

    log-info "updating DXVK in feztal-wine"

    check-wine-arch

    create-temp-dir

    fetch-dxvk-installer "$TEMP_DIR/dxvk.tar.gz"

    log-debug "extracting latest release"
    tar -C "$TEMP_DIR" --strip-components=1 -xf "$TEMP_DIR/dxvk.tar.gz"

    if [[ $? -ne 0 ]]; then
        log-error "failed to extract latest release"
        exit 1
    fi

    log-info "running DXVK setup script"
    feztal-run-in-prefix "$TEMP_DIR/setup_dxvk.sh" install

    log-debug "saving current version"
    echo "$RELEASE_VERSION" > "$FEZTAL_INSTALL_DIR/dxvk-version"

    log-info "finished installing DXVK"
}

feztal-uninstall-dxvk() {
    if [[ ! -d "$FEZTAL_INSTALL_DIR/prefix" ]]; then
        log-error "feztal-wine is not installed"
        exit 1
    fi

    if [[ ! -f "$FEZTAL_INSTALL_DIR/dxvk-version" ]]; then
        log-info "DXVK is not installed"
        exit 1
    fi

    log-info "uninstalling DXVK from feztal-wine"

    check-wine-arch

    create-temp-dir

    noisy-rm-file "$FEZTAL_INSTALL_DIR/dxvk-version"

    fetch-dxvk-installer "$TEMP_DIR/dxvk.tar.gz"

    log-debug "extracting latest release"
    tar -C "$TEMP_DIR" --strip-components=1 -xf "$TEMP_DIR/dxvk.tar.gz"

    if [[ $? -ne 0 ]]; then
        log-error "failed to extract latest release"
        exit 1
    fi

    log-info "running DXVK uninstall script"
    feztal-run-in-prefix "$TEMP_DIR/setup_dxvk.sh" uninstall

    log-info "finished uninstalling DXVK"
}

feztal-help() {
    echo "${W}usage:${N} $(basename "$0") [command]"
    echo
    echo "${W}commands:${N}"
    echo " - run ............. run FEZTAL"
    echo " - install* ........ download FEZTAL and prepare wine prefix"
    echo " - update* ......... update FEZTAL to the latest version"
    echo " - uninstall ....... remove FEZTAL wine prefix"
    echo " - install-dxvk .... install DXVK into the wine prefix"
    echo " - update-dxvk ..... update DXVK in the wine prefix"
    echo " - uninstall-dxvk .. uninstall DXVK from the wine prefix"
    echo
    echo "* manual download for now, would need itch.io API key"
}

feztal-invalid-usage() {
    log-error "invalid usage"
    feztal-help
    exit 1
}

# invocation

if [[ $# -ne 1 ]]; then
    feztal-invalid-usage
fi

case "$1" in
    run) feztal-run;;
    install) feztal-install;;
    update) feztal-update;;
    uninstall) feztal-uninstall;;
    install-dxvk) feztal-install-dxvk;;
    update-dxvk) feztal-update-dxvk;;
    uninstall-dxvk) feztal-uninstall-dxvk;;
    help) feztal-help;;
    *) feztal-invalid-usage;;
esac

exit 0
