#!/usr/bin/env bash
## Create a live Kali rolling image, using offsec-awae metapackage and preseed files
## Updated: 2021-11-01
#
## Info:
##   - Credentials: kali/kali
##   - Timezone: Etc/UTC
##   - Keyboard: US
##   - Metapackage: https://gitlab.com/kalilinux/packages/offsec-courses/-/blob/kali/master/debian/control
#
## Example:
##   $ bash <(curl "https://gitlab.com/kalilinux/recipes/live-build-config-examples/-/raw/master/offsec-awae-live.sh")
#

## Exit on issue
set -e

## Make sure we have programs needed
sudo apt-get update
sudo apt-get install -yqq git live-build simple-cdd cdebootstrap curl

## Get base-image build-script
if [ -e "/opt/kali-build/" ]; then
  cd /opt/kali-build/
  sudo git reset --hard HEAD >/dev/null
  sudo git clean -f -d >/dev/null
  sudo git pull >/dev/null
else
  sudo git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git /opt/kali-build/
  cd /opt/kali-build/
fi

## Select packages for image (Live)
cat <<'EOF' | sudo tee kali-config/variant-default/package-lists/kali.list.chroot >/dev/null
## Graphical desktop
kali-desktop-xfce

## Metapackages
offsec-awae

## Extra applications
code-oss
gobuster
jd-gui
EOF

## Boot menu for image
cat <<'EOF' | sudo tee kali-config/common/includes.binary/isolinux/install.cfg >/dev/null
label install
    menu label ^Unattended Install
    linux /install/vmlinuz
    initrd /install/initrd.gz
    append vga=788 -- quiet file=/cdrom/install/preseed.cfg locale=en_US keymap=us hostname=kali domain=local.lan
EOF

## Point to our boot menu
cat <<'EOF' | sudo tee kali-config/common/includes.binary/isolinux/isolinux.cfg >/dev/null
include menu.cfg
ui vesamenu.c32
default install
prompt 0
timeout 1
EOF

## Add to preseed file
cat <<'EOF' | sudo tee -a kali-config/common/includes.installer/preseed.cfg >/dev/null
d-i debian-installer/locale string en_US.UTF-8
d-i console-keymaps-at/keymap select us
d-i keyboard-configuration/xkb-keymap select us
d-i mirror/http/proxy string
d-i mirror/suite string kali-rolling
d-i mirror/codename string kali-rolling

d-i clock-setup/utc boolean true
d-i time/zone string Etc/UTC

# Partitioning
d-i partman-auto/method string regular
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-auto/choose_recipe select atomic
d-i partman-auto/disk string /dev/sda
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true

# Change default hostname
d-i netcfg/get_hostname string kali
d-i netcfg/get_domain string unassigned-domain
#d-i netcfg/choose_interface select auto
d-i netcfg/choose_interface select eth0
d-i netcfg/dhcp_timeout string 60

d-i hw-detect/load_firmware boolean false

d-i passwd/user-fullname string Kali Linux
# Normal user's username
d-i passwd/username string kali
# Normal user's password (clear text)
d-i passwd/user-password password kali
d-i passwd/user-password-again password kali

d-i apt-setup/use_mirror boolean true
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_other_os boolean false
d-i grub-installer/bootdev string /dev/sda
d-i finish-install/reboot_in_progress note

kismet kismet/install-setuid boolean false
kismet kismet/install-users string

sslh sslh/inetd_or_standalone select standalone

mysql-server-5.5 mysql-server/root_password_again password
mysql-server-5.5 mysql-server/root_password password
mysql-server-5.5 mysql-server/error_setting_password error
mysql-server-5.5 mysql-server-5.5/postrm_remove_databases boolean false
mysql-server-5.5 mysql-server-5.5/start_on_boot boolean true
mysql-server-5.5 mysql-server-5.5/nis_warning note
mysql-server-5.5 mysql-server-5.5/really_downgrade boolean false
mysql-server-5.5 mysql-server/password_mismatch error
mysql-server-5.5 mysql-server/no_upgrade_when_using_ndb error
EOF

## Switch Xfce4 default web icon to FireFox
cat <<'EOF' | sudo tee kali-config/common/hooks/live/01-xfce-firefox.chroot >/dev/null
sed -i 's_xfce4-web-browser.desktop_firefox-esr.desktop_' /etc/xdg/xfce4/panel/default.xml
sed -i 's_xfce4-web-browser.desktop_firefox-esr.desktop_' /usr/share/kali-themes/etc/xdg/xfce4/panel/default.xml
EOF
sudo chmod 0755 kali-config/common/hooks/live/01-xfce-firefox.chroot

## Switch from mousepad to VS-Code
cat <<'EOF' | sudo tee kali-config/common/hooks/live/02-xfce-vscode.chroot >/dev/null
sed -i 's_mousepad.desktop_code-oss.desktop_' /etc/xdg/xfce4/panel/default.xml
sed -i 's_mousepad.desktop_code-oss.desktop_' /usr/share/kali-themes/etc/xdg/xfce4/panel/default.xml
EOF
sudo chmod 0755 kali-config/common/hooks/live/02-xfce-vscode.chroot

## Set VS-Code as default
sudo mkdir -p kali-config/common/includes.chroot/usr/share/applications/
cat <<'EOF' | sudo tee kali-config/common/includes.chroot/usr/share/applications/mimeapps.list >/dev/null
[Default Applications]
text/plain=code-oss.desktop
EOF
sudo chmod 0644 kali-config/common/includes.chroot/usr/share/applications/mimeapps.list

## Local mirror
#echo "http://192.168.1.123/kali" | sudo tee .mirror >/dev/null

## Build image
time sudo ./build.sh \
  --debug \
  --live \
  --version offsec-awae

## Output
ls -lh /opt/kali-build/images/*.iso

## Done
echo "[i] Done"
exit 0
