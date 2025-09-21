#!/bin/bash
# KodiToRK3588-dani.sh — Personalized, full auto-mount (fstab) + custom samba shares for Dani
set -e
start=$(date +%s)
USER="dani"

echo -e "\n============================"
echo "  KodiToRK3588 Setup (Dani)"
echo -e "============================\n"
echo "Which Kodi version do you want to install?"
echo "  1 - Omega (v21, with FFmpeg 6)"
echo "  2 - Piers (v22, with FFmpeg 7)"
read -p "Enter 1 or 2: " VERSION_CHOICE
if [ "$VERSION_CHOICE" == "1" ]; then
  KODI_VERSION="omega"
  FFMPEG_VERSION="6.0"
  KODI_BRANCH="Omega"
  echo "[INFO] Kodi Omega will be installed with FFmpeg 6"
elif [ "$VERSION_CHOICE" == "2" ]; then
  KODI_VERSION="piers"
  FFMPEG_VERSION="7.0"
  KODI_BRANCH="master"
  echo "[INFO] Kodi Piers will be installed with FFmpeg 7"
else
  echo "Invalid selection!"
  exit 1
fi

echo "[1/13] Mounting and preparing your disks (fstab, escaped spaces)..."
DISK_ARRAY=(
  '/dev/disk/by-id/wwn-0x50014ee26b262e44-part1:/media/dani/4TB DE AMOR'
  '/dev/disk/by-id/wwn-0x5000039ff4ec789d-part1:/media/dani/UN AMOR DE 3 TB'
  '/dev/disk/by-id/wwn-0x5000c500ad50b456-part1:/media/dani/5 TB DE INTENSIDAD'
)
for ITEM in "${DISK_ARRAY[@]}"; do
  SRC=$(echo "$ITEM" | cut -d: -f1)
  DEST_RAW=$(echo "$ITEM" | cut -d: -f2)
  DEST_FSTAB=$(echo "$DEST_RAW" | sed 's/ /\\040/g')
  if [ ! -d "$DEST_RAW" ]; then
    sudo mkdir -p "$DEST_RAW"
  fi
  LINE="$SRC $DEST_FSTAB auto nosuid,nodev,nofail,x-gvfs-show 0 0"
  if ! grep -Fq "$SRC" /etc/fstab; then
    echo "$LINE" | sudo tee -a /etc/fstab
  fi
  sudo mount "$DEST_RAW" || true
done

echo "[2/13] Creating your ROMs folder..."
if [ ! -d "/media/dani/ROMs" ]; then
  sudo mkdir -p "/media/dani/ROMs"
fi
echo "[INFO] Copy your ROM files into /media/dani/ROMs after script finishes."

echo "[3/13] Installing main build dependencies and services..."
sudo apt-get update
sudo apt-get install -y build-essential autoconf automake cmake libtool git nasm yasm libass-dev p11-kit libva-dev libvdpau-dev \
libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev pkg-config texinfo wget zlib1g-dev libchromaprint-dev frei0r-plugins-dev \
libgnutls28-dev ladspa-sdk libcaca-dev libcdio-paranoia-dev libcodec2-dev libfontconfig1-dev libfreetype-dev libfribidi-dev \
libgsm1-dev libjack-dev libmodplug-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev libopenjp2-7-dev libopenmpt-dev \
libopus-dev libpulse-dev librsvg2-dev librubberband-dev librtmp-dev libshine-dev libsmbclient-dev libsoxr-dev libspeex-dev libssh-dev \
libtheora-dev libtwolame-dev libv4l-dev libvo-amrwbenc-dev libvorbis-dev libvpx-dev libwavpack-dev libwebp-dev libx264-dev libx265-dev \
libxvidcore-dev libxml2-dev libzmq3-dev libzvbi-dev liblilv-dev libopenal-dev ocl-icd-opencl-dev frei0r-plugins libbluray-dev \
libfdk-aac-dev librga-dev libdrm-dev meson ninja-build libudev-dev libinput-dev libxkbcommon-dev uuid-dev libcurl4-openssl-dev rapidjson-dev
sudo apt -y install samba pavucontrol avahi-daemon avahi-discover libnss-mdns
sudo systemctl enable --now avahi-daemon.service

echo "[4/13] Updating samba shares in /etc/samba/smb.conf..."
if ! grep -q "\[HDD\]" /etc/samba/smb.conf; then
  sudo bash -c "cat >> /etc/samba/smb.conf" <<'EOF'

[HDD]
    comment = HDD
    path = /media/dani/
    read only = no
    browsable = yes

[Home]
    comment = Home
    path = /home/dani/
    read only = no
    browsable = yes
EOF
  sudo systemctl restart smbd
fi

echo "[5/13] Building and installing LibCEC for HDMI CEC support..."
sudo apt-get install -y cmake libudev-dev libxrandr-dev python3-dev swig libcec-dev
mkdir -p ~/dev && cd ~/dev
git clone https://github.com/Pulse-Eight/libcec.git || true
mkdir -p libcec/build && cd libcec/build
cmake -DCMAKE_INSTALL_LIBDIR:PATH='lib/aarch64-linux-gnu' -DCMAKE_INSTALL_PREFIX:PATH='/usr' -DHAVE_LINUX_API=1 ..
make -j$(nproc)
sudo make install
sudo ldconfig

echo "[6/13] Building and installing MPP (video hardware acceleration)..."
cd ~/dev
git clone -b jellyfin-mpp --depth=1 https://github.com/nyanmisaka/mpp.git rkmpp || true
mkdir -p rkmpp/rkmpp_build
cd rkmpp/rkmpp_build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_TEST=OFF ..
make -j$(nproc)
sudo make install

echo "[7/13] Building and installing RGA (graphics accelerator)..."
cd ~/dev
git clone -b jellyfin-rga --depth=1 https://github.com/nyanmisaka/rk-mirrors.git rkrga || true
meson setup rkrga rkrga_build --prefix=/usr --libdir=lib --buildtype=release --default-library=shared -Dcpp_args=-fpermissive -Dlibdrm=false -Dlibrga_demo=false
meson configure rkrga_build
sudo ninja -C rkrga_build install

echo "[8/13] Patching ALSA/Pipewire for HDMI AC3/DTS passthrough..."
if ! grep -q "rockchip-hdmi0" /usr/share/alsa/cards/aliases.conf; then
  sudo cp /usr/share/alsa/cards/aliases.conf /usr/share/alsa/cards/aliases.conf.bak
  echo "rockchip-hdmi0 cards.HDMI-SPDIF" | sudo tee -a /usr/share/alsa/cards/aliases.conf
fi
if ! grep -q "HDMI-SPDIF.pcm.hdmi.0" /usr/share/alsa/cards/HDMI-SPDIF.conf 2>/dev/null; then
  sudo cp /usr/share/alsa/cards/HDMI-SPDIF.conf /usr/share/alsa/cards/HDMI-SPDIF.conf.bak
cat <<EOF | sudo tee -a /usr/share/alsa/cards/HDMI-SPDIF.conf
<confdir:pcm/hdmi.conf>
<confdir:pcm/iec958.conf>
HDMI-SPDIF.pcm.hdmi.0 {
    @args [ CARD DEVICE CTLINDEX AES0 AES1 AES2 AES3 ]
    @args.CARD { type string }
    @args.DEVICE { type integer }
    @args.CTLINDEX { type integer }
    @args.AES0 { type integer }
    @args.AES1 { type integer }
    @args.AES2 { type integer }
    @args.AES3 { type integer }
    type hw
    card \$CARD
}
HDMI-SPDIF.pcm.iec958.0 {
    @args [ CARD AES0 AES1 AES2 AES3 ]
    @args.CARD { type string }
    @args.AES0 { type integer }
    @args.AES1 { type integer }
    @args.AES2 { type integer }
    @args.AES3 { type integer }
    type hw
    card \$CARD
}
EOF
fi
echo "[INFO] For 5.1/7.1 and passthrough, set HDMI output to 'Digital Surround 5.1 (HDMI)' in pavucontrol after setup!"

if [ "$KODI_VERSION" == "omega" ]; then
  echo "[9/13] Building FFmpeg 6 (for Kodi Omega)..."
  cd ~
  [ -d ffmpeg ] || git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg
  cd ffmpeg
  git checkout release/6.0
  ./configure --prefix=/usr --enable-gpl --enable-nonfree --enable-version3 --enable-shared --disable-stripping --disable-doc --enable-libass --enable-libaom --enable-libfdk-aac --enable-libmp3lame --enable-libvorbis --enable-libopus --enable-libsoxr --enable-libx264 --enable-libx265 --enable-libdrm --enable-opencl --disable-vdpau
  make -j$(nproc)
  sudo make install
elif [ "$KODI_VERSION" == "piers" ]; then
  echo "[9/13] Building FFmpeg 7 (for Kodi Piers)..."
  cd ~
  [ -d ffmpeg ] || git clone https://github.com/nyanmisaka/ffmpeg-rockchip.git ffmpeg
  cd ffmpeg
  git checkout jellyfin-rk
  ./configure --prefix=/usr --enable-gpl --enable-version3 --enable-nonfree --enable-shared --disable-stripping --disable-doc --enable-libass --enable-libaom --enable-libfdk-aac --enable-libmp3lame --enable-libvorbis --enable-libopus --enable-libsoxr --enable-libx264 --enable-libx265 --enable-libdrm --enable-opencl --disable-vdpau
  make -j$(nproc)
  sudo make install
fi
sudo ldconfig

echo "[10/13] Building Kodi ($KODI_BRANCH branch)..."
cd ~
[ -d xbmc ] || git clone https://github.com/xbmc/xbmc.git xbmc
cd xbmc
git checkout $KODI_BRANCH
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_INTERNAL_FFMPEG=OFF
make -j$(nproc)
sudo make install

echo "[11/13] Building music visualizations (Goom, FishBMC, etc)..."
VISUALS=(goom fishbmc spectrum waveform shadertoy)
cd ~
for vis in "${VISUALS[@]}"; do
  [ -d "visualization.$vis" ] || git clone "https://github.com/xbmc/visualization.$vis.git"
  cd "visualization.$vis"
  git checkout $KODI_BRANCH || true
  mkdir -p build && cd build
  cmake .. -DCMAKE_INSTALL_PREFIX=/usr
  make -j$(nproc) || true
  sudo make install || true
  cd ~/ 
done

echo "[12/13] Building inputstream.adaptive addon..."
cd ~
[ -d inputstream.adaptive ] || git clone https://github.com/xbmc/inputstream.adaptive.git
cd inputstream.adaptive
git checkout $KODI_BRANCH || git checkout master
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install

echo "[13/13] Installing RetroArch and main libretro cores"
sudo apt-get install -y retroarch libretro-*

echo "[INFO] Copy your ROM files to /media/dani/ROMs after the script for use in Kodi or RetroArch."
echo "[INFO] Samba setup for user Dani."
sudo smbpasswd -a dani

end=$(date +%s); dur=$((end-start))
echo -e "\n>>> Dani's setup finished! Duration: $((dur/60)) min $((dur%60)) sec"
echo "[INFO] Audio: To enable AC3/DTS passthrough, run 'pavucontrol', go to 'Configuration' tab, and select 'Digital Surround 5.1 (HDMI)' for your HDMI audio output. Enable passthrough in Kodi as well."
