<#
    .SYNOPSIS
        Monitor for kills and notify the player.

    .DESCRIPTION
        This script monitors a folder where Nvidia stores "Hunter killed" and "Player downed" clips.
        The creation of a clip indicates that the player died or killed another player in Hunt Showdown,
        but the game doesn't notify the player that they got a kill or that a clip was generated until after the match.
        Therefore, we can leverage clip creation to confirm a player's kills.

    .VERSION
        1.2.2

    .AUTHOR
        Apocrypher00
#>

#### --- Imports --- ###################################################################################################

using namespace System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms

#### --- End Imports --- ###############################################################################################

#### --- Globals --- ###################################################################################################

# Current version of the script
$CurrentVersion = "1.2.2"

# Username for current user
$UserName = $Env:UserName

# Path to user folder
$UserPath = "C:\Users\$UserName"

# Nvidia app path
$AppPath = "C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA app.exe"

# Temp Clip Path
$ClipPath = "$UserPath\AppData\Local\Temp\Highlights\Hunt  Showdown"

# Gallery Path
$GalleryPath = "$UserPath\Videos\Hunt  Showdown"

# Hunt splash screen path
$SplashPath = "C:\Program Files (x86)\Steam\steamapps\common\Hunt Showdown\EasyAntiCheat\SplashScreen.png"

# Version file URL
$RepoURL        = "https://raw.githubusercontent.com/Apocrypher00/KillPopper/master"
$VersionFileURL = "$RepoURL/version.txt"

#### --- End Globals --- ###############################################################################################

#### --- Functions --- #################################################################################################

# Function to display a message box
function Show-MessageBox {
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [string]
        $Message = "",

        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $Title = "",
        
        [Parameter(Mandatory = $false, Position = 2)]
        [MessageBoxButtons]
        $Button = [MessageBoxButtons]::OK,
        
        [Parameter(Mandatory = $false, Position = 3)]
        [MessageBoxIcon]
        $Icon = [MessageBoxIcon]::Information
    )

    return [MessageBox]::Show($Message, $Title, $Button, $Icon)
}

# Function to wait for user input before exiting
function Wait-Exit {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    if ($Message) { Write-Warning -Message $Message }
    if ($ErrorRecord) { Write-Error -ErrorRecord $ErrorRecord }

    Show-MessageBox -Message $Message -Title "KillPopper" -Button OK -Icon Error | Out-Null
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    exit 1
}

# Function to display a notification
function Show-KillNotification {
    New-BurntToastNotification -AppLogo $SplashPath -Text @("Hunt: Showdown 1896", "Kill Confirmed!")
}

#### --- End Functions --- #############################################################################################

#### --- Main Script --- ###############################################################################################

try {
    # Set the window title
    $host.UI.RawUI.WindowTitle = "KillPopper"

    # Start the transcipt
    Write-Host "Starting transcript..."
    try {
        if (-not (Test-Path -Path ".\logs")) {
            Write-Warning "Logs folder missing. Creating now..."
            New-Item -Path ".\logs" -ItemType Directory -Force
        }

        Start-Transcript -Path ".\logs\$((Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")).log" | Out-Null
    } catch {
        Wait-Exit "Failed to start transcript!" $_
    }

    # Display the script information
    Write-Host "Script version is:         '$CurrentVersion'"
    Write-Host "User is:                   '$Username'"
    Write-Host "User folder is:            '$UserPath'"
    Write-Host "Highlights temp folder is: '$ClipPath'"
    Write-Host "Gallery folder is:         '$GalleryPath'"
    Write-Host "Nvidia app is at:          '$AppPath'"
    Write-Host "Splash screen is at:       '$SplashPath'"

    # Check for updates
    try {
        $LatestVersion = Invoke-WebRequest -Uri $VersionFileURL -UseBasicParsing | Select-Object -ExpandProperty Content
        $LatestVersion = $LatestVersion.Trim()

        if ($LatestVersion -gt $CurrentVersion) {
            Write-Host "New version available: $LatestVersion!" -ForegroundColor Green
            Show-MessageBox `
                -Message "New version available: $LatestVersion!" `
                -Title "KillPopper" `
                -Button OK `
                -Icon Information | Out-Null
        } else {
            Write-Host "Script is up to date!" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to check for updates!"
    }

    # Check if NuGet is installed
    if (-not (Get-PackageProvider -Name "NuGet" -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Warning "NuGet not installed. Installing..."
        try {
            Install-PackageProvider -Name "NuGet" -Scope CurrentUser -Force
        } catch {
            Wait-Exit "Failed to install NuGet!" $_
        }
    } else {
        Write-Host "NuGet is already installed."
    }

    # Check if the BurntToast module is installed
    if (-not (Get-InstalledModule -Name "BurntToast" -ErrorAction SilentlyContinue)) {
        Write-Warning "BurntToast not installed. Installing..."
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

    # Check for splash screen
    if (-not (Test-Path -Path $SplashPath)) {
        Write-Warning "Splash screen not found! Switching to Default..."
        $SplashPath = $null
    }

    # Check if the NVIDIA App is installed
    # If so, we need to monitor the gallery instead of the temp folder
    if (Test-Path -Path $AppPath) {
        Write-Host "NVIDIA App found. Monitoring Gallery instead of Temp folder."
        $ClipPath = $GalleryPath 
    }

    # Check for Clip Path
    if (-not (Test-Path -Path $ClipPath)) {
        try {
            Write-Host "Temp folder missing. Creating now..."
            New-Item -Path $ClipPath -ItemType Directory -Force
        } catch {
            Wait-Exit "Failed to create temp folder!" $_
        }
    }

    # Event Handler: Action when a new clip is created
    $ClipAction = {
        $ClipEvent = $Event.SourceEventArgs
        $FileName  = $ClipEvent.Name

        # Ignore "Player downed" clips
        if ($FileName -like "*Player downed*") { return }
        
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

#### --- End Main Script --- ###########################################################################################
