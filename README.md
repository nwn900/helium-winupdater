[Getting started](#getting-started) * [Settings](#settings) * [Issues](#issues) * [Credits](#credits)
<img src="Helium-WinUpdater.ico" align="right">

# Helium WinUpdater

A Windows updater for the [Helium browser](https://github.com/imputnet/helium), ported from the [LibreWolf WinUpdater](https://codeberg.org/librewolf/winupdater) by ltGuillaume.

## Getting started

### Helium Setup

- Download and extract the latest `Helium-WinUpdater.zip` from the [releases page](https://github.com/imputnet/helium/releases), then run `Helium-WinUpdater.exe` to check for an update. If one is available, it will be downloaded immediately.
- On first run, Helium WinUpdater will copy itself to `%AppData%\Helium\WinUpdater` to be able to update itself without administrator privileges.

### Helium Portable

- If you want to run the portable version of Helium, download and extract `helium_x.x.x_x64-windows.zip` from [helium-windows releases](https://github.com/imputnet/helium-windows/releases/latest).
- Place `Helium-WinUpdater.exe` in the same directory as the `Helium` folder (not inside it). The updater will detect the portable installation automatically.

### Scheduled updates

- You can run Helium WinUpdater to enable the option `Schedule a task for automatic update checks`. This will prompt for administrator permissions and a PowerShell window will notify you of the result. The scheduled task will run while the **current user account** is logged in (at 1 minute after login, and every 4 hours).
- If your account has **administrator permissions**, the update will be fully automatic. If not, the update will be downloaded and you will be asked to start the update (administrator permissions required).
- If Helium is already **running**, you will be notified about the new version. The update will start as soon as you close the browser.

## Settings

### Settings and log file

- The updater needs to be able to write to `Helium-WinUpdater.ini` in its own folder (so make sure it has permission to do so), otherwise WinUpdater will copy itself to `%AppData%\Helium\WinUpdater` and run from there.
- `Helium-WinUpdater.ini` contains a `[Log]` section that shows the results of the last update check and the last update action.

### Changing the working directory

If for some reason WinUpdater is not able to use the user's default `%Temp%` folder for downloading and extracting files, you can specify an alternative work directory by setting `WorkDir` in the .ini file under `[Settings]`:

```ini
[Settings]
WorkDir=D:\Temp
```

To specify the directory of `Helium-WinUpdater.exe`, use `WorkDir=.`, or use a relative subfolder like `WorkDir=.\Temp`.

## Coexistence with LibreWolf WinUpdater

Helium WinUpdater uses separate file names, task names, and folder paths from the LibreWolf WinUpdater. Both can be installed and run simultaneously without conflicts.

## Issues

### Anti-cheat software

If you set up scheduled updates, you might get annoyed by some anti-cheat software. It may wrongfully point at WinUpdater, because it is built upon AutoHotkey, which *can* be used to cheat in games. If this happens, you can either:
  1. Open the **Task Scheduler** via the Start menu, then double-click on `Helium WinUpdater...` in the `Task Scheduler Library`, open the `Triggers` tab, then click on `One time` and the button `Delete`. Then press `OK` to make the change to *only check for updates 1 minute after login* (and not every 4 hours).
  2. Create a shortcut to `%AppData%\Helium\WinUpdater\Helium-WinUpdater.exe /RemoveTask` and one to `%AppData%\Helium\WinUpdater\Helium-WinUpdater.exe /CreateTask` (on your desktop), so you can quickly prevent WinUpdater from running during gameplay and reactivate it afterwards.

### Server certificate revocation

You may encounter a `Security Alert: Revocation information for the Security certificate for this site is not available` Windows dialog or a `The server certificate revocation check for (...) has failed` warning by WinUpdater. You can tell WinUpdater to automatically continue when this dialog pops up by setting `IgnoreCrlErrors` to `1` in the .ini file under `[Settings]`:

```ini
[Settings]
IgnoreCrlErrors=1
```

## Credits

- [Helium Browser](https://github.com/imputnet/helium) by [imput](https://imput.net/)
- [Original LibreWolf WinUpdater](https://codeberg.org/librewolf/winupdater) by [ltGuillaume](https://codeberg.org/ltguillaume)
- [LibreWolf](https://librewolf.net) by the [LibreWolf Community](https://librewolf.net/#core-contributors)
