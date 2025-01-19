<#
    .SYNOPSIS
        Monitor for kills and notify the player.

    .DESCRIPTION
        This script monitors a temp folder where Nvidia stores "Player Killed" and "Player Downed" clips.
        The creation of a temp clip indicates that the player died or killed another player in Hunt Showdown,
        but the game doesn't notify the player that they got a kill or that a clip was generated until after the match.
        Therefore, we can leverage clip creation to confirm a player's kills.

    .NOTES
        Future versions may ignore "Player Downed", but I haven't figured out how to differentiate them yet.

    .VERSION
        1.1.0

    .AUTHOR
        Apocrypher00
#>

function Wait-Exit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]
        $Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($Message) { Write-Warning -Message $Message }
    if ($ErrorRecord) { Write-Error -ErrorRecord $ErrorRecord }

    Read-Host -Prompt "Press Enter to Exit"
    try  { Stop-Transcript | Out-Null } catch {}
    exit
}

try {
    # Set the window title
    $host.UI.RawUI.WindowTitle = "Kill Popper"

    # Start the transcipt
    Write-Host "Starting transcript..."
    try {
        Start-Transcript -Path ".\logs\$((Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")).log" | Out-Null
    } catch {
        Wait-Exit "Failed to start transcript!"
    }

    # Check if the BurntToast module is installed
    if (-not (Get-InstalledModule -Name "BurntToast" -ErrorAction SilentlyContinue)) {
        Write-Host "BurntToast not installed. Installing..."
        try {
            Install-Module -Name "BurntToast" -Scope CurrentUser -Force
        } catch {
            Wait-Exit "Failed to install BurntToast!" $_
        }
    } else {
        Write-Host "BurntToast is already installed."
    }

    # Import the BurntToast module after confirming installation
    Write-Host "Importing BurntToast..."
    try {
        Import-Module "BurntToast"
    } catch {
        Wait-Exit "Failed to import BurntToast!" $_
    }

    # Username for current user
    $UserName = $Env:UserName
    Write-Host "User is '$Username'"

    # Temp Clip Path
    $ClipPath = "C:\Users\$UserName\AppData\Local\Temp\Highlights\Hunt  Showdown"
    Write-Host "Highlights temp folder is '$ClipPath'"

    # Check for Clip Path
    if (-not (Test-Path -Path $ClipPath)) {
        try {
            Write-Host "Temp folder missing. Creating now..."
            New-Item -Path $ClipPath -ItemType Directory -Force
        } catch {
            Wait-Exit "Failed to create temp folder!" $_
        }
    }

    # Define the path where the Hunt splash screen image is
    $SplashPath = "C:\Program Files (x86)\Steam\steamapps\common\Hunt Showdown\EasyAntiCheat\SplashScreen.png"
    Write-Host "Splash screen is at '$SplashPath'"

    # Check for splash screen
    if (-not (Test-Path -Path $SplashPath)) {
        Write-Warning "Splash screen not found! Switching to Default..."
        $SplashPath = $null
    }

    # Function to display a notification
    function Show-KillNotification {
        New-BurntToastNotification -AppLogo $SplashPath -Text @("Hunt: Showdown 1896", "Kill Confirmed!")
    }

    # Event Handler: Action when a new clip is created
    $ClipAction = {
        $ClipEvent = $Event.SourceEventArgs
        $FileName = $ClipEvent.Name
        Write-Host "New clip created: $FileName"
        Show-KillNotification
    }

    # Create filesystem watcher for MP4 files
    Write-Host "Creating Watcher..."
    try {
        $Watcher = [System.IO.FileSystemWatcher]::new($ClipPath, "*.mp4")
        $Watcher.EnableRaisingEvents = $true
    } catch {
        Wait-Exit "Failed to created Watcher!" $_
    }

    # Monitor the folder for new video files
    Write-Host "Starting Watcher..."
    try {
        Register-ObjectEvent -InputObject $Watcher -EventName "Created" -Action $ClipAction | Out-Null
    } catch {
        Wait-Exit "The Watcher is dead!" $_
    }

    # Keep the script running to continuously monitor
    Write-Host "The Watcher is watching..."
    while ($true) { Start-Sleep 1 }

} catch {
    Wait-Exit "Unknown Error!" $_
}
