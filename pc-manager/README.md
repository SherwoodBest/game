# PC Manager

A local app for keeping a Windows 10 or 11 laptop fast, tidy and healthy. It runs entirely on your own machine: nothing is installed, nothing is downloaded, and nothing is sent anywhere.

## Run it

1. Copy the `pc-manager` folder to your laptop. If you downloaded the repo as a ZIP, extract it first.
2. Double-click **`Start PC Manager.bat`**.
3. Choose **Yes** when Windows asks for permission. If you choose No, PC Manager opens in *limited mode*: features that need administrator rights are marked, and you can restart as administrator from the badge in the title bar.

If Windows SmartScreen warns about the file, click **More info**, then **Run anyway**.

Tip: **Settings > Add desktop shortcut** gives you a desktop icon that starts PC Manager without the extra console window.

## What's inside

| Page | What you can do |
| --- | --- |
| **Home** | A health score out of 100, with a scan that starts by itself. **Fix all** removes safe junk in one click. Recommendations come with their own fix button, alongside quick actions and a summary of your PC. |
| **Cleaner** | Scan temporary files, error reports, the thumbnail cache, browser caches, old Windows Update downloads and the Recycle Bin. Tick what to remove, then **Clean now**. |
| **Storage** | See how full each drive is, and find large files in your own folders. Open their folder or move them to the Recycle Bin. |
| **Startup apps** | Switch off apps that start at sign-in, with icons, publishers and search. It uses the same switch as Task Manager. |
| **Running apps** | See what's using memory and CPU right now, and end an app that's stuck. Windows' own processes are protected. |
| **Installed apps** | List everything installed, sort by name, size or date, and uninstall with the app's own uninstaller. |
| **Power & battery** | Pick a power plan, see battery health and charge cycles, and create a battery report or a one-minute energy check. |
| **Tweaks** | Switches for transparency, animations, web results in Start search, Game Mode, game capture, GPU scheduling, background Store apps, hibernation, Windows tips and Storage Sense. Each shows a suggestion, and **Apply suggested** sets them all at once. |
| **Toolbox** | Restore points, Windows repair (DISM and SFC), drive optimization, drive health, a disk error scan, Windows and app updates (winget), DNS cache, Reliability history, Device Manager and more. |
| **Settings** | Light, dark or system theme. You can also turn off the confirmation before deleting, view recent activity, and add a desktop shortcut. |

Scans and clean-ups run in the background, so the window never freezes, and you can cancel long scans.

## Safety

- **Your files are never touched by the cleaner.** It only deletes from temp folders, caches and the Recycle Bin. Documents, photos, downloads, passwords and browser history are left alone.
- **Large files go to the Recycle Bin**, never straight to deletion, and only when you ask.
- **Temp files from the last 24 hours are kept**, in case an app or installer still needs them. Files in use are skipped.
- **The cleaner never follows folder links or junctions**, so it can't reach anything outside the folders it lists.
- **Every tweak and startup change can be switched back** in the app.
- **You're asked before anything is deleted or ended.** Emptying the Recycle Bin always asks, even if you turn confirmations off.
- **Everything is logged** in Settings > Recent activity. The full log is at `%LOCALAPPDATA%\PCManager\activity.log`.

Before changing a lot at once, use **Toolbox > Create restore point**.

## Good to know

- Needs Windows 10 or 11. It uses Windows PowerShell 5.1 and WPF, which are built in.
- PC Manager acts on the account that approved the permission prompt. If you use a standard account and type in someone else's admin password, Cleaner and Tweaks apply to that admin account instead. Sign in as an administrator to avoid this.
- Some tweaks only take full effect after you sign out or restart. Each one is labelled.
- To start without the permission prompt (limited mode):
  `powershell -ExecutionPolicy Bypass -File PCManager.ps1 -NoElevate`

## Project layout

```
Start PC Manager.bat   launcher (double-click this)
PCManager.ps1          entry point: admin check, loads everything, opens the window
engine/                what the app does, with no window code (also used by the background worker)
  Common.ps1           registry, formatting, safe folder walking
  Cleaner.ps1          clean-up categories, measuring and deleting
  System.ps1           PC details, health score, running apps, large files, installed apps, drive health
  Startup.ps1          startup apps (Task Manager's on/off switch)
  Tweaks.ps1           tweaks and power plans
ui/
  Theme.xaml           styles: buttons, switches, cards, scroll bars
  Shell.xaml           window frame: title bar, sidebar, dialog, notifications
  Core.ps1             theme colors, dialogs, notifications, background worker, navigation
  Widgets.ps1          shared list rows, bars and tiles
  pages/               one .xaml layout and one .ps1 logic file per page
```
