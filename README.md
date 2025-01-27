# KillPopper

A PowerShell script that shows a Windows notification when you get a kill in Hunt: Showdown 1896

## Description

KillPopper is a PowerShell script that takes advantage of the NVIDIA highlights to let you know when you get a kill in Hunt Showdown.  
Normally highlights aren't available until after the game, but they are still created as the kill (or down) happens.  
This means that we can monitor the folder that the clips are generated in and show a notification in real-time.  
This allows you to confirm every kill, even if you miss the sound cues or it happens very far away.  
This is especially helpful when other players die to your traps on the other side of the map, although the highlight itself won't show the kill.

## Requirements

GeForce Experience (for v1.1+), or NVIDIA App (for v1.2+)  
PowerShell 5+ (PowerShell 5 is pre-installed on Windows)  
NuGet PowerShell Package Provider (should be installed the first time the script runs)  
BurntToast PowerShell Module (should be installed the first time the script runs)

## Getting Started

Download the latest release and unzip the files to a new folder, then just double click the shortcut with the green arrow before playing.  
The script will run in the background and monitor for new clips.  
The script will tell you if any errors occurr by displaying them in the console and by logging everything to the logs folder.
  
Make sure that notifications are enabled and you don't have "Do Not Disturb" turned on while in-game.  
If you have GeForce Experience, KillPopper can't distinguish between kill clips and down clips, so you will have to disable "Player downed" highlights if you don't want notifications to appear when you die.
