# =============================================================================================
# DELETES FILES WHOSE LAST MODIFIED DATE IS MORE THAN SPECIFIED NO. OF DAYS OLD
# =============================================================================================
#
# =============================================================================================
# PowerShell script written by ChatGPT with instructions from Lin Yangchen
# Refined by Lin Yangchen
# Light Microscopy Core, Centre for Bioimaging Sciences, National University of Singapore
# 11 September 2026, last updated 8 October 2026
# =============================================================================================
#
#
#
# Protected files regardless of age:
#   - Filename contains "template" or "delete"
#     (case-insensitive, anywhere in the name)
#   - File in a subfolder whose name contains "template" or "delete"
#     even if the filename itself does not contain those words
#
#
#
#
# =============================================================================================
# INSTRUCTIONS
# =============================================================================================
#
#
#
# BEFORE RUNNING THIS SCRIPT
#
# The latest version of the script can be downloaded from
# https://github.com/linyangchen/core-facility-automation/blob/main/powershell_autodelete.ps1
#
# Copy the script onto the computer where you want to use it,
# into any folder of your choice.
#
# To enable powershell script execution on the computer,
# type powershell in the Windows search bar and click Run as Administrator.
# A terminal window will appear.
# Type Set-ExecutionPolicy RemoteSigned and press enter. Answer yes to all.
#
# Under the USER SETTINGS section below:
# specify folder in which to check and delete files (enclose in double quotes)
# Set $DaysOld to the number of days older than which the file will be deleted.
# For testing the script without deleting any files, set $DryRun to $true below.
# To actually delete files, set $DryRun to $false.
#
#
#
#
# TO RUN THE SCRIPT MANUALLY
#
# open a powershell window.
# change directory to where the script is
# and type .\ followed by the filename of the script with no space.
# if it returns error saying script is digitally unsigned,
# right click on the script file icon, select Properties and tick Unblock.
#
#
# TO RUN THE SCRIPT AUTOMATICALLY AT REGULAR INTERVALS
#
# log in as an admin and open task scheduler.
# click create task on the right.
# in the actions tab, click new and select start a program
# type powershell.exe in the program field.
# type -ExecutionPolicy Bypass -File "C:\Path\To\YourScript.ps1" in arguments
# in the triggers tab, set the time interval for automatic execution.
# in the general tab, set it to run with highest privileges
# and whether user is logged on or not
# click ok.
#
#
#
# =============================================================================================
# USER SETTINGS
# =============================================================================================

# Specify full path to directory in which to check and delete files.
# to get full path, navigate to the folder in File Explorer,
# right click on the folder name in address bar and copy.

$FolderPath = 


# specify threshold file age (files with mod date older than this will be deleted)

$DaysOld = 15


$DryRun = $true



# ============================================================
# FOLDER SPECIFICATION
# ============================================================


# Alternative interactive user input
#$FolderPath = Read-Host "Enter the full path of the folder to clean"

# Remove accidental quotation marks if a quoted path was pasted
#$FolderPath = $FolderPath.Trim().Trim('"')


if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
    Write-Host ""
    Write-Host "ERROR: Folder does not exist:" -ForegroundColor Red
    Write-Host $FolderPath -ForegroundColor Red
    exit 1
}

# Convert the selected folder to a DirectoryInfo object
$RootFolder = Get-Item -LiteralPath $FolderPath -ErrorAction Stop

# ============================================================
# SETUP
# ============================================================

$CutoffDate = (Get-Date).AddDays(-$DaysOld)

Write-Host ""
Write-Host "========================================"
Write-Host "Old File Cleanup"
Write-Host "========================================"
Write-Host "Root folder : $($RootFolder.FullName)"
Write-Host "Modified before: $CutoffDate"
Write-Host 'Protected   : names containing "template" or "delete"'
Write-Host "Dry run     : $DryRun"
Write-Host "========================================"
Write-Host ""

if (-not $DryRun) {
    Write-Host "WARNING: Files will actually be deleted." -ForegroundColor Red
    Write-Host ""
}

$FilesChecked = 0
$FilesDeleted = 0
$FilesSkipped = 0
$FilesFailed = 0

# ============================================================
# GET FILES ONLY
# ============================================================

$Files = Get-ChildItem `
    -LiteralPath $RootFolder.FullName `
    -File `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue

# ============================================================
# PROCESS EACH FILE
# ============================================================

foreach ($File in $Files) {

    $FilesChecked++

    # --------------------------------------------------------
    # CHECK FILE NAME
    # --------------------------------------------------------

    if ($File.Name -match '(?i)template|delete') {

        Write-Host "SKIP - protected filename:" -ForegroundColor Yellow
        Write-Host "      $($File.FullName)" -ForegroundColor Yellow

        $FilesSkipped++
        continue
    }

    # --------------------------------------------------------
    # CHECK PARENT FOLDERS
    # --------------------------------------------------------

    $ExcludedFolder = $null
    $CurrentFolder = $File.Directory

    while ($null -ne $CurrentFolder) {

        # Stop when we reach the folder selected by the user
        if ($CurrentFolder.FullName -eq $RootFolder.FullName) {
            break
        }

        # Check only the actual folder name
        if ($CurrentFolder.Name -match '(?i)template|delete') {

            $ExcludedFolder = $CurrentFolder
            break
        }

        $CurrentFolder = $CurrentFolder.Parent
    }

    # --------------------------------------------------------
    # FILE IS INSIDE A PROTECTED FOLDER
    # --------------------------------------------------------

    if ($null -ne $ExcludedFolder) {

        Write-Host "SKIP - protected folder:" -ForegroundColor Yellow
        Write-Host "      File:   $($File.FullName)" -ForegroundColor Yellow
        Write-Host "      Folder: $($ExcludedFolder.FullName)" -ForegroundColor Yellow

        $FilesSkipped++
        continue
    }

    # --------------------------------------------------------
    # CHECK LAST MODIFIED DATE
    #
    # Creation date is deliberately NOT checked.
    # --------------------------------------------------------

    if ($File.LastWriteTime -ge $CutoffDate) {

        Write-Host "KEEP - modified within $DaysOld days:" `
            -ForegroundColor DarkGray

        Write-Host "      $($File.FullName)" `
            -ForegroundColor DarkGray

        continue
    }

    # --------------------------------------------------------
    # FILE IS ELIGIBLE FOR DELETION
    # --------------------------------------------------------

    if ($DryRun) {

        Write-Host "WOULD DELETE:" -ForegroundColor Cyan
        Write-Host "      $($File.FullName)" -ForegroundColor Cyan
        Write-Host "      Modified: $($File.LastWriteTime)" -ForegroundColor Cyan
    }
    else {

        try {

            Remove-Item `
                -LiteralPath $File.FullName `
                -Force `
                -ErrorAction Stop

            Write-Host "DELETED:" -ForegroundColor Green
            Write-Host "      $($File.FullName)" -ForegroundColor Green

            $FilesDeleted++
        }
        catch {

            Write-Host "FAILED TO DELETE:" -ForegroundColor Red
            Write-Host "      $($File.FullName)" -ForegroundColor Red
            Write-Host "      $($_.Exception.Message)" -ForegroundColor Red

            $FilesFailed++
        }
    }
}





# ============================================================
# DELETE EMPTY FOLDERS
#
# Folders are processed deepest-first so a parent folder
# can become empty after its child folder is removed.
#
# The specified root folder itself is NEVER deleted.
# Protected folders containing "template" or "delete" are
# also never deleted.
# ============================================================

Write-Host ""
Write-Host "Checking for empty folders..." -ForegroundColor Cyan

$Folders = Get-ChildItem `
    -LiteralPath $RootFolder.FullName `
    -Directory `
    -Recurse `
    -Force `
    -ErrorAction SilentlyContinue |
    Sort-Object { $_.FullName.Length } -Descending

$FoldersDeleted = 0
$FoldersSkipped = 0

foreach ($Folder in $Folders) {

    # --------------------------------------------------------
    # Never delete a folder whose name contains "template"
    # or "delete".
    # --------------------------------------------------------

    if ($Folder.Name -match '(?i)template|delete') {

        Write-Host "SKIP FOLDER (protected name): $($Folder.FullName)" `
            -ForegroundColor Yellow

        $FoldersSkipped++
        continue
    }

    # --------------------------------------------------------
    # Check whether the folder is empty.
    # --------------------------------------------------------

    $Contents = Get-ChildItem `
        -LiteralPath $Folder.FullName `
        -Force `
        -ErrorAction SilentlyContinue

    if ($null -eq $Contents) {

        if ($DryRun) {

            Write-Host "WOULD DELETE EMPTY FOLDER: $($Folder.FullName)" `
                -ForegroundColor Cyan
        }
        else {

            try {

                Remove-Item `
                    -LiteralPath $Folder.FullName `
                    -Force `
                    -ErrorAction Stop

                Write-Host "DELETED EMPTY FOLDER: $($Folder.FullName)" `
                    -ForegroundColor Green

                $FoldersDeleted++
            }
            catch {

                Write-Host "FAILED TO DELETE FOLDER: $($Folder.FullName)" `
                    -ForegroundColor Red

                Write-Host "    $($_.Exception.Message)" `
                    -ForegroundColor Red
            }
        }
    }
}





# ============================================================
# SUMMARY
# ============================================================

Write-Host ""
Write-Host "========================================"
Write-Host "Finished"
Write-Host "========================================"
Write-Host "Files checked : $FilesChecked"
Write-Host "Files skipped : $FilesSkipped"

if ($DryRun) {

    Write-Host ""
    Write-Host "DRY RUN - NO FILES WERE DELETED." `
        -ForegroundColor Yellow

    Write-Host ""
    Write-Host 'Change $DryRun = $true to $DryRun = $false'
    Write-Host "when you are ready to enable deletion."
}
else {

    Write-Host "Files deleted : $FilesDeleted"
    Write-Host "Files failed  : $FilesFailed"
}

