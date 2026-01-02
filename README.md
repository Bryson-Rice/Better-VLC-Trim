# FFmpeg Trim Video – VLC Lua Extension

A simple VLC extension that trims videos because its too many buttons to trim a video in VLC

## Requirements

**FFmpeg** (must be installed and accessible from the command line)

## Installation

### 1. Install the VLC Lua Extension

Place `ffmpeg_trim.lua` in VLC’s **extensions** folder.

**Windows**

C:\Users<YourUsername>\AppData\Roaming\vlc\lua\extensions\

**macOS**

/Users/<YourUsername>/Library/Application Support/org.videolan.vlc/lua/extensions/


**Linux**

~/.local/share/vlc/lua/extensions/


Restart VLC after placing the file.

### 2. Install FFmpeg

#### Windows
```powershell
winget install FFmpeg
```

#### macOS (Homebrew)
```bash
brew install ffmpeg
```


#### Linux (Debian / Ubuntu)
```bash
sudo apt install ffmpeg
```

#### Linux (Arch)
```bash
sudo pacman -S ffmpeg
```

### 3. Verify FFmpeg Is Installed

```bash
ffmpeg --version
```

If FFmpeg is installed correctly, version information will be printed.
If this command fails, VLC will not be able to trim videos.

## Usage

After placing the lua script in the correction check the View tab and select `Trim video using FFmpeg`

![img](usage.png)
