#!/bin/sh
set -eu

version=${1:-0.1.0}
case "$version" in
    *[!0-9A-Za-z.+:~-]*|'')
        echo "invalid Debian version: $version" >&2
        exit 2
        ;;
esac

export LC_ALL=C
export TZ=UTC
export SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-1788089400}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
output_dir=${2:-"$source_dir/dist"}
mkdir -p "$output_dir"
output_dir=$(CDPATH= cd -- "$output_dir" && pwd)

build_root=$(mktemp -d)
trap 'rm -rf -- "$build_root"' EXIT HUP INT TERM
package_root="$build_root/fz-m1-touch-mode"

install -d "$package_root/DEBIAN"
sed "s/@VERSION@/$version/g" "$script_dir/control.in" > "$package_root/DEBIAN/control"
chmod 0644 "$package_root/DEBIAN/control"
install -m 0755 "$script_dir/postinst" "$package_root/DEBIAN/postinst"
install -m 0755 "$script_dir/prerm" "$package_root/DEBIAN/prerm"
install -m 0755 "$script_dir/postrm" "$package_root/DEBIAN/postrm"
install -m 0644 "$script_dir/conffiles" "$package_root/DEBIAN/conffiles"

install -D -m 0755 "$source_dir/tools/fz-m1-touch-mode" "$package_root/usr/sbin/fz-m1-touch-mode"
install -D -m 0755 "$source_dir/gui/fz-m1-touch-tray" "$package_root/usr/bin/fz-m1-touch-tray"
install -D -m 0755 "$source_dir/gui/fz-m1-touch-mode-helper" "$package_root/usr/libexec/fz-m1-touch-mode-helper"

install -d "$package_root/usr/lib/systemd/system"
sed 's#/usr/local/sbin/fz-m1-touch-mode#/usr/sbin/fz-m1-touch-mode#' \
    "$source_dir/systemd/fz-m1-touch-mode@.service" \
    > "$package_root/usr/lib/systemd/system/fz-m1-touch-mode@.service"
chmod 0644 "$package_root/usr/lib/systemd/system/fz-m1-touch-mode@.service"

install -D -m 0644 "$source_dir/udev/99-fz-m1-touch-mode.rules" \
    "$package_root/usr/lib/udev/rules.d/99-fz-m1-touch-mode.rules"

install -d "$package_root/usr/share/polkit-1/actions"
sed 's#/usr/local/libexec/fz-m1-touch-mode-helper#/usr/libexec/fz-m1-touch-mode-helper#' \
    "$source_dir/gui/io.github.michaelh1981.fz-m1-touch-mode.policy" \
    > "$package_root/usr/share/polkit-1/actions/io.github.michaelh1981.fz-m1-touch-mode.policy"
chmod 0644 "$package_root/usr/share/polkit-1/actions/io.github.michaelh1981.fz-m1-touch-mode.policy"

install -d "$package_root/etc/xdg/autostart"
sed 's#/usr/local/bin/fz-m1-touch-tray#/usr/bin/fz-m1-touch-tray#' \
    "$source_dir/gui/fz-m1-touch-mode-tray.desktop" \
    > "$package_root/etc/xdg/autostart/fz-m1-touch-mode-tray.desktop"
chmod 0644 "$package_root/etc/xdg/autostart/fz-m1-touch-mode-tray.desktop"

doc_dir="$package_root/usr/share/doc/fz-m1-touch-mode"
install -d "$doc_dir"
install -m 0644 "$source_dir/README.md" "$source_dir/README.en.md" \
    "$source_dir/NOTES.md" "$source_dir/LICENSE" "$doc_dir/"
gzip -n -9 -c "$script_dir/changelog" > "$doc_dir/changelog.Debian.gz"
chmod 0644 "$doc_dir/changelog.Debian.gz"

package="$output_dir/fz-m1-touch-mode_${version}_all.deb"
dpkg-deb --root-owner-group --build "$package_root" "$package"

archive="$output_dir/fz-m1-touch-mode-${version}.tar.gz"
tar --sort=name --mtime="@$SOURCE_DATE_EPOCH" --owner=0 --group=0 --numeric-owner \
    -C "$source_dir" -czf "$archive" \
    --transform "s#^#fz-m1-touch-mode-${version}/#" \
    .gitignore LICENSE NOTES.md README.md README.en.md SECURITY.md \
    gui packaging systemd tools/fz-m1-touch-mode udev

(cd "$output_dir" && sha256sum "$(basename "$package")" "$(basename "$archive")" > SHA256SUMS)
printf '%s\n%s\n' "$package" "$archive"
