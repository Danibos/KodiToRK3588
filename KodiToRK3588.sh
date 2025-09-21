#!/bin/bash
# KodiToRK3588.sh - Universal installer for Kodi + FFmpeg + gaming + AC3 passthrough patch on Orange Pi 5 / RK3588 (Armbian)
# By default, does NOT edit /etc/fstab or use fixed user folders. Multiuser ready.
set -e
start=$(date +%s)
USER="$(whoami)"

echo -e "\n===================="
echo "  KodiToRK3588 Setup"
echo -e "====================\n"
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

echo "[1/11] Creating your ROMs folder and prepping paths..."
if [ ! -d "/media/$USER/ROMs" ]; then
  sudo mkdir -p "/media/$USER/ROMs"
fi
echo "[INFO] Copy your ROM files into /media/$USER/ROMs after script finishes."

echo "[2/11] Installing main build dependencies and services..."
sudo apt-get update
sudo apt-get install -y build-essential autoconf automake cmake libtool git nasm yasm libass-dev p11-kit libva-dev libvdpau-dev \
libvorbis-dev libxcb1-dev libxcb-shm0-dev libxcb-xfixes0-dev pkg-config texinfo wget zlib1g-dev libchromaprint-dev frei0r-plugins-dev \
libgnutls28-dev ladspa-sdk libcaca-dev libcdio-paranoia-dev libcodec2-dev libfontconfig1-dev libfreetype-dev libfribidi-dev \
libgsm1-dev libjack-dev libmodplug-dev libmp3lame-dev libopencore-amrnb-dev libopencore-amrwb-dev libopenjp2-7-dev libopenmpt-dev \
libopus-dev libpulse-dev librsvg2-dev librubberband-dev librtmp-dev libshine-dev libsmbclient-dev libsoxr-dev libspeex-dev libssh-dev \
libtheora-dev libtwolame-dev libv4l-dev libvo-amrwbenc-dev libvorbis-dev libvpx-dev libwavpack-dev libwebp-dev libx264-dev libx265-dev \
libxvidcore-dev libxml2-dev libzmq3-dev libzvbi-dev liblilv-dev libopenal-dev ocl-icd-opencl-dev frei0r-plugins libbluray-dev \
libfdk-aac-dev librga-dev libdrm-dev meson ninja-build libudev-dev libinput-dev libxkbcommon-dev uuid-dev libcurl4-openssl-dev rapidjson-dev

# Install shared-media network services and audio controller
sudo apt -y install samba pavucontrol avahi-daemon avahi-discover libnss-mdns
sudo systemctl enable --now avahi-daemon.service

echo "[3/11] Building and installing LibCEC for HDMI CEC support..."
sudo apt-get install -y cmake libudev-dev libxrandr-dev python3-dev swig libcec-dev
mkdir -p ~/dev && cd ~/dev
git clone https://github.com/Pulse-Eight/libcec.git || true
mkdir -p libcec/build && cd libcec/build
cmake -DCMAKE_INSTALL_LIBDIR:PATH='lib/aarch64-linux-gnu' -DCMAKE_INSTALL_PREFIX:PATH='/usr' -DHAVE_LINUX_API=1 ..
make -j$(nproc)
sudo make install
sudo ldconfig

echo "[4/11] Building and installing MPP (video hardware acceleration)..."
cd ~/dev
git clone -b jellyfin-mpp --depth=1 https://github.com/nyanmisaka/mpp.git rkmpp || true
mkdir -p rkmpp/rkmpp_build
cd rkmpp/rkmpp_build
cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_TEST=OFF ..
make -j$(nproc)
sudo make install

echo "[5/11] Building and installing RGA (graphics accelerator)..."
cd ~/dev
git clone -b jellyfin-rga --depth=1 https://github.com/nyanmisaka/rk-mirrors.git rkrga || true
meson setup rkrga rkrga_build --prefix=/usr --libdir=lib --buildtype=release --default-library=shared -Dcpp_args=-fpermissive -Dlibdrm=false -Dlibrga_demo=false
meson configure rkrga_build
sudo ninja -C rkrga_build install

echo "[6/11] Patching ALSA/Pipewire for HDMI AC3/DTS passthrough..."
# /usr/share/alsa/cards/aliases.conf
if ! grep -q "rockchip-hdmi0" /usr/share/alsa/cards/aliases.conf; then
  sudo cp /usr/share/alsa/cards/aliases.conf /usr/share/alsa/cards/aliases.conf.bak
  echo "rockchip-hdmi0 cards.HDMI-SPDIF" | sudo tee -a /usr/share/alsa/cards/aliases.conf
fi
# /usr/share/alsa/cards/HDMI-SPDIF.conf
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
  echo "[7/11] Cloning and building FFmpeg 6 (for Kodi Omega)..."
  cd ~
  [ -d ffmpeg ] || git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg
  cd ffmpeg
  git checkout release/6.0
  ./configure --prefix=/usr --enable-gpl --enable-nonfree --enable-version3 --enable-shared --disable-stripping --disable-doc --enable-libass --enable-libaom --enable-libfdk-aac --enable-libmp3lame --enable-libvorbis --enable-libopus --enable-libsoxr --enable-libx264 --enable-libx265 --enable-libdrm --enable-opencl --disable-vdpau
  make -j$(nproc)
  sudo make install
elif [ "$KODI_VERSION" == "piers" ]; then
  echo "[7/11] Cloning and building FFmpeg 7 (for Kodi Piers)..."
  cd ~
  [ -d ffmpeg ] || git clone https://github.com/nyanmisaka/ffmpeg-rockchip.git ffmpeg
  cd ffmpeg
  git checkout jellyfin-rk
  ./configure --prefix=/usr --enable-gpl --enable-version3 --enable-nonfree --enable-shared --disable-stripping --disable-doc --enable-libass --enable-libaom --enable-libfdk-aac --enable-libmp3lame --enable-libvorbis --enable-libopus --enable-libsoxr --enable-libx264 --enable-libx265 --enable-libdrm --enable-opencl --disable-vdpau
  make -j$(nproc)
  sudo make install
fi
sudo ldconfig

echo "[8/11] Cloning and building Kodi ($KODI_BRANCH branch)..."
cd ~
[ -d xbmc ] || git clone https://github.com/xbmc/xbmc.git xbmc
cd xbmc
git checkout $KODI_BRANCH
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DENABLE_INTERNAL_FFMPEG=OFF
make -j$(nproc)
sudo make install

echo "[9/11] Building and installing music visualizations (Goom, FishBMC, Spectrum, Waveform, Shadertoy)..."
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

echo "[10/11] Compiling and installing inputstream.adaptive addon..."
cd ~
[ -d inputstream.adaptive ] || git clone https://github.com/xbmc/inputstream.adaptive.git
cd inputstream.adaptive
git checkout $KODI_BRANCH || git checkout master
mkdir -p build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr
make -j$(nproc)
sudo make install

echo "[11/11] Installing RetroArch and main libretro cores"
sudo apt-get install -y retroarch libretro-*

echo "[INFO] Copy your ROM files to /media/$USER/ROMs after the script for use in Kodi or RetroArch."
echo "[INFO] Samba setup for your user."
read -s -p "Enter Samba password for user $USER: " SMBPASS
echo
(echo "$SMBPASS"; echo "$SMBPASS") | sudo smbpasswd -a -s "$USER"

end=$(date +%s); dur=$((end-start))
echo -e "\n>>> Setup finished! Duration: $((dur/60)) min $((dur%60)) sec"
echo "[INFO] Audio: To enable AC3/DTS passthrough, run 'pavucontrol', go to 'Configuration' tab, and select 'Digital Surround 5.1 (HDMI)' for your HDMI audio output. Enable passthrough in Kodi as well."
