Clear-Host
# ==================== EDIT THESE VARIABLES ====================
$path= "E:\+Ready to Embed - Movie Shelf - Dual Audio"
#$path = $basePath + "\Livros\Brandon Sanderson\PDF"
$ans= ""
$oldString="HC3S "
$newString=""
$prefix = ""           #Prefix to Add
$NumCharRemove = 1     ## Menu Item #3
$folderFileListExport = 'E:\+Ready to Embed - Movie Shelf - Dual Audio'                 ##Menu Item #14
# ==============================================================
<#
_OceanofPDF.com_
_-_adastra339
_-_c_mantis

#>

# ================ DON'T TOUCH THESE VARIABLES =================
$basePath = $PSScriptRoot
# ==============================================================


if (-not (Test-Path $path)) { Write-Host "Path does not exist: $path" -ForegroundColor Black -BackgroundColor Red; exit }
Set-Location -Path $path

function Export-FolderToCsv {
    param(
        [string]$FolderPath,
        [string]$CsvPath = "$FolderPath\!filelist.csv",
        [string[]]$Extensions = @("*.mp4", "*.jpg", "*.png", "*.webp","*.*")
    )
    $files = @()

    if (-not (Test-Path $FolderPath)) {  Write-Host "Error: Folder not found → $FolderPath" -ForegroundColor Red; return     }
    foreach ($ext in $Extensions) { $files += Get-ChildItem -Path $FolderPath -Filter $ext -File -Recurse | Select-Object FullName }
    if ($files.Count -eq 0) { Write-Host "No matching files found in $FolderPath" -ForegroundColor Yellow; return }

    try {
        $files | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "Exported $($files.Count) files to $CsvPath" -ForegroundColor Green
    }
    catch { Write-Host "Error exporting to CSV: $_" -ForegroundColor Red }
}

# ================== SWITCH MENU ==================
switch(14)
{
#######========================================================================================================================================================
0 { # Menu

Write-Host "Menu: 
---------------
 1) Rename Files - REPLACE oldString
 2) Add Prefix
 3) Remove X number of character at start of each file
 4) Remove brackets
 5) Remove paranthesis
 6) Export List of File?? (**In Progress)
 7) Move Files Out of Subfolders
 8) Delete empty folders??
 9) Export size of subfolders in a folder
 10) Replace .. or .- with .
 11) Subs: Clean naming of SRT files and folders (@params)
 12) Subs: Rename Subs in Folders to Filename, then move them up a couple Directory levels 
 13) Subs: Change '.' to ' ', and remove 'English'
 14) Export file list to CSV
 "

#It is doing SOMETHING weird with the X-Men subtitle.... Moving it up to main directory for some reason...

#Rename "subs.srt" and ".srt" with name of folder directory


write-host "`n"
write-host "`n"

#######========================================================================================================================================================
} 99 { ## Test Space


#Get-ChildItem -Path source -Recurse -File | Move-Item -Destination dest

#Get-ChildItem *.* -Recurse | Move-Item -Destination $path

write-host $path

#######========================================================================================================================================================
} 1 {  ##-- Rename Files - remove oldString

    write-host '----BEFORE Rename----'

    Get-ChildItem -Name

    ###-- Replace a string of characters
    (Get-ChildItem -File) | Rename-Item -NewName { $_.Name -replace $oldString, $newString }


    write-host '----AFTER Rename----'
    Get-ChildItem -Name

#######========================================================================================================================================================
} 2 {  ###-- Add Prefix

    (Get-ChildItem -File) | Rename-Item -NewName { $prefix + $_.Name}
    

#######========================================================================================================================================================
} 3 {  ##-- Remove X number of character at start of each file

    (Get-ChildItem -File) | Rename-Item -NewName { $_.Name.Substring($NumCharRemove) }

#######========================================================================================================================================================
} 4 {  ##-- Remove brackets

    (Get-ChildItem -File) | Rename-Item -NewName { $_.Name -replace '\[','' }
    
    (Get-ChildItem -File) | Rename-Item -NewName { $_.Name -replace '\]','' }

    write-host '----AFTER----'
    Get-ChildItem -Name


#######========================================================================================================================================================
} 5 {  ##-- Remove paranthesis

    (Get-ChildItem -File) | Rename-Item -NewName { $_.Name -replace '\(','' }
    
    (Get-ChildItem -File) | Rename-Item -NewName { $_.Name -replace '\)','' }

    write-host '----AFTER----'
    Get-ChildItem -Name


#######========================================================================================================================================================
} 6 {  ##-- Export List of Files ?????

    $fileExport = $path + "\files.txt"
    $path | ft Name -HideTableHeaders | Out-File -FilePath $fileExport


    # Define the path to the folder containing MP4 files
    $FolderPath = $path

    # Define the path for the output CSV file
    $OutputCsvPath = $fileExport

# Get all .mp4 files in the specified folder and its subfolders
# Select desired properties for export (e.g., Name, DirectoryName, Length, CreationTime, LastWriteTime)
# Pipe the results to Export-Csv
Get-ChildItem -Path $FolderPath -Recurse -Include "*.mp4" | 
    Select-Object Name, DirectoryName, Length, CreationTime, LastWriteTime | 
    Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8


#######========================================================================================================================================================
} 7 {  ##-- Move Files Out of Subfolders

$ans = Read-Host "Are you sure you want to move all files out of sub-directories? (y/n)"

if ($ans = "y") {
    Get-ChildItem *.* -Recurse | Move-Item -Destination $path
}


#######========================================================================================================================================================
} 8 {  ##-- Delete empty subfolders

Get-ChildItem -Path source -Recurse -Directory | Remove-Item



#######========================================================================================================================================================
} 9 {  ##-- Export size of subfolders in a folder
        # export to a csv file. Call it FolderSize.csv. Export it to the same folder of the powershell script


# Set the target folder path
$TargetPath = $path

# Get the script's directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CsvPath = Join-Path $ScriptDir ".FolderSize.csv"

# Collect folder sizes and export to CSV
Get-ChildItem $TargetPath -Directory | ForEach-Object {
    $size = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    [PSCustomObject]@{
        Folder = $_.FullName
        SizeMB = [Math]::Round($size / 1MB, 2)
    }
} | Sort-Object SizeMB -Descending | Export-Csv -Path $CsvPath -NoTypeInformation

Write-Host "Folder sizes exported to: $CsvPath"


#######========================================================================================================================================================
} 10 {  ##-- Subtitles: Clean naming of SRT files and folders


$items = Get-ChildItem -Path $path -Recurse -Force | Sort-Object { $_.FullName.Length } -Descending

foreach ($item in $items) {
    $name = $item.Name

    # Trim spaces at start and end
    $newName = $newName.Trim()

    # Replace .. and .- with .
    #$newName = $name -replace "\.\.", "." -replace "\.-", "." -replace "\. ", "." -replace "\._", "." -replace "\.+", "."
    $newName = $name -replace "\.(?:\.|-| |_|\+)+", "."
    $newName = $newName -replace '[\s\u00A0]+(?=\.[^.]+$)', ''



    # Remove Brackets, Leading & Trailing dash, and empty paranthesis
    $newName = $newName -replace "\[", "" -replace "\]", ""
    $newName = $newName -replace "\(\)", ""
    $newName = $newName -replace "^-", "" -replace "-$", ""      # Leading & Trailing dash

    $newName = $newName -replace "  ", " "      # Fix double spaces
 

    # Trim spaces at start and end
    $newName = $newName.Trim()

    if ($newName -ne $name) {
        $parent = Split-Path -Path $item.FullName -Parent
        $target = Join-Path -Path $parent -ChildPath $newName

        $i = 1
        $candidateName = $newName
        while (Test-Path -LiteralPath $target) {
            $base = [IO.Path]::GetFileNameWithoutExtension($newName)
            $ext = [IO.Path]::GetExtension($newName)
            $candidateName = "{0} ({1}){2}" -f $base, $i, $ext
            $target = Join-Path -Path $parent -ChildPath $candidateName
            $i++
        }

        Rename-Item -LiteralPath $item.FullName -NewName (Split-Path $target -Leaf)
        Write-Host "Renamed: $name -> $candidateName"
    }
}


#######======================================
} 11 {  ##-- Clean naming of SRT files and folders

#$targetPath = $path

# Define patterns (case-insensitive), deduped and sorted by length (shortest first)
$patterns = @(
    "WebRip","H264","x264","x265","720p","816p","1040p","1080p","IMAX","HDTV","HDCAM","HDTC","SDH","XViD","mp4","Brip","BrRip","HDRip","Bluray","DvDrip","DolbyD",
    "YIFY","DCOM","Disney","Extended","REMASTERED","Subtitles","Subs","850MB","1400MB","1.29gb",

    "NVEE_","Nickarad","AAC51","-2447","bitloks","BOKUTOX","REPACK","[YTSMX]","[YTS.MX]","AC3-ETRG","AC3-EVO",
    "avitaeng","-WOLVERDONFILMESCOM","A Release-Lounge","5\.1 \+","RARBG","-DEFiNiTE","-AMIABLE","AAC-",
    "AAC5.1","WEB-DL","[y2flix.cc]",".\avita\.eng","aviRCrew","\.avita.","MIRCrew","anoXmous","avip","[-]",
    "DTS -MgB","ETRG","\+","DD5\.1","GalaxyRG","5.1","VPPV","Toxic3","B4ND1T69","c1nem4","DTS"

    ,"Solar","Sparks","avish",".Internal.","Deceit","First Try",".GAZ","LOL","SUNSCREEN","Diamond"
    ,"YTS.MX","YTS.AG","fasamoo","LKRG","REMUX.AVC.DTS-HD.MA.FGT-.to",".YTS.",".p82",".AVC.",".AAC",".avita."


) | Select-Object -Unique
#) | Sort-Object { $_.Length } | Select-Object -Unique


# "\.\.","\(\)","\[\]","\.AG\.","Solar","\.AAC5\.1","\.5\.1","\.Dual","\.GAZ","LOL",


###############################################################


# Get all items recursively
$items = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue

# --- Rename files ---
$files = $items | Where-Object { -not $_.PSIsContainer }
foreach ($f in $files) {
    $parent = Split-Path -Path $f.FullName -Parent
    if ([string]::IsNullOrEmpty($parent)) { continue }

    $name = $f.Name

    # Inline pattern removal, case-insensitive
    foreach ($pattern in $patterns) {
        $name = [regex]::Replace($name, [regex]::Escape($pattern), '', 'IgnoreCase')
    }

    # Skip if no change
    if ($name -ieq $f.Name) { continue }

    $target = Join-Path -Path $parent -ChildPath $name
    $i = 1
    $candidateName = $name

    # Avoid overwriting existing files
    while (Test-Path -LiteralPath $target) {
        $nameOnly = [IO.Path]::GetFileNameWithoutExtension($name)
        $ext = [IO.Path]::GetExtension($name)
        $candidateName = "{0} ({1}){2}" -f $nameOnly, $i, $ext
        $target = Join-Path -Path $parent -ChildPath $candidateName
        $i++
    }

    Rename-Item -LiteralPath $f.FullName -NewName (Split-Path $target -Leaf)
    Write-Host "Renamed file: $($f.FullName) -> $candidateName"
}

# --- Rename directories bottom-up ---
$dirs = $items | Where-Object { $_.PSIsContainer } | Sort-Object { $_.FullName.Length } -Descending
foreach ($d in $dirs) {
    $parent = Split-Path -Path $d.FullName -Parent
    if ([string]::IsNullOrEmpty($parent)) { continue }

    $name = $d.Name

    # Inline pattern removal, case-insensitive
    foreach ($pattern in $patterns) {
        $name = [regex]::Replace($name, [regex]::Escape($pattern), '', 'IgnoreCase')
    }

    # Skip if no change or empty
    if ([string]::IsNullOrEmpty($name) -or $name -ieq $d.Name) { continue }

    $target = Join-Path -Path $parent -ChildPath $name
    $i = 1
    $candidateName = $name

    # Avoid overwriting existing dirs
    while (Test-Path -LiteralPath $target) {
        $candidateName = "{0} ({1})" -f $name, $i
        $target = Join-Path -Path $parent -ChildPath $candidateName
        $i++
    }

    Rename-Item -LiteralPath $d.FullName -NewName (Split-Path $target -Leaf)
    Write-Host "Renamed dir: $($d.FullName) -> $candidateName"
}


#######======================================
} 12 {  ##-- Clean naming of SRT files and folders, and move them up a directory level
				#Rename Subs in Folders to Filename, then move them up to a couple Directory levels



# Step 1: Move SRT files from any subfolder called "Subs" up one level
Get-ChildItem -Path $path -Recurse -Directory -Filter "Subs" |
    ForEach-Object {
        $parentFolder = $_.Parent.FullName
        Get-ChildItem -Path $_.FullName -File |
            ForEach-Object {
                Move-Item -Path $_.FullName -Destination (Join-Path $parentFolder $_.Name) -Force
            }
    }

# Step 2: Prefix folder name to SRT files starting with English or <number>_English
Get-ChildItem -Path $path -Recurse -File -Filter "*.srt" |    
    Where-Object {
        $_.BaseName -match '^(English|\d+_English)' -or
        $_.BaseName -match '^(English|_english)' -or
        $_.BaseName -match '^(English|\d+_Eng)$' -or
        $_.BaseName -match '^(English|_eng)$' -or
        $_.BaseName -match '^(English|_eng.hi)$' -or
        $_.BaseName -ieq 'subs' -or
        [string]::IsNullOrWhiteSpace($_.BaseName)
    } |
    ForEach-Object {
        $folderName = $_.Directory.Name
        $newName = $folderName + "_" + $_.Name
        Rename-Item -Path $_.FullName -NewName $newName -Force
    }

# Step 3: Move matching SRTs up one folder if filename matches current folder name before "_"
Get-ChildItem -Path $path -Recurse -File -Filter "*.srt" |
    ForEach-Object {
        $folderName = $_.Directory.Name
        $filePrefix = $_.BaseName.Split('_')[0]  # Take part before first "_"
        if ($filePrefix -eq $folderName) {
            $targetFolder = $_.Directory.Parent.FullName
            $targetPath = Join-Path $targetFolder $_.Name
            Move-Item -Path $_.FullName -Destination $targetPath -Force
        }
    }



#######======================================
} 14 {  ##-- Clean naming of SRT files and folders, and move them up a directory level

    # Export all matching files in folder to default "filelist.csv"
    Export-FolderToCsv -FolderPath $folderFileListExport

    # Export to a specific CSV file
#    Export-FolderToCsv -FolderPath "C:\Users\Danny\Videos" -CsvPath "C:\Users\Danny\Videos\massImageFix.csv"

    # Export only MP4 + JPG (skip PNG/WEBP)
#    Export-FolderToCsv -FolderPath folderFileListExport -Extensions @("*.mp4","*.jpg")


#######========================================================================================================================================================
} 1001 {  ##-- replace single short dash with long dash, then replace double long dash with double short dash, on SRT files

gci $basePath *.srt -recurse | ForEach {
  (Get-Content $_ | ForEach {$_ -replace "-", "–"}) | Set-Content $_ 
}

gci $basePath *.srt -recurse | ForEach {
  (Get-Content $_ | ForEach {$_ -replace "––", "--"}) | Set-Content $_ 
}


}
#######========================================================================================================================================================
#######========================================================================================================================================================
#######========================================================================================================================================================
}