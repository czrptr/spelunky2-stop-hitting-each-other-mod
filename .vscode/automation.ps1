# -------- Imports --------
$signature = @"
using System;
using System.Runtime.InteropServices;

public static class Win32
{
  public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
  public const uint MOUSEEVENTF_LEFTUP   = 0x0004;
  public const int VK_RETURN = 0x0D;
  public const int VK_Z = 0x5A;
  public const int VK_K = 0x4B;
  public const uint KEYEVENTF_KEYDOWN = 0x0000;
  public const uint KEYEVENTF_KEYUP = 0x0002;

  [StructLayout(LayoutKind.Sequential)]
  public struct RECT
  {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
  }

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool SetCursorPos(int X, int Y);

  [DllImport("user32.dll")]
  public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

  [DllImport("user32.dll")]
  [return: MarshalAs(UnmanagedType.Bool)]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

  [DllImport("user32.dll")]
  public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

  [DllImport("user32.dll")]
  public static extern uint MapVirtualKey(uint uCode, uint uMapType);
}
"@

Add-Type -TypeDefinition $signature
Add-Type -AssemblyName System.Windows.Forms

# -------- Utilities --------

function Get-Process-Handle
{
  param
  (
    [string]$Name
  )
  $proc = Get-Process | Where-Object { $_.ProcessName -like "*$Name*" } | Select-Object -First 1
  if ($proc -eq $null)
  {
    Write-Error "Launch: No process found with name containing '$Name'."
    return $null
  }

  $handle = $proc.MainWindowHandle
  if ($handle -eq 0)
  {
    Write-Error "Launch: Process found, but window handle is 0."
    return $null
  }

  $rect = New-Object Win32+RECT
  $success = [Win32]::GetWindowRect($handle, [ref] $rect)
  if (-not $success)
  {
    Write-Error "Launch: Failed to get window rectangle via GetWindowRect."
    return $null
  }

  return $handle
}

function Wait-For-Process-Close
{
  param
  (
    [string]$Name,
    [int]$Timeout = 0, # 0 = no timeout, wait indefinitely (milliseconds)
    [int]$CheckInterval = 200  # How often to check (milliseconds)
  )

  # First check if process exists at all
  $initialProcesses = Get-Process | Where-Object { $_.ProcessName -like "*$Name*" }
  if ($initialProcesses.Count -eq 0)
  {
    return $true
  }

  $startTime = Get-Date

  while ($true)
  {
    # Check if any processes are still running
    $runningProcesses = Get-Process | Where-Object { $_.ProcessName -like "*$Name*" }

    if ($runningProcesses.Count -eq 0)
    {
      return $true
    }

    # Check timeout
    if ($Timeout -gt 0)
    {
      $elapsedTime = (Get-Date) - $startTime
      if ($elapsedTime.TotalSeconds -ge $Timeout)
      {
        return $false
      }
    }

    # Wait before next check
    Start-Sleep -Milliseconds $CheckInterval
  }
}

function Get-Window-Rect
{
  param
  (
    [IntPtr]$Handle
  )
  $rect = New-Object Win32+RECT
  $success = [Win32]::GetWindowRect($Handle, [ref] $rect)
  if (-not $success)
  {
    Write-Error "Launch: Failed to get window rectangle via GetWindowRect."
    return $null
  }

  return $rect
}

function Minimize-Window
{
  param
  (
    [IntPtr]$Handle
  )
  [Win32]::ShowWindowAsync($Handle, 6) | Out-Null
  Start-Sleep -Milliseconds 25
}

function Restere-Window
{
  param
  (
    [IntPtr]$Handle
  )
  [Win32]::ShowWindowAsync($Handle, 9) | Out-Null
  Start-Sleep -Milliseconds 25
}

function Focus-Window
{
  param
  (
    [IntPtr] $Handle
  )
  [Win32]::SetForegroundWindow($Handle) | Out-Null
}

Add-Type -TypeDefinition @"
public enum Anchor
{
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
    Center
}
"@

function Click-In-Window
{
  param
  (
    [IntPtr] $Handle,
    [Win32+RECT] $Rect,
    [int] $X,
    [int] $Y,
    [Anchor] $Anchor
  )
  Focus-Window -Handle $Handle

  switch ($Anchor)
  {
    "TopLeft" {
      $absX = $Rect.Left + $X
      $absY = $Rect.Top + $Y
    }
    "TopRight" {
      $absX = $Rect.Right - $X
      $absY = $Rect.Top + $Y
    }
    "BottomLeft" {
      $absX = $Rect.Left + $X
      $absY = $Rect.Bottom - $Y
    }
    "BottomRight" {
      $absX = $Rect.Right - $X
      $absY = $Rect.Bottom - $Y
    }
    "Center" {
      $centerX = $Rect.Left + ($windowWidth / 2)
      $centerY = $Rect.Top + ($windowHeight / 2)
      $absX = $centerX + $X
      $absY = $centerY + $Y
    }
  }

  [Win32]::SetCursorPos($absX, $absY) | Out-Null
  Start-Sleep -Milliseconds 25

  # Simulate mouse click
  [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 25
  [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 25
}

function Send-Key
{
  param
  (
    [IntPtr]$Handle,
    [int]$Key,
    [int]$Delay = 200
  )
  Start-Sleep -Milliseconds $Delay
  $scanCode = [Win32]::MapVirtualKey($Key, 0)
  [Win32]::keybd_event($Key, $scanCode, [Win32]::KEYEVENTF_KEYDOWN, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 25
  [Win32]::keybd_event($Key, $scanCode, [Win32]::KEYEVENTF_KEYUP, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 25
}

# -------- Logic --------

# Find Modlunky2
$handle = Get-Process-Handle -Name "modlunky2"
if ($handle -eq $null)
{
  Exit
}
Restere-Window -Handle $handle
# Click Play
$rect = Get-Window-Rect -Handle $handle
Click-In-Window -Handle $handle -Rect $rect -X 110 -Y 180 -Anchor BottomLeft
# Hide Modlunky2
Minimize-Window -Handle $handle

# Find Spelunky2
Start-Sleep -Milliseconds 1000
$handle = Get-Process-Handle -Name "Spel2"
if ($handle -eq $null)
{
  Exit
}

Start-Sleep -Milliseconds 5000
Focus-Window -Handle $handle
$rect = Get-Window-Rect -Handle $handle

# Skip to gameplay using Overlunky Skip intro script autoloading

# # > Game
# Click-In-Window -Handle $handle -Rect $rect -X 250 -Y 6 -Anchor TopLeft
# # > Players
# Click-In-Window -Handle $handle -Rect $rect -X 250 -Y 130 -Anchor TopLeft
# # > Number of players = 2
# Click-In-Window -Handle $handle -Rect $rect -X 620 -Y 150 -Anchor TopLeft
# # > Player 2
# Click-In-Window -Handle $handle -Rect $rect -X 620 -Y 290 -Anchor TopLeft
# # > Keyboard 2
# Click-In-Window -Handle $handle -Rect $rect -X 620 -Y 345 -Anchor TopLeft
# # Exit menu
# Click-In-Window -Handle $handle -Rect $rect -X 0 -Y 0 -Anchor Center

# Focus VSCode
$gameClosed = Wait-For-Process-Close -Name -Timeout 0 -CheckInterval 1000
if ($gameClosed)
{
  $handle = Get-Process-Handle -Name "Code"
  if ($handle -ne $null)
  {
    Focus-Window -Handle $handle
  }
}