# Quas MultiQuest Edition

**Fork of [Quest ADB Scripts by Varset](https://github.com/Varsett/Quas)**

This fork adds **MultiQuest Manager** - a PowerShell-based batch manager for managing multiple Meta Quest headsets simultaneously.

---

## What's New: MultiQuest Manager

MultiQuest Manager extends QUAS with the ability to perform batch operations across **multiple Quest devices at once**.

### Key Features

✅ **Batch Operations** - Execute commands on all connected Quest devices simultaneously
✅ **QUAS-Proven Commands** - Uses the exact same tested ADB commands from QUAS v5.2.0
✅ **Auto-Detection** - Automatically detects all connected Quest devices
✅ **Parallel & Sequential Modes** - Choose between fast parallel or detailed sequential execution
✅ **Certificate Deployment** - Deploy SSL certificates to multiple devices at once
✅ **Media Management** - Batch screenshot, screen recording, and file transfers
✅ **System Settings** - Apply settings (brightness, volume, Wi-Fi) to all devices

---

## Quick Start

### Prerequisites

- Windows 10/11 with PowerShell 5.1+
- ADB installed and in PATH
- Meta Quest devices with USB debugging enabled

### Running MultiQuest Manager

```powershell
cd Quas
PowerShell -ExecutionPolicy Bypass -File MultiQuest-Manager.ps1
```

The script will automatically detect all connected Quest devices and present a menu-driven interface.

---

## Use Cases

### 1. Deploy Apps to Multiple Headsets

Perfect for:
- Development teams testing on multiple devices
- VR arcades deploying apps to multiple stations
- Education environments with multiple Quest headsets

**Example:** Install an APK to 10 Quest headsets simultaneously:
1. Connect all headsets via USB
2. Run MultiQuest Manager
3. Select `[2] App Management` → `[1] Install APK`
4. Enter APK path
5. All devices install in parallel

### 2. Batch Certificate Deployment

Deploy SSL certificates for secure local streaming:
1. Select `[6] Certificate Management`
2. Select `[1] Push certificate to all devices`
3. Enter certificate path
4. All devices receive the certificate simultaneously

### 3. Batch Media Collection

Collect screenshots/videos from multiple devices:
1. Select `[5] Screenshot/Screen Record`
2. Select `[4] Copy Oculus screenshots/videos to PC`
3. All media automatically organized by device ID in `Desktop/QuestMedia`

---

## Differences from QUAS

| Feature | QUAS | MultiQuest Manager |
|---------|------|-------------------|
| Target Devices | Single device | Multiple devices (batch) |
| Interface | CMD Batch menus | PowerShell interactive menus |
| Execution | Sequential only | Sequential or Parallel |
| Platform | Windows (CMD) | Windows (PowerShell) |
| ADB Commands | Proven, tested | **Same as QUAS** |

---

## Documentation

- **[MultiQuest Manager README](MULTIQUEST_MANAGER_README.md)** - Complete documentation
- **[Original QUAS README](README.md)** - Original QUAS documentation

---

## Proven ADB Commands

MultiQuest Manager uses the **exact same ADB commands** from QUAS v5.2.0:

```powershell
# Screenshot (QUAS method)
adb exec-out screencap -p > screenshot.png

# APK Install (QUAS flags)
adb install -r -g --no-streaming app.apk

# Wireless ADB (QUAS standard)
adb tcpip 5555

# Media Copy (QUAS paths)
adb pull /sdcard/Oculus/Screenshots
adb pull /sdcard/Oculus/Videoshots
```

All commands have been tested and proven in QUAS for reliability.

---

## Batch Operations Available

### Device Management
- Wireless ADB setup (all devices)
- USB debugging configuration
- ADB server restart
- Authorization check

### App Management
- Batch APK installation (`-r -g --no-streaming`)
- Batch app uninstallation
- List installed apps
- Grant permissions to all devices

### File Operations
- Push files to all devices
- Pull files from all devices
- Delete files from all devices
- Batch media collection

### System Settings
- Set brightness (0-255)
- Set volume (0-15)
- Enable/Disable Wi-Fi
- Set timezone
- Clear app cache
- Grant permissions

### Screenshots & Recording
- Batch screenshots (`exec-out screencap`)
- Batch screen recording
- Pull Oculus media folders
- Custom file transfers

### Certificate Management
- Deploy certificates to all devices
- Open certificate installer on all devices
- View installed certificates

---

## Version History

### v1.1.0 (Current)
- Updated to use proven QUAS ADB commands
- Screenshot: `exec-out screencap` (faster, more reliable)
- APK install: `install -r -g --no-streaming`
- Wireless ADB: `tcpip 5555`
- Media copy: Pull from `/sdcard/Oculus/Screenshots` and `/sdcard/Oculus/Videoshots`
- Save to `Desktop/QuestMedia` (same as QUAS)

### v1.0.0
- Initial release
- Multi-device detection
- Batch operations framework
- Menu-driven interface

---

## Credits

- **Original QUAS**: [Varset](https://github.com/Varsett) - Quest ADB Scripts v5.2.0
- **MultiQuest Manager**: Created for batch operations on multiple Quest devices
- **Website**: www.vrcomm.ru (original QUAS)

---

## Branch Structure

- **`main`** - Stable release with MultiQuest Manager
- **`multiquest`** - Development branch for MultiQuest features

---

## Contributing

This is a fork focused on adding multi-device batch capabilities. For issues with the original QUAS functionality, please refer to the [original repository](https://github.com/Varsett/Quas).

For MultiQuest Manager issues or suggestions:
1. Open an issue in this repository
2. Describe the batch operation use case
3. Include number of devices and error details if applicable

---

## License

This fork maintains the same license as the original QUAS project.

---

## Support

- **MultiQuest Manager**: Open an issue in this repository
- **Original QUAS**: https://github.com/Varsett/Quas

---

**Happy Multi-Quest Managing! 🥽🥽🥽**
