<#
  Name:             Set Display Mode
  Description:      Switches a display's refresh rate and/or resolution for one game
                    and puts the previous mode back when the game exits.
  Author:           TrayTrigger
  Version:          1.0
  Phase:            both
  Needs admin:      no
  Dependencies:     none
  Script Arguments: a refresh rate ("144"), a resolution ("1920x1080"), or both, in
                    any order. "display:2" picks the second display instead of the
                    primary one.

  Once this file is in your scripts folder it is yours: TrayTrigger never changes
  it. Settings that vary by PC belong in Edit Game > Script Arguments.

  WHY
    An older game runs best at 60 Hz, a competitive one wants your monitor's
    fastest mode while the desktop sits at a calmer one, or a game that only
    knows 1920x1080 stretches badly on an ultrawide unless the desktop is
    already at that resolution. Changing the mode by hand before and after
    every session gets old. This script does it for the games you choose it
    for, and puts the mode you had back when you quit.

  SET IT UP
    1. In Edit Game, choose this file as the pre-launch script and tick "Use
       the same script for pre-launch and post-exit".
    2. In Script Arguments, type the mode you want while the game runs:
         144             the refresh rate only, at the current resolution
         1920x1080       the resolution only, at the current refresh rate
         1920x1080 60    both
       Add display:2 (or 3, ...) to change a display other than the primary.
    3. Press Test next to the pre-launch box: the display switches. Press Test
       next to the post-exit box: it switches back.
    4. Tick "Wait for the pre-launch script to finish", so the game starts
       after the switch, not during it.

  HOW IT WORKS
    prelaunch  Reads the display's current mode, writes it to a note in your
               TEMP folder named after the game ID, and asks Windows for the
               mode you named. Windows refuses a mode the display doesn't
               offer, and the script says so and changes nothing.
    postexit   Reads the note, puts that mode back, and deletes the note.
               Nothing happens if the pre-launch run changed nothing.

  SAYING WHAT IT DID
    A line this script prints starting with "TT:" is for the player:
    TrayTrigger 1.6.1 and later put it on the game's Played row in Activity &
    History and show it in the launch popup before the game. Older versions
    treat it as ordinary output.

  GOOD TO KNOW
    The change is the same one Windows Settings > Display makes, and it is
    temporary: a sign-out or restart also puts the registered mode back.
    A game set to "exclusive fullscreen" picks its own mode anyway; this is
    for borderless and windowed games, and for the desktop around them.
    HDR is not touched. Use TrayTrigger's own HDR choice in Edit Game for that.

  MAKE IT YOURS
    To switch two displays, copy this file and give each copy its own
    display:N argument, one as the game's script and one as a default script.
#>
param(
    [string]$Phase,
    [string]$GameName,
    [string]$GameExe,
    [string]$GameId,
    [string]$Playtime,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

$note = Join-Path $env:TEMP "TrayTrigger-DisplayMode-$GameId.txt"

# The Windows calls that list displays and read and set a display mode: the same ones
# Windows Settings > Display uses. In C#, because PowerShell can't hand a struct to
# Windows by reference itself.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace TrayTriggerScripts
{
    public static class Display
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DEVMODE
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
            public ushort dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
            public uint dmFields;
            public int dmPositionX, dmPositionY;
            public uint dmDisplayOrientation, dmDisplayFixedOutput;
            public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
            public ushort dmLogPixels;
            public uint dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
            public uint dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct DISPLAY_DEVICE
        {
            public uint cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public uint StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern bool EnumDisplaySettings(string lpszDeviceName, int iModeNum, ref DEVMODE lpDevMode);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        static extern int ChangeDisplaySettingsEx(string lpszDeviceName, ref DEVMODE lpDevMode, IntPtr hwnd, uint dwflags, IntPtr lParam);

        const int ENUM_CURRENT_SETTINGS = -1;
        const uint DM_PELSWIDTH = 0x80000, DM_PELSHEIGHT = 0x100000, DM_DISPLAYFREQUENCY = 0x400000;
        const uint ATTACHED_TO_DESKTOP = 0x1, PRIMARY_DEVICE = 0x4;

        /// Each display attached to the desktop as "name|description|primary", the primary first.
        public static string[] AttachedDevices()
        {
            var primary = new List<string>();
            var others = new List<string>();
            for (uint i = 0; ; i++)
            {
                var d = new DISPLAY_DEVICE();
                d.cb = (uint)Marshal.SizeOf(typeof(DISPLAY_DEVICE));
                if (!EnumDisplayDevices(null, i, ref d, 0)) break;
                if ((d.StateFlags & ATTACHED_TO_DESKTOP) == 0) continue;
                bool isPrimary = (d.StateFlags & PRIMARY_DEVICE) != 0;
                (isPrimary ? primary : others).Add(d.DeviceName + "|" + d.DeviceString + "|" + (isPrimary ? "1" : "0"));
            }
            primary.AddRange(others);
            return primary.ToArray();
        }

        /// The display's current width, height and refresh rate, or null when it can't be read.
        public static int[] CurrentMode(string deviceName)
        {
            var m = new DEVMODE();
            m.dmSize = (ushort)Marshal.SizeOf(typeof(DEVMODE));
            if (!EnumDisplaySettings(deviceName, ENUM_CURRENT_SETTINGS, ref m)) return null;
            return new[] { (int)m.dmPelsWidth, (int)m.dmPelsHeight, (int)m.dmDisplayFrequency };
        }

        /// Asks Windows for the mode. 0 means it took; -2 means the display doesn't offer it.
        public static int Change(string deviceName, int width, int height, int hz)
        {
            var m = new DEVMODE();
            m.dmSize = (ushort)Marshal.SizeOf(typeof(DEVMODE));
            m.dmPelsWidth = (uint)width;
            m.dmPelsHeight = (uint)height;
            m.dmDisplayFrequency = (uint)hz;
            m.dmFields = DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY;
            return ChangeDisplaySettingsEx(deviceName, ref m, IntPtr.Zero, 0, IntPtr.Zero);
        }
    }
}
'@

# The Nth display attached to the desktop (1 = the primary): its Windows name (\\.\DISPLAY1) and description.
function Get-DisplayDevice([int]$index) {
    $devices = @([TrayTriggerScripts.Display]::AttachedDevices())
    if ($devices.Count -eq 0 -or $index -gt $devices.Count) { return $null }
    $parts = $devices[[Math]::Max(1, $index) - 1] -split '\|'
    # Named for the player as "the primary display" or "display 2": Windows' own description is the graphics card.
    return [pscustomobject]@{ Name = $parts[0]; Description = $(if ($index -le 1) { 'the primary display' } else { "display $index" }) }
}

function Describe-Mode($width, $height, $hz) { "{0}x{1} at {2} Hz" -f $width, $height, $hz }

switch ($Phase) {
    'prelaunch' {
        # Read what was asked for: a refresh rate, a resolution, a display number.
        $wantHz = 0; $wantW = 0; $wantH = 0; $displayIndex = 1
        foreach ($arg in $ScriptArgs) {
            if ($arg -match '^(\d{3,5})x(\d{3,5})$') { $wantW = [int]$Matches[1]; $wantH = [int]$Matches[2] }
            elseif ($arg -match '^(\d{2,3})(hz)?$') { $wantHz = [int]$Matches[1] }
            elseif ($arg -match '^display:(\d+)$') { $displayIndex = [int]$Matches[1] }
            else { Write-Output "Ignoring '$arg': not a refresh rate (144), a resolution (1920x1080) or display:N." }
        }
        if ($wantHz -eq 0 -and $wantW -eq 0) {
            Write-Output 'TT: no mode named. Put a refresh rate (144), a resolution (1920x1080) or both in Edit Game > Script Arguments.'
            exit 1
        }

        $device = Get-DisplayDevice $displayIndex
        if (-not $device) {
            Write-Output "TT: display $displayIndex isn't attached, so the mode was left alone"
            exit 1
        }
        $current = [TrayTriggerScripts.Display]::CurrentMode($device.Name)
        if (-not $current) {
            Write-Output "TT: couldn't read the current mode of $($device.Description), so it was left alone"
            exit 1
        }
        $curW, $curH, $curHz = $current

        # What isn't named stays as it is.
        if ($wantW -eq 0) { $wantW = $curW; $wantH = $curH }
        if ($wantHz -eq 0) { $wantHz = $curHz }

        $from = Describe-Mode $curW $curH $curHz
        $to = Describe-Mode $wantW $wantH $wantHz
        if ($wantW -eq $curW -and $wantH -eq $curH -and $wantHz -eq $curHz) {
            Write-Output "TT: $($device.Description) is already at $to"
            exit 0
        }

        $result = [TrayTriggerScripts.Display]::Change($device.Name, $wantW, $wantH, $wantHz)
        if ($result -ne 0) {
            $why = if ($result -eq -2) { "it doesn't offer $to" } else { "Windows refused the change (code $result)" }
            Write-Output "TT: $($device.Description) stays at ${from}: $why"
            exit 1
        }

        # Remember what to put back. Device name first, so the post-exit run finds the same display.
        Set-Content -LiteralPath $note -Value @($device.Name, $curW, $curH, $curHz)
        Write-Output "Switched $($device.Name) from $from to $to."
        Write-Output "TT: $($device.Description) switched to $to, back to $from after the game"
    }

    'postexit' {
        if (-not (Test-Path -LiteralPath $note)) {
            Write-Output 'The pre-launch run changed nothing, so there is nothing to put back.'
            exit 0
        }
        $lines = @(Get-Content -LiteralPath $note)
        Remove-Item -LiteralPath $note -Force
        if ($lines.Count -lt 4) {
            Write-Output 'TT: the note of the previous mode was damaged, so the display was left as it is'
            exit 1
        }
        $deviceName = $lines[0]; $w = [int]$lines[1]; $h = [int]$lines[2]; $hz = [int]$lines[3]
        $back = Describe-Mode $w $h $hz

        $current = [TrayTriggerScripts.Display]::CurrentMode($deviceName)
        if ($current -and $current[0] -eq $w -and $current[1] -eq $h -and $current[2] -eq $hz) {
            Write-Output "TT: display already back at $back"
            exit 0
        }
        $result = [TrayTriggerScripts.Display]::Change($deviceName, $w, $h, $hz)
        if ($result -ne 0) {
            Write-Output "TT: couldn't put the display back to $back (code $result); use Windows Settings > Display"
            exit 1
        }
        Write-Output "TT: display back at $back"
    }

    default {
        Write-Output "Unknown phase '$Phase'."
        exit 1
    }
}

exit 0
