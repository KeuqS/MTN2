#!/bin/sh
# Installs MTN2 from the folder this script sits in.
#
#   ./install.sh               for the current user: ~/.local/opt/mtn2, command ~/.local/bin/mtn2
#   sudo ./install.sh          for everyone: /opt/mtn2, command /usr/local/bin/mtn2
#   ./install.sh --uninstall   removes what an earlier run installed (same rights as the install)
set -e

here=$(cd "$(dirname "$0")" && pwd)
if [ "$(id -u)" = 0 ]; then
    prefix=/opt/mtn2
    bindir=/usr/local/bin
else
    prefix="$HOME/.local/opt/mtn2"
    bindir="$HOME/.local/bin"
fi

if [ "$1" = "--uninstall" ]; then
    rm -f "$bindir/mtn2" "$bindir/mtn2-sdl"
    rm -rf "$prefix"
    echo "MTN2 removed from $prefix"
    exit 0
fi

if [ ! -x "$here/mtn2-tui" ]; then
    echo "mtn2-tui not found next to install.sh" >&2
    exit 1
fi

mkdir -p "$bindir"
rm -rf "$prefix"
mkdir -p "$prefix"
cp -a "$here"/. "$prefix"/
ln -sf "$prefix/mtn2-tui" "$bindir/mtn2"
if [ -x "$prefix/mtn2-sdl" ]; then
    ln -sf "$prefix/mtn2-sdl" "$bindir/mtn2-sdl"
fi
echo "MTN2 installed in $prefix; run: mtn2"
case ":$PATH:" in
    *":$bindir:"*) ;;
    *) echo "Add $bindir to PATH to start it by name." ;;
esac
