# KodiToRK3588.sh — Kodi + FFmpeg + Gaming installer for Orange Pi 5 / RK3588/S

## What does this script do?

**KodiToRK3588.sh** is a fully automated setup tool to convert your Orange Pi 5 (or any RK3588 SBC) into a modern Media Center and retro gaming station.
Tested on Armbian 25.8.1 Noble Gnome with vendor kernel 6.1.115: https://www.armbian.com/orangepi-5/

- Lets you choose **which version of Kodi to install** at launch: **Omega (v21, FFmpeg 6.0)** or **Piers (v22, FFmpeg 7.0)**
- **Compiles and installs the correct FFmpeg version** with the best codecs for your choice.
- **Builds and installs Kodi ($KODI_BRANCH) latest branch from source** (Omega or Piers)
- **Music visualizations**: compiles Goom, FishBMC, Spectrum, Waveform, Shadertoy (all OpenGLES2 and ARM compatible)
- **Builds inputstream.adaptive**: enable streaming (e.g. Netflix, Prime, etc) from Kodi official repo for your ARM device
- **Installs RetroArch and main libretro cores** for maximum gaming support out-of-the-box
- **Auto-creates `/media/$USER/ROMs`** for your classic games/ROMs (copy them there manually after script finishes)
- **Samba setup**: prompts you for your Samba password and enables sharing your user folders over LAN
- **Pipewire/Audio setup**: system audio ready with support for selecting 'Digital Surround 5.1 (HDMI)' profile. This enables true AC3 5.1 passthrough for your AVR or HDMI TV (see below)
- **User feedback**: clear, numbered steps in the console, with progress and total time taken
- **Safe to rerun/idempotent**: you can rerun it anytime; it won't break previous setups and only updates what's missing

---

## Quickstart

download ths script, then:

chmod +x KodiToRK3588.sh

./KodiToRK3588.sh

At the prompt, choose Omega or Piers and enter your Samba password when asked.
When it's done, copy your ROMs to /media/$USER/ROMs

**If you're connected over SSH, I recommend using `tmux` or `screen` to avoid problems if the connection drops.**


---

## Audio & AC3/DTS 5.1 passthrough
- The script ensures Pipewire and system audio are ready.
- **To enable AC3 5.1 passthrough:** Launch `pavucontrol` (PulseAudio Volume Control) or your system's audio settings and select the **'Digital Surround 5.1 (HDMI)'** output profile for your HDMI card.
- This unlocks 5.1 surround and audio passthrough (DTS, AC3) for compatible HDMI TVs/soundbars/AVRs.  
- In Kodi, ensure **Settings > Audio** is set to the HDMI device, channels to 5.1 and passthrough options enabled for Dolby/DTS as your AVR supports.

---

## How to use for gaming?

- Copy your ROMs to `/media/$USER/ROMs`
- Use Kodi's Retroplayer or Retroarch to scan and launch your games
- Script includes latest RetroArch and cores for SNES, NES, Genesis, PlayStation, MAME, and more

---

## Validation checklist

After running the script, you should check:
- Kodi is launchable and shows the correct version (Omega or Piers)
- Visualizations show up under Kodi's music add-ons
- FFmpeg version is correct: `ffmpeg -version`
- Your user folder is shareable via Samba (can be accessed in the LAN)
- `inputstream.adaptive` is active in Kodi add-ons
- ROMs are visible in `/media/$USER/ROMs` and launch with RetroArch/Kodi

---

## License

MIT. Free to use, modify and distribute.

---

## Collaborate

- Fork the repo, improve or fix, make a Pull Request
- Submit issues/feature requests for your hardware variant or other SBCs

---

**Thanks for using and sharing KodiToRK3588.sh!**

