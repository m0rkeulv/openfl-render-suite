# Runs an AIR application under adl and saves what its window really shows (the stage's rectangle of
# the client area, through PrintWindow with PW_RENDERFULLCONTENT), then stops adl. The app itself keeps running long enough to
# be captured (the kits' Main waits 4 s after its own draw() capture before exiting). AIR renders the
# stage 1:1 in the top-left of the client area, whatever the DPI scale of the window.
#
#   powershell -File capture_air_window.ps1 -Adl <adl.exe> -AppDir <Export/air> -Out <png> [-Wait 2500]
param(
  [string]$Adl,
  [string]$AppDir,
  [string]$Out,
  [int]$Wait = 2500
)
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class W {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  public struct RECT { public int left, top, right, bottom; }
  public struct POINT { public int x, y; }
  public static List<uint[]> Visible() {
    var res = new List<uint[]>();
    EnumWindows((h,l) => {
      if (IsWindowVisible(h)) {
        uint pid; GetWindowThreadProcessId(h, out pid);
        RECT r; GetClientRect(h, out r);
        int cw = r.right-r.left, ch = r.bottom-r.top;
        if (cw > 100 && ch > 100) res.Add(new uint[]{ (uint)h.ToInt64(), pid, (uint)cw, (uint)ch });
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
}
"@
[W]::SetProcessDPIAware() | Out-Null
Add-Type -AssemblyName System.Drawing

$p = Start-Process -FilePath $Adl -ArgumentList @("application.xml", "bin") -WorkingDirectory $AppDir -PassThru
try {
  $h = [IntPtr]::Zero
  for ($i = 0; $i -lt 80; $i++) {
    Start-Sleep -Milliseconds 150
    foreach ($w in [W]::Visible()) {
      if ([int]$w[1] -eq $p.Id) { $h = [IntPtr][int64]$w[0]; break }
    }
    if ($h -ne [IntPtr]::Zero) { break }
  }
  if ($h -eq [IntPtr]::Zero) { Write-Output "no adl window found"; return }
  [W]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, 0, 0, 0x0001 -bor 0x0004 -bor 0x0010) | Out-Null
  Start-Sleep -Milliseconds $Wait
  $wr = New-Object W+RECT; [W]::GetWindowRect($h, [ref]$wr) | Out-Null
  $winW = $wr.right - $wr.left; $winH = $wr.bottom - $wr.top
  $full = New-Object System.Drawing.Bitmap $winW, $winH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($full)
  $hdc = $g.GetHdc()
  $ok = [W]::PrintWindow($h, $hdc, 2)
  $g.ReleaseHdc($hdc); $g.Dispose()
  # keep the stage: the client area's origin relative to the window, then the stage's size from the
  # descriptor (the window is DPI-scaled, the stage is not), or the whole client area without one
  $cr = New-Object W+RECT; [W]::GetClientRect($h, [ref]$cr) | Out-Null
  $origin = New-Object W+POINT; [W]::ClientToScreen($h, [ref]$origin) | Out-Null
  $cx = $origin.x - $wr.left; $cy = $origin.y - $wr.top
  $cw = $cr.right - $cr.left; $ch = $cr.bottom - $cr.top
  $descriptor = Join-Path $AppDir "application.xml"
  if (Test-Path $descriptor) {
    $xml = Get-Content $descriptor -Raw
    if ($xml -match "<width>(\d+)</width>") { $cw = [Math]::Min($cw, [int]$Matches[1]) }
    if ($xml -match "<height>(\d+)</height>") { $ch = [Math]::Min($ch, [int]$Matches[1]) }
  }
  $client = $full.Clone((New-Object System.Drawing.Rectangle $cx, $cy, $cw, $ch), $full.PixelFormat)
  $client.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $client.Dispose(); $full.Dispose()
  Write-Output ("window " + $winW + "x" + $winH + " stage " + $cw + "x" + $ch + " at " + $cx + "," + $cy + " PrintWindow=" + $ok + " saved " + $Out)
} finally {
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
}
