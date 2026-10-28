# PC Manager

A local app for tuning up a Windows 10 or 11 laptop. Everything runs on your own machine: nothing is installed, nothing is downloaded, and nothing is sent anywhere.

## Run it

1. Copy the `pc-manager` folder to your laptop. If you downloaded the repo as a ZIP, extract it first.
2. Double-click **`Start PC Manager.bat`**.
3. Choose **Yes** when Windows asks for permission. If you choose No, PC Manager still opens, but features that need administrator rights are switched off.

If Windows SmartScreen warns about the file, click **More info**, then **Run anyway**. You can also right-click `PCManager.ps1`, choose **Properties**, and tick **Unblock**.

## What it does

| Section | What you can do |
| --- | --- |
| **Overview** | See memory, processor, disk and battery at a glance, with suggestions. **Quick tune-up** cleans safe temporary files and caches in one click. |
| **Clean up** | Scan for and delete temporary files, error reports, the thumbnail cache, browser caches, old Windows Update downloads and the Recycle Bin. You pick what to delete. |
| **Startup apps** | Stop apps from starting when you sign in. Untick to turn one off; tick to turn it back on. It's the same switch Task Manager uses. |
| **Apps & processes** | See which apps use the most memory and CPU, and end one if it's stuck or hogging resources. Windows' own processes are protected. |
| **Power & battery** | Switch power plans, check battery health, and create a battery report or a one-minute energy check. |
| **Tweaks** | Turn transparency effects, Game Mode, game capture, Windows tips, Storage Sense, background Store apps, GPU scheduling and hibernation on or off. Each tweak shows its current setting and a suggestion. |
| **Maintenance** | Create a restore point, repair Windows (DISM and SFC), optimize drives, check drive health, scan for disk errors, update Windows and apps (winget), and clear the DNS cache. |

## Safety

- **Your files are never touched.** Clean up only deletes from temp folders, caches and the Recycle Bin. Documents, photos, downloads, passwords and browser history are left alone.
- **Temp files from the last 24 hours are kept**, in case an app or installer is still using them. Files that are in use are skipped.
- **Clean up never follows folder links or junctions**, so it can't reach anything outside the folders it lists.
- **Every tweak and startup change can be undone** by switching it back in the app.
- **Long jobs open in their own window** (repairs, drive optimization, restore points), so you can see exactly what's running.
- **Everything is logged** to `%LOCALAPPDATA%\PCManager\activity.log`.
- Reports (battery, energy) are saved in `Documents\PC Manager Reports`.

Before changing a lot at once, use **Maintenance > Create restore point**.

## Good to know

- Requires Windows 10 or 11. It uses Windows PowerShell 5.1, which is built in.
- PC Manager acts on the account that approved the permission prompt. If you use a standard account and type in someone else's admin password, Clean up and Tweaks apply to that admin account instead of yours. Sign in as an administrator to avoid this.
- Some tweaks only take full effect after you sign out or restart. The app tells you when a restart is needed.
- To start without the permission prompt (limited mode), run:
  `powershell -ExecutionPolicy Bypass -File PCManager.ps1 -NoElevate`
