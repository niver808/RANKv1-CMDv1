<#
.SYNOPSIS
    RANK1 Cyberpunk Animated Console Installer UI
.DESCRIPTION
    Single-file, zero-dependency animated TUI installer compatible with Windows PowerShell 5.1 (conhost)
    and PowerShell 7+ (Windows Terminal). Save this file as UTF-8 with BOM.
#>

#region === ACTIONS (REPLACE WITH YOUR LOGIC) ===

function Invoke-Install {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Report
    )

    # TODO: Replace these placeholder steps with your actual installation logic.
    # Call: & $Report "<Step Description>" <PercentComplete 0..100>
    # Throw an exception (throw "Message") to trigger the animated error screen.

    & $Report "Validating system prerequisites..." 15
    Start-Sleep -Milliseconds 650

    & $Report "Extracting core payload archives..." 38
    Start-Sleep -Milliseconds 800

    & $Report "Configuring environment & registry keys..." 64
    Start-Sleep -Milliseconds 750

    & $Report "Registering background services..." 88
    Start-Sleep -Milliseconds 700

    & $Report "Finalizing installation & cleaning up..." 100
    Start-Sleep -Milliseconds 500
}

function Invoke-Uninstall {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Report
    )

    # TODO: Replace these placeholder steps with your actual uninstallation logic.

    & $Report "Stopping active RANK1 processes..." 20
    Start-Sleep -Milliseconds 600

    & $Report "Unregistering system services..." 45
    Start-Sleep -Milliseconds 700

    & $Report "Removing application binaries..." 75
    Start-Sleep -Milliseconds 800

    & $Report "Purging configuration & cache files..." 92
    Start-Sleep -Milliseconds 600

    & $Report "Uninstallation complete..." 100
    Start-Sleep -Milliseconds 450
}

#endregion

#region === CONFIG (THEME, TEXTS, SPEEDS) ===

$script:Config = @{
    # Window Dimensions & Identity
    Title        = "RANK1 INSTALLER"
    Subtitle     = "I N S T A L L E R   v1.0"
    Width        = 90
    Height       = 32
    FontName     = "Cascadia Mono"
    FallbackFont = "Consolas"
    FontSize     = 18

    # Cyberpunk Palette (RGB Arrays)
    BgColor      = @(5, 5, 12)         # Deep Void Black
    Purple       = @(124, 58, 237)     # #7C3AED Neon Purple
    Cyan         = @(6, 182, 212)      # #06B6D4 Electric Cyan
    White        = @(243, 244, 246)
    DimGray      = @(115, 120, 138)
    DarkGray     = @(65, 70, 85)
    BoxBorder    = @(95, 75, 165)
    Green        = @(16, 185, 129)
    BrightGreen  = @(52, 211, 153)
    DimGreen     = @(6, 95, 70)
    Yellow       = @(245, 158, 11)
    Red          = @(239, 68, 68)
    DarkRed      = @(127, 29, 29)

    # Animation Timings
    IdleFps      = 15
    BootCharMs   = 12
    GlitchFrames = 4
    GlitchDelay  = 28
    FadeSteps    = 8
    FadeDelay    = 45

    # UI Strings
    MenuItems    = @("INSTALL", "UNINSTALL", "EXIT")
    FooterHint   = "↑↓ navigate   ENTER select   ESC exit"
    BootLines    = @(
        "[ OK ] Initializing virtual terminal subsystem...",
        "[ OK ] Loading RANK1 deployment modules...",
        "[ OK ] Verifying console buffer & permissions...",
        "[ OK ] Ready."
    )
}

$script:BannerArt = @(
    "██████╗  █████╗ ███╗   ██╗██╗  ██╗  ██╗",
    "██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝ ███║",
    "██████╔╝███████║██╔██╗ ██║█████╔╝  ╚██║",
    "██╔══██╗██╔══██║██║╚██╗██║██╔═██╗   ██║",
    "██║  ██║██║  ██║██║ ╚████║██║  ██╗  ██║",
    "╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝  ╚═╝"
)

$script:SpinnerFrames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
$script:GlitchChars   = @("░", "▒", "▓", "█", "▄", "▀", "╬", "╪")
$script:e             = [char]27

#endregion

#region === CONSOLE SETUP & WIN32 INTEROP ===

$Win32Code = @"
using System;
using System.Runtime.InteropServices;

public class ConsoleNative {
    public const int STD_OUTPUT_HANDLE = -11;
    public const uint ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004;

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);

    [StructLayout(LayoutKind.Sequential)]
    public struct COORD {
        public short X;
        public short Y;
        public COORD(short x, short y) { X = x; Y = y; }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CONSOLE_FONT_INFO_EX {
        public uint cbSize;
        public uint nFont;
        public COORD dwFontSize;
        public uint FontFamily;
        public uint FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(
        IntPtr consoleOutput,
        bool maximumWindow,
        ref CONSOLE_FONT_INFO_EX consoleCurrentFontEx
    );
}
"@

if (-not ("ConsoleNative" -as [type])) {
    Add-Type -TypeDefinition $Win32Code -Language CSharp
}

function Initialize-Console {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $Host.UI.RawUI.WindowTitle = $script:Config.Title

    # Enable VT / 24-bit ANSI sequences on legacy conhost
    $handle = [ConsoleNative]::GetStdHandle([ConsoleNative]::STD_OUTPUT_HANDLE)
    $mode = 0
    if ([ConsoleNative]::GetConsoleMode($handle, [ref]$mode)) {
        $newMode = $mode -bor [ConsoleNative]::ENABLE_VIRTUAL_TERMINAL_PROCESSING
        [void][ConsoleNative]::SetConsoleMode($handle, $newMode)
    }

    # Configure Font (Skip cleanly if inside Windows Terminal)
    $isWindowsTerminal = -not [string]::IsNullOrEmpty($env:WT_SESSION)
    if (-not $isWindowsTerminal) {
        foreach ($fontName in @($script:Config.FontName, $script:Config.FallbackFont)) {
            try {
                $fontInfo = New-Object ConsoleNative+CONSOLE_FONT_INFO_EX
                $fontInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($fontInfo)
                $fontInfo.nFont = 0
                $fontInfo.dwFontSize = New-Object ConsoleNative+COORD(0, [short]$script:Config.FontSize)
                $fontInfo.FontFamily = 54 # FF_MODERN | FIXED_PITCH
                $fontInfo.FontWeight = 400
                $fontInfo.FaceName = $fontName
                if ([ConsoleNative]::SetCurrentConsoleFontEx($handle, $false, [ref]$fontInfo)) {
                    break
                }
            } catch {
                # Ignore font errors on unsupported hosts
            }
        }
    }

    # Resize Window & Buffer to 90x32
    $w = $script:Config.Width
    $h = $script:Config.Height
    try {
        $raw = $Host.UI.RawUI
        $maxW = $raw.MaxPhysicalWindowSize.Width
        $maxH = $raw.MaxPhysicalWindowSize.Height
        if ($maxW -gt 0 -and $w -gt $maxW) { $w = $maxW }
        if ($maxH -gt 0 -and $h -gt $maxH) { $h = $maxH }

        $script:Config.Width  = $w
        $script:Config.Height = $h

        $winSize = New-Object System.Management.Automation.Host.Size($w, $h)
        $bufSize = New-Object System.Management.Automation.Host.Size($w, $h)

        if ($raw.BufferSize.Width -lt $w -or $raw.BufferSize.Height -lt $h) {
            $raw.BufferSize = $bufSize
        }
        $raw.WindowSize = $winSize
        $raw.BufferSize = $bufSize
    } catch {
        # Fallback if terminal locks window dimensions (e.g., split pane in WT)
        $script:Config.Width  = [Math]::Max(70, [Console]::WindowWidth)
        $script:Config.Height = [Math]::Max(26, [Console]::WindowHeight)
    }

    # Set black background, hide cursor, clear screen
    [Console]::BackgroundColor = [ConsoleColor]::Black
    [Console]::ForegroundColor = [ConsoleColor]::Gray
    $bg = $script:Config.BgColor
    [Console]::Write("$($script:e)[?25l$($script:e)[48;2;$($bg[0]);$($bg[1]);$($bg[2])m$($script:e)[2J$($script:e)[H")
}

function Restore-Console {
    [Console]::Write("$($script:e)[0m$($script:e)[?25h")
    [Console]::ResetColor()
}

function Test-IsAdmin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-SystemInfoString {
    try {
        $os = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption
        $os = $os -replace "Microsoft ", "" -replace " Pro", "" -replace " Home", "" -replace " Enterprise", ""
    } catch {
        $os = "Windows $([System.Environment]::OSVersion.Version.Major)"
    }
    $user = $env:USERNAME
    return @{ OS = $os.Trim(); User = $user; IsAdmin = (Test-IsAdmin) }
}

#endregion

#region === DRAW HELPERS (FLICKER-FREE BUFFERED WRITES) ===

function Get-AnsiRgb {
    param([int[]]$Fg, [int[]]$Bg = $null)
    $bgArr = if ($null -eq $Bg) { $script:Config.BgColor } else { $Bg }
    return "$($script:e)[38;2;$($Fg[0]);$($Fg[1]);$($Fg[2])m$($script:e)[48;2;$($bgArr[0]);$($bgArr[1]);$($bgArr[2])m"
}

function Get-InterpolatedColor {
    param([int[]]$C1, [int[]]$C2, [double]$T)
    $clamped = [Math]::Max(0.0, [Math]::Min(1.0, $T))
    $r = [int][Math]::Round($C1[0] + ($C2[0] - $C1[0]) * $clamped)
    $g = [int][Math]::Round($C1[1] + ($C2[1] - $C1[1]) * $clamped)
    $b = [int][Math]::Round($C1[2] + ($C2[2] - $C1[2]) * $clamped)
    return @($r, $g, $b)
}

function Set-CursorSafe {
    param([int]$X, [int]$Y)
    $cx = [Math]::Max(0, [Math]::Min($script:Config.Width - 1, $X))
    $cy = [Math]::Max(0, [Math]::Min($script:Config.Height - 1, $Y))
    [Console]::SetCursorPosition($cx, $cy)
}

function Write-At {
    param(
        [int]$X,
        [int]$Y,
        [string]$Text,
        [int[]]$Fg = $script:Config.White,
        [int[]]$Bg = $script:Config.BgColor
    )
    Set-CursorSafe -X $X -Y $Y
    [Console]::Write("$(Get-AnsiRgb -Fg $Fg -Bg $Bg)$Text")
}

function Clear-Rect {
    param([int]$X, [int]$Y, [int]$Width, [int]$Height)
    $blank = " " * $Width
    $ansi  = Get-AnsiRgb -Fg $script:Config.White -Bg $script:Config.BgColor
    for ($row = 0; $row -lt $Height; $row++) {
        Set-CursorSafe -X $X -Y ($Y + $row)
        [Console]::Write("$ansi$blank")
    }
}

function Write-Gradient {
    param(
        [int]$X,
        [int]$Y,
        [string]$Text,
        [int[]]$StartColor = $script:Config.Purple,
        [int[]]$EndColor   = $script:Config.Cyan,
        [double]$Phase     = 0.0,
        [int[]]$Bg         = $script:Config.BgColor
    )
    $sb  = New-Object System.Text.StringBuilder
    $len = [Math]::Max(1, $Text.Length - 1)
    for ($i = 0; $i -lt $Text.Length; $i++) {
        # Smooth cosine wave shifting left-to-right based on Phase
        $pos = ($i / $len) - $Phase
        $wave = 0.5 - 0.5 * [Math]::Cos($pos * [Math]::PI * 2.0)
        $col = Get-InterpolatedColor -C1 $StartColor -C2 $EndColor -T $wave
        [void]$sb.Append("$(Get-AnsiRgb -Fg $col -Bg $Bg)$($Text[$i])")
    }
    Set-CursorSafe -X $X -Y $Y
    [Console]::Write($sb.ToString())
}

function Draw-Box {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width,
        [int]$Height,
        [int[]]$BorderColor = $script:Config.BoxBorder,
        [int[]]$FillColor   = $script:Config.BgColor,
        [string]$Title      = ""
    )
    $innerW = $Width - 2
    $horiz  = "─" * $innerW
    $fill   = " " * $innerW
    $bAnsi  = Get-AnsiRgb -Fg $BorderColor -Bg $FillColor
    $fAnsi  = Get-AnsiRgb -Fg $script:Config.White -Bg $FillColor

    # Top border
    Set-CursorSafe -X $X -Y $Y
    [Console]::Write("$bAnsi╭$horiz╮")

    if (-not [string]::IsNullOrEmpty($Title)) {
        $tStr = " $Title "
        $tX   = $X + [int](($Width - $tStr.Length) / 2)
        Write-At -X $tX -Y $Y -Text $tStr -Fg $BorderColor -Bg $FillColor
    }

    # Middle rows
    for ($row = 1; $row -lt ($Height - 1); $row++) {
        Set-CursorSafe -X $X -Y ($Y + $row)
        [Console]::Write("$bAnsi│$fAnsi$fill$bAnsi│")
    }

    # Bottom border
    Set-CursorSafe -X $X -Y ($Y + $Height - 1)
    [Console]::Write("$bAnsi╰$horiz╯")
}

function Draw-Progress {
    param(
        [int]$X,
        [int]$Y,
        [int]$Percent,
        [int]$BarWidth = 50
    )
    $pct    = [Math]::Max(0, [Math]::Min(100, $Percent))
    $filled = [int][Math]::Round(($pct / 100.0) * $BarWidth)
    $empty  = $BarWidth - $filled

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append("$(Get-AnsiRgb -Fg $script:Config.DimGray)[")

    for ($i = 0; $i -lt $filled; $i++) {
        $t = $i / [Math]::Max(1, ($BarWidth - 1))
        $col = Get-InterpolatedColor -C1 $script:Config.Purple -C2 $script:Config.Cyan -T $t
        [void]$sb.Append("$(Get-AnsiRgb -Fg $col)█")
    }

    if ($empty -gt 0) {
        [void]$sb.Append("$(Get-AnsiRgb -Fg $script:Config.DarkGray)$("░" * $empty)")
    }

    $pctText = (" {0,3}%" -f $pct)
    [void]$sb.Append("$(Get-AnsiRgb -Fg $script:Config.DimGray)]$(Get-AnsiRgb -Fg $script:Config.Cyan)$pctText")

    Set-CursorSafe -X $X -Y $Y
    [Console]::Write($sb.ToString())
}

function Draw-Banner {
    param([double]$Phase = 0.0, [int]$MaxLines = 6)
    $bannerW = $script:BannerArt[0].Length
    $startX  = [int](($script:Config.Width - $bannerW) / 2)
    $startY  = 3

    for ($i = 0; $i -lt $MaxLines; $i++) {
        $linePhase = $Phase - ($i * 0.03)
        Write-Gradient -X $startX -Y ($startY + $i) -Text $script:BannerArt[$i] -Phase $linePhase
    }
}

#endregion

#region === ANIMATIONS ===

function Invoke-AdminCheckPrompt {
    param([hashtable]$SysInfo)
    if ($SysInfo.IsAdmin) { return }

    $boxW = 54
    $boxH = 7
    $boxX = [int](($script:Config.Width - $boxW) / 2)
    $boxY = [int](($script:Config.Height - $boxH) / 2)

    Draw-Box -X $boxX -Y $boxY -Width $boxW -Height $boxH -BorderColor $script:Config.Yellow -Title "ELEVATION RECOMMENDED"
    Write-At -X ($boxX + 4) -Y ($boxY + 2) -Text "⚠  Installer is not running as Administrator." -Fg $script:Config.Yellow
    Write-At -X ($boxX + 4) -Y ($boxY + 4) -Text "Restart as Admin? [Y/N]: " -Fg $script:Config.White

    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Y) {
            Write-At -X ($boxX + 29) -Y ($boxY + 4) -Text "YES - Relaunching..." -Fg $script:Config.BrightGreen
            Start-Sleep -Milliseconds 350
            $scriptPath = $MyInvocation.PSCommandPath
            if ([string]::IsNullOrEmpty($scriptPath)) { $scriptPath = $PSCommandPath }
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
            Restore-Console
            exit 0
        }
        elseif ($key.Key -eq [ConsoleKey]::N -or $key.Key -eq [ConsoleKey]::Escape) {
            Write-At -X ($boxX + 29) -Y ($boxY + 4) -Text "NO  - Continuing..." -Fg $script:Config.DimGray
            Start-Sleep -Milliseconds 300
            Clear-Rect -X $boxX -Y $boxY -Width $boxW -Height $boxH
            break
        }
    }
}

function Invoke-BootAnimation {
    $startX = 12
    $startY = 6
    $rng = New-Object System.Random

    # 1. Type out fake system boot lines
    for ($lineIdx = 0; $lineIdx -lt $script:Config.BootLines.Count; $lineIdx++) {
        $line = $script:Config.BootLines[$lineIdx]
        $y = $startY + $lineIdx
        for ($c = 0; $c -lt $line.Length; $c++) {
            $color = if ($c -lt 6) { $script:Config.BrightGreen } else { $script:Config.Green }
            Write-At -X ($startX + $c) -Y $y -Text $line[$c] -Fg $color
            Start-Sleep -Milliseconds $script:Config.BootCharMs
        }
        Start-Sleep -Milliseconds 110
    }

    Start-Sleep -Milliseconds 250
    Clear-Rect -X $startX -Y $startY -Width 68 -Height ($script:Config.BootLines.Count + 1)

    # 2. Glitch reveal of the RANK1 banner line by line
    $bannerW = $script:BannerArt[0].Length
    $bStartX = [int](($script:Config.Width - $bannerW) / 2)
    $bStartY = 3

    for ($row = 0; $row -lt $script:BannerArt.Count; $row++) {
        $targetLine = $script:BannerArt[$row]
        for ($g = 0; $g -lt $script:Config.GlitchFrames; $g++) {
            $sb = New-Object System.Text.StringBuilder
            for ($col = 0; $col -lt $targetLine.Length; $col++) {
                if ($targetLine[$col] -eq ' ') {
                    [void]$sb.Append(' ')
                } else {
                    $gChar = $script:GlitchChars[$rng.Next(0, $script:GlitchChars.Count)]
                    [void]$sb.Append($gChar)
                }
            }
            $gColor = if ($g % 2 -eq 0) { $script:Config.Purple } else { $script:Config.Cyan }
            Write-At -X $bStartX -Y ($bStartY + $row) -Text $sb.ToString() -Fg $gColor
            Start-Sleep -Milliseconds $script:Config.GlitchDelay
        }
        # Settle final gradient line
        Write-Gradient -X $bStartX -Y ($bStartY + $row) -Text $targetLine -Phase (-$row * 0.03)
    }

    # Reveal Subtitle
    $subX = [int](($script:Config.Width - $script:Config.Subtitle.Length) / 2)
    Write-At -X $subX -Y 10 -Text $script:Config.Subtitle -Fg $script:Config.DimGray
    Start-Sleep -Milliseconds 150
}

function Invoke-MenuSelectFlash {
    param([int]$SelectedIndex, [int]$BoxX, [int]$BoxY, [int]$BoxW)
    $itemY = $BoxY + 2 + ($SelectedIndex * 2)
    $label = "  ▶  $($script:Config.MenuItems[$SelectedIndex])"
    $padded = $label.PadRight($BoxW - 4)

    for ($f = 0; $f -lt 3; $f++) {
        $bg = if ($f % 2 -eq 0) { $script:Config.Cyan } else { $script:Config.Purple }
        Write-At -X ($BoxX + 2) -Y $itemY -Text $padded -Fg $script:Config.White -Bg $bg
        Start-Sleep -Milliseconds 55
    }
}

function Invoke-FadeOutExit {
    $w = $script:Config.Width
    $h = $script:Config.Height
    $msg = "Goodbye."
    $msgX = [int](($w - $msg.Length) / 2)
    $msgY = [int]($h / 2)

    # Progressive sweep / dim wipe
    for ($step = 1; $step -le $script:Config.FadeSteps; $step++) {
        $t = $step / $script:Config.FadeSteps
        $shade = Get-InterpolatedColor -C1 $script:Config.Purple -C2 $script:Config.BgColor -T $t
        $rowsPerStep = [Math]::Ceiling($h / $script:Config.FadeSteps)
        $yStart = ($step - 1) * $rowsPerStep
        $yEnd   = [Math]::Min($h - 1, $yStart + $rowsPerStep)

        for ($y = $yStart; $y -le $yEnd; $y++) {
            Write-At -X 0 -Y $y -Text (" " * $w) -Fg $shade -Bg $script:Config.BgColor
        }
        Start-Sleep -Milliseconds $script:Config.FadeDelay
    }

    Write-At -X $msgX -Y $msgY -Text $msg -Fg $script:Config.Cyan
    Start-Sleep -Milliseconds 450
    Clear-Rect -X 0 -Y 0 -Width $w -Height $h
    Set-CursorSafe -X 0 -Y 0
}

#endregion

#region === SCREENS (CONFIRMATION, WORKING, RESULT) ===

function Show-ConfirmUninstall {
    $boxW = 46
    $boxH = 7
    $boxX = [int](($script:Config.Width - $boxW) / 2)
    $boxY = 14

    Clear-Rect -X ($boxX - 2) -Y ($boxY - 1) -Width ($boxW + 4) -Height ($boxH + 3)
    Draw-Box -X $boxX -Y $boxY -Width $boxW -Height $boxH -BorderColor $script:Config.Red -Title "CONFIRM UNINSTALL"
    Write-At -X ($boxX + 4) -Y ($boxY + 2) -Text "This will remove RANK1 from your PC." -Fg $script:Config.White
    Write-At -X ($boxX + 12) -Y ($boxY + 4) -Text "Are you sure? [Y/N]" -Fg $script:Config.Red

    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq [ConsoleKey]::Y) {
                Clear-Rect -X $boxX -Y $boxY -Width $boxW -Height $boxH
                return $true
            }
            if ($key.Key -eq [ConsoleKey]::N -or $key.Key -eq [ConsoleKey]::Escape) {
                Clear-Rect -X $boxX -Y $boxY -Width $boxW -Height $boxH
                return $false
            }
        }
        Start-Sleep -Milliseconds 30
    }
}

function Show-ResultScreen {
    param(
        [bool]$Success,
        [string]$ActionName,
        [string]$ErrorMessage = ""
    )

    $boxW = 54
    $boxH = if ($Success) { 5 } else { 7 }
    $baseX = [int](($script:Config.Width - $boxW) / 2)
    $boxY  = 22

    if ($Success) {
        $bannerText = "✔  $ActionName COMPLETE"
        $textX = $baseX + [int](($boxW - $bannerText.Length) / 2)

        # Pulse bright / dim 3 times
        for ($p = 0; $p -lt 6; $p++) {
            $isBright = ($p % 2 -eq 0)
            $bCol = if ($isBright) { $script:Config.BrightGreen } else { $script:Config.DimGreen }
            $tCol = if ($isBright) { $script:Config.White } else { $script:Config.Green }
            Draw-Box -X $baseX -Y $boxY -Width $boxW -Height $boxH -BorderColor $bCol
            Write-At -X $textX -Y ($boxY + 2) -Text $bannerText -Fg $tCol
            Start-Sleep -Milliseconds 160
        }
    }
    else {
        $bannerText = "✖  $ActionName FAILED"
        $errTrim = if ($ErrorMessage.Length -gt ($boxW - 6)) { $ErrorMessage.Substring(0, $boxW - 9) + "..." } else { $ErrorMessage }
        $offsets = @(-3, 3, -2, 2, -1, 1, 0)

        # Horizontal shake effect
        foreach ($dx in $offsets) {
            $curX = $baseX + $dx
            Clear-Rect -X ($baseX - 4) -Y $boxY -Width ($boxW + 8) -Height $boxH
            Draw-Box -X $curX -Y $boxY -Width $boxW -Height $boxH -BorderColor $script:Config.Red
            $tX = $curX + [int](($boxW - $bannerText.Length) / 2)
            $eX = $curX + [int](($boxW - $errTrim.Length) / 2)
            Write-At -X $tX -Y ($boxY + 2) -Text $bannerText -Fg $script:Config.Red
            Write-At -X $eX -Y ($boxY + 4) -Text $errTrim -Fg $script:Config.Yellow
            Start-Sleep -Milliseconds 45
        }
    }

    $prompt = "Press any key to return to menu..."
    $pX = [int](($script:Config.Width - $prompt.Length) / 2)
    Write-At -X $pX -Y ($boxY + $boxH + 1) -Text $prompt -Fg $script:Config.DimGray

    # Flush any buffered keypresses before waiting
    while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }
    [void][Console]::ReadKey($true)
}

function Invoke-ActionRunner {
    param(
        [ValidateSet("INSTALL", "UNINSTALL")]
        [string]$Mode
    )

    $w = $script:Config.Width
    Clear-Rect -X 0 -Y 12 -Width $w -Height ($script:Config.Height - 12)

    $barW = 50
    $barX = [int](($w - ($barW + 7)) / 2)
    $statusY = 13
    $barY    = 15
    $logStartY = 17

    $completedLogs = New-Object System.Collections.Generic.List[string]
    $currentStep   = "Initializing $Mode..."
    $currentPct    = 0
    $spinIdx       = 0

    # Callback passed into Invoke-Install / Invoke-Uninstall
    $reportCallback = {
        param([string]$StepText, [int]$Percent)

        # Mark previous step done in log list
        if ($script:LastStepText -and $script:LastStepText -ne $StepText) {
            $completedLogs.Add($script:LastStepText)
            if ($completedLogs.Count -gt 5) {
                $completedLogs.RemoveAt(0)
            }
        }
        $script:LastStepText = $StepText

        # Animate spinner smoothly during step transition
        for ($tick = 0; $tick -lt 4; $tick++) {
            $spinChar = $script:SpinnerFrames[$script:SpinCounter % $script:SpinnerFrames.Count]
            $script:SpinCounter++

            $headerLine = "$spinChar  $StepText".PadRight(62)
            Write-At -X $barX -Y $statusY -Text $headerLine -Fg $script:Config.Cyan
            Draw-Progress -X $barX -Y $barY -Percent $Percent -BarWidth $barW

            for ($l = 0; $l -lt $completedLogs.Count; $l++) {
                $logY = $logStartY + $l
                $entry = "  → $($completedLogs[$l])... done "
                Write-At -X $barX -Y $logY -Text $entry -Fg $script:Config.DimGray
                Write-At -X ($barX + $entry.Length) -Y $logY -Text "✔" -Fg $script:Config.BrightGreen
            }
            Start-Sleep -Milliseconds 45
        }
    }

    $script:LastStepText = $null
    $script:SpinCounter  = 0

    try {
        if ($Mode -eq "INSTALL") {
            Invoke-Install -Report $reportCallback
        } else {
            Invoke-Uninstall -Report $reportCallback
        }

        # Finalize last step log line
        if ($script:LastStepText) {
            $completedLogs.Add($script:LastStepText)
            if ($completedLogs.Count -gt 5) { $completedLogs.RemoveAt(0) }
            for ($l = 0; $l -lt $completedLogs.Count; $l++) {
                $logY = $logStartY + $l
                $entry = "  → $($completedLogs[$l])... done "
                Write-At -X $barX -Y $logY -Text $entry -Fg $script:Config.DimGray
                Write-At -X ($barX + $entry.Length) -Y $logY -Text "✔" -Fg $script:Config.BrightGreen
            }
        }

        Write-At -X $barX -Y $statusY -Text ("✔  $Mode finished.".PadRight(62)) -Fg $script:Config.BrightGreen
        Draw-Progress -X $barX -Y $barY -Percent 100 -BarWidth $barW
        Show-ResultScreen -Success $true -ActionName $Mode
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-At -X $barX -Y $statusY -Text ("✖  Error during $Mode".PadRight(62)) -Fg $script:Config.Red
        Show-ResultScreen -Success $false -ActionName $Mode -ErrorMessage $errMsg
    }
}

#endregion

#region === MENU LOOP ===

function Draw-MainMenu {
    param(
        [int]$SelectedIndex,
        [int]$PrevIndex,
        [hashtable]$SysInfo
    )
    $w = $script:Config.Width
    $boxW = 36
    $boxH = 9
    $boxX = [int](($w - $boxW) / 2)
    $boxY = 13

    # Only redraw full frame when needed
    Draw-Box -X $boxX -Y $boxY -Width $boxW -Height $boxH -BorderColor $script:Config.BoxBorder

    # Quick highlight slide transition if selection changed
    if ($PrevIndex -ne $SelectedIndex -and $PrevIndex -ge 0) {
        $oldY = $boxY + 2 + ($PrevIndex * 2)
        $midBg = Get-InterpolatedColor -C1 $script:Config.Purple -C2 $script:Config.BgColor -T 0.55
        Write-At -X ($boxX + 2) -Y $oldY -Text ("     $($script:Config.MenuItems[$PrevIndex])".PadRight($boxW - 4)) -Fg $script:Config.DimGray -Bg $midBg
        Start-Sleep -Milliseconds 25
    }

    for ($i = 0; $i -lt $script:Config.MenuItems.Count; $i++) {
        $itemY = $boxY + 2 + ($i * 2)
        $text  = $script:Config.MenuItems[$i]

        if ($i -eq $SelectedIndex) {
            # Gradient-tinted highlight bar for active selection
            $barText = "  ▶  $text".PadRight($boxW - 4)
            $sb = New-Object System.Text.StringBuilder
            for ($c = 0; $c -lt $barText.Length; $c++) {
                $t = $c / [Math]::Max(1, ($barText.Length - 1))
                $bgCol = Get-InterpolatedColor -C1 $script:Config.Purple -C2 $script:Config.Cyan -T $t
                # Darken slightly so white text pops with crisp contrast
                $bgCol = @(
                    [int]($bgCol[0] * 0.65),
                    [int]($bgCol[1] * 0.65),
                    [int]($bgCol[2] * 0.65)
                )
                [void]$sb.Append("$(Get-AnsiRgb -Fg $script:Config.White -Bg $bgCol)$($barText[$c])")
            }
            Set-CursorSafe -X ($boxX + 2) -Y $itemY
            [Console]::Write($sb.ToString())
        }
        else {
            $dimText = "     $text".PadRight($boxW - 4)
            Write-At -X ($boxX + 2) -Y $itemY -Text $dimText -Fg $script:Config.DimGray -Bg $script:Config.BgColor
        }
    }

    # System Info Line under box
    $adminVal = if ($SysInfo.IsAdmin) { "YES" } else { "NO" }
    $adminCol = if ($SysInfo.IsAdmin) { $script:Config.BrightGreen } else { $script:Config.Yellow }
    $prefix   = "OS: $($SysInfo.OS)  |  User: $($SysInfo.User)  |  Admin: "
    $totalLen = $prefix.Length + $adminVal.Length
    $infoX    = [int](($w - $totalLen) / 2)
    $infoY    = $boxY + $boxH + 2

    Write-At -X $infoX -Y $infoY -Text $prefix -Fg $script:Config.DimGray
    Write-At -X ($infoX + $prefix.Length) -Y $infoY -Text $adminVal -Fg $adminCol

    # Footer Hint
    $footX = [int](($w - $script:Config.FooterHint.Length) / 2)
    Write-At -X $footX -Y ($script:Config.Height - 2) -Text $script:Config.FooterHint -Fg $script:Config.DarkGray
}

function Start-InstallerUI {
    $sysInfo = Get-SystemInfoString
    Invoke-AdminCheckPrompt -SysInfo $sysInfo
    Invoke-BootAnimation

    $selected = 0
    $phase    = 0.0
    $frameMs  = [int](1000 / $script:Config.IdleFps)
    $boxW     = 36
    $boxX     = [int](($script:Config.Width - $boxW) / 2)
    $boxY     = 13

    Draw-MainMenu -SelectedIndex $selected -PrevIndex -1 -SysInfo $sysInfo

    while ($true) {
        # Animate idle banner gradient wave without blocking keyboard input
        Draw-Banner -Phase $phase
        $phase += 0.025
        if ($phase -gt 1.0) { $phase -= 1.0 }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            $prev = $selected

            switch ($key.Key) {
                ([ConsoleKey]::UpArrow) {
                    $selected = ($selected - 1 + $script:Config.MenuItems.Count) % $script:Config.MenuItems.Count
                    Draw-MainMenu -SelectedIndex $selected -PrevIndex $prev -SysInfo $sysInfo
                }
                ([ConsoleKey]::DownArrow) {
                    $selected = ($selected + 1) % $script:Config.MenuItems.Count
                    Draw-MainMenu -SelectedIndex $selected -PrevIndex $prev -SysInfo $sysInfo
                }
                ([ConsoleKey]::Escape) {
                    Invoke-FadeOutExit
                    return
                }
                ([ConsoleKey]::Enter) {
                    Invoke-MenuSelectFlash -SelectedIndex $selected -BoxX $boxX -BoxY $boxY -BoxW $boxW
                    $choice = $script:Config.MenuItems[$selected]

                    if ($choice -eq "EXIT") {
                        Invoke-FadeOutExit
                        return
                    }
                    elseif ($choice -eq "INSTALL") {
                        Invoke-ActionRunner -Mode "INSTALL"
                        Clear-Rect -X 0 -Y 12 -Width $script:Config.Width -Height ($script:Config.Height - 12)
                        Draw-MainMenu -SelectedIndex $selected -PrevIndex -1 -SysInfo $sysInfo
                    }
                    elseif ($choice -eq "UNINSTALL") {
                        if (Show-ConfirmUninstall) {
                            Invoke-ActionRunner -Mode "UNINSTALL"
                        }
                        Clear-Rect -X 0 -Y 12 -Width $script:Config.Width -Height ($script:Config.Height - 12)
                        Draw-MainMenu -SelectedIndex $selected -PrevIndex -1 -SysInfo $sysInfo
                    }
                }
            }
        }

        Start-Sleep -Milliseconds $frameMs
    }
}

#endregion

#region === ENTRYPOINT ===

try {
    Initialize-Console
    Start-InstallerUI
}
finally {
    Restore-Console
}

#endregion
