# MultiQuest Manager v1.0.0

**Batch ADB Manager for Multiple Meta Quest Devices**

Inspired by Quest ADB Scripts by Varset - Enhanced for managing multiple Quest devices simultaneously.

---

## Features

### Device Management
- Auto-detect all connected Quest devices (USB)
- Connect/disconnect devices via Wi-Fi (wireless ADB)
- Check ADB authorization status
- Restart ADB server
- Display detailed device information (battery, storage, IP, etc.)

### Batch Operations
- **App Management**: Install/uninstall APKs to all devices at once
- **File Operations**: Push/pull/delete files across all devices
- **Certificate Management**: Deploy SSL certificates to multiple devices
- **System Settings**: Apply settings (brightness, volume, Wi-Fi, etc.) to all devices
- **Screenshots & Recording**: Capture screenshots or record screens from all devices simultaneously

### Execution Modes
- **Sequential**: Process devices one by one with detailed feedback
- **Parallel**: Execute commands on all devices simultaneously for faster operations

---

## Requirements

- **Windows 10/11** with PowerShell 5.1+
- **ADB (Android Debug Bridge)** installed and in PATH
- **Meta Quest devices** with USB debugging enabled
- **USB cable** or **Wi-Fi connection** for each device

### Installing ADB

If you don't have ADB installed:

1. Download [Platform Tools](https://developer.android.com/studio/releases/platform-tools)
2. Extract to `C:\platform-tools\`
3. Add to PATH:
   ```powershell
   $env:Path += ";C:\platform-tools"
   [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)
   ```

---

## Quick Start

### 1. Enable Developer Mode on Quest

1. Open Meta Quest app on your phone
2. Go to: Menu → Devices → [Your Quest] → Developer Mode
3. Toggle **Developer Mode** ON

### 2. Enable USB Debugging on Quest

1. Put on your Quest headset
2. Connect via USB to your PC
3. Accept the USB debugging prompt in VR
4. Check "Always allow from this computer"

### 3. Run MultiQuest Manager

```powershell
PowerShell -ExecutionPolicy Bypass -File MultiQuest-Manager.ps1
```

The script will automatically detect all connected Quest devices.

---

## Main Menu Options

### [1] Device Management
- **Connect via Wi-Fi**: Enable wireless ADB on all devices
- **Disconnect wireless**: Disconnect Wi-Fi ADB connections
- **USB Debugging**: Open USB debugging settings on all devices
- **Check authorization**: View ADB authorization status
- **Restart ADB**: Restart ADB server

### [2] App Management (Batch)
- **Install APK**: Install an APK to all connected devices
- **Uninstall app**: Remove an app from all devices
- **List apps**: View installed packages on each device
- **Backup/Restore**: Backup or restore app data (coming soon)

### [3] File Operations (Batch)
- **Push file**: Copy a file from PC to all devices
- **Pull file**: Download a file from all devices to PC
- **Delete file**: Remove a file from all devices
- **List files**: View directory contents on all devices

### [4] System Settings (Apply to All)
- **Screen brightness**: Set brightness level (0-255)
- **Volume level**: Set volume (0-15)
- **Wi-Fi**: Enable/disable Wi-Fi
- **Timezone**: Set timezone
- **Clear cache**: Clear app cache for all apps
- **Grant permissions**: Grant app permissions
- **Developer options**: Open developer settings

### [5] Screenshot / Screen Record
- **Screenshot**: Take screenshots from all devices
- **Start recording**: Record screens (up to 180 seconds)
- **Stop recording**: Stop ongoing recordings
- **Pull media**: Download screenshots/recordings to PC

### [6] Certificate Management
- **Push certificate**: Copy SSL certificate to all devices
- **Open installer**: Launch certificate installer on all devices
- **View certificates**: Show installed certificates

### [7] Reboot Devices
- Reboot all connected devices simultaneously

### [8] Device Information
- View detailed info for each device:
  - Model and brand
  - Android version
  - Battery level
  - IP address
  - Storage usage

### [9] Refresh Device List
- Re-scan for connected Quest devices

---

## Usage Examples

### Example 1: Install APK to Multiple Quests

1. Connect all Quest devices via USB
2. Run MultiQuest Manager
3. Select `[2] App Management`
4. Select `[1] Install APK to all devices`
5. Enter APK path: `C:\Apps\myapp.apk`
6. Wait for installation to complete on all devices

### Example 2: Deploy SSL Certificate

1. Connect all Quest devices
2. Select `[6] Certificate Management`
3. Select `[1] Push certificate to all devices`
4. Enter certificate path: `C:\Appz\ssl\server-cert.p12`
5. Select `[2] Open certificate installer`
6. Put on each Quest and complete installation

### Example 3: Wireless ADB Setup

1. Connect all Quests via USB (first time)
2. Select `[1] Device Management`
3. Select `[1] Connect device via Wi-Fi`
4. Note the IP addresses displayed
5. Disconnect USB cables
6. Devices remain connected via Wi-Fi

To reconnect later:
```powershell
adb connect 192.168.1.100:5555
adb connect 192.168.1.101:5555
```

### Example 4: Batch Screenshots

1. Connect all devices
2. Select `[5] Screenshot / Screen Record`
3. Select `[1] Take screenshot`
4. Screenshots saved to `/sdcard/Download/` on each device
5. Choose to pull screenshots to PC
6. Find screenshots in `.\Screenshots_[timestamp]\` folder

### Example 5: Apply System Settings

1. Connect all devices
2. Select `[4] System Settings`
3. Select `[1] Set screen brightness`
4. Enter brightness: `150`
5. Brightness applied to all devices instantly

---

## Tips & Tricks

### Selecting Specific Devices

Currently, all batch operations apply to **all connected devices**. To operate on specific devices:

1. Disconnect unwanted devices
2. Or modify `$script:ConnectedDevices` array in the script

### Wireless ADB (Wi-Fi)

Benefits:
- No USB cables needed
- Move around freely
- Easier device management

Limitations:
- Slightly slower than USB
- Requires initial USB connection to set up
- Both PC and Quest must be on same network

### Performance

- **Parallel mode**: Faster but less detailed output
- **Sequential mode**: Slower but shows progress for each device

For most operations, sequential mode is recommended for better visibility.

### Common Issues

**"No devices detected"**
- Ensure USB debugging is enabled
- Accept USB debugging prompt on Quest
- Try: `adb kill-server` then `adb start-server`
- Check USB cable connection

**"Unauthorized device"**
- Put on Quest and accept USB debugging prompt
- Check "Always allow from this computer"

**"Certificate installation failed"**
- Quest 3 restricts manual certificate installation
- Use `network_security_config.xml` in your Android app instead
- See: [QUEST3_SETUP.md](QUEST3_SETUP.md)

**Script execution policy error**
- Run as Administrator:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
  ```

---

## Advanced Configuration

### Custom Commands

The `Invoke-BatchCommand` function can execute any ADB command across all devices:

```powershell
Invoke-BatchCommand -Description "Custom operation" -Command {
    param($dev)
    & adb -s $dev.ID shell your-command-here
}
```

### Filtering Devices

To operate only on specific Quest models:

```powershell
$filteredDevices = $script:ConnectedDevices | Where-Object { $_.Model -eq "Quest 3" }
Invoke-BatchCommand -Devices $filteredDevices -Command { ... }
```

---

## File Structure

```
c:\Appz\ssl\
├── MultiQuest-Manager.ps1          # Main script
├── MULTIQUEST_MANAGER_README.md    # This file
├── server-cert.pem                 # SSL certificate
├── server-key.pem                  # SSL key
├── mediamtx.yml                    # MediaMTX config
├── Android_network_security_config.xml
├── QUEST3_SETUP.md                 # Quest 3 setup guide
└── Screenshots_*/                  # Screenshot output folders
```

---

## Version History

### v1.0.0 (2025-01-22)
- Initial release
- Automatic device detection
- Batch app management
- Batch file operations
- Certificate management
- System settings configuration
- Screenshot and screen recording
- Device information display
- Wireless ADB support

---

## Credits

- **Inspired by**: Quest ADB Scripts by Varset v5.2.0
- **Created for**: Managing multiple Meta Quest headsets simultaneously
- **Website**: www.vrcomm.ru (original QUAS)

---

## License

This tool is provided as-is for educational and development purposes.

---

## Support

For issues related to:
- **MediaMTX SSL setup**: See [LEEME_PRIMERO.md](LEEME_PRIMERO.md)
- **Quest 3 certificates**: See [QUEST3_SETUP.md](QUEST3_SETUP.md)
- **Unreal Engine integration**: See [UNREAL_ENGINE_SETUP.md](UNREAL_ENGINE_SETUP.md)

---

## Changelog & Roadmap

### Planned Features
- GUI version with WPF
- Device filtering/selection
- Custom command presets
- Automated testing workflows
- Log file generation
- App data backup/restore completion
- Network performance testing
- Memory analysis tools

---

**Happy Quest Managing! 🥽**
