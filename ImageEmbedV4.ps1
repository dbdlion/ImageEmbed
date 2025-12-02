Clear-Host
Set-Location C:\
# ================== EDIT THESE VARIABLES ==================
<#
$ImageInput = "C:\Users\Danny\Videos\~TCT_Workshop\Test2\how-the-grinch-stole-christmas-53d3e7cca719d.jpg"
$VideoInput = "C:\Users\Danny\Videos\~TCT_Workshop\Test2\How the Grinch stole Christmas (1966).avi"
$subInput = "C:\Users\Danny\Videos\~TCT_Workshop\Test2\backup\How the Grinch stole Christmas (1966).srt"
#>

$ImageInput = "C:\Users\Danny\Pictures\!!Film Vault Posters\17 Miracles.jpg"
$VideoInput = "E:\17 Miracles.mkv"
#$subInput = "E:\wandavision - embed !!SUBS!! & image\WandaVision.srt"


$VideoFolder = "E:\#Fixing"
$ImageFolder = "C:\Users\Danny\Pictures\Movie Posters\!Replace\"

# columns: Video,Image
$MapCsv      = "C:\Users\Danny\Videos\Video Fix 04.csv"
#$MapCsv      = "C:\Users\Danny\Videos\dcomImage.csv"

# ================== UNCOMMONLY TOUCHED VARIABLES ==================
$cleanBackups = "Yes"
$Timestamp  = "00:12:14"   # Used only for option 4 (set thumbnail from timestamp)

# ================== DON'T TOUCH THESE VARIABLES ==================
$ErrorActionPreference = "Stop"
$ImageOutput = [System.IO.Path]::ChangeExtension($ImageInput, ".jpg")
$TempOutput  = $VideoInput.Replace(".mp4", "_withthumbnail.mp4")
$BackupFile  = $VideoInput + ".tvid"
$err = ""
$Global:ErrorCount = 0
#$Global:MovieCount = 0

# ================== GLOBAL ERROR LOG ==================

$Global:ErrorCount   = 0
$Global:SuccessCount = 0
$Global:ErrorLog     = "C:\Users\Danny\Videos\errorLog.txt"
if (Test-Path $Global:ErrorLog) { Remove-Item $Global:ErrorLog -Force }


# ================== GLOBAL ERROR LOG ==================
<#
$Global:ErrorCount   = 0
$Global:SuccessCount = 0
$DriveLetter = (Get-Item $VideoFolder).PSDrive.Name

# Decide on error log location based on drive
if ($DriveLetter -eq "C") {
    $ErrorLogFolder = [Environment]::GetFolderPath("MyVideos")            # Use standard Videos folder if C drive exists
} else {
    $ErrorLogFolder = "$DriveLetter`:\"                                   # Use root of the drive
}

$Global:ErrorLog = Join-Path $ErrorLogFolder "errorLog.txt"               # Build final path

if (-not (Test-Path $ErrorLogFolder)) {                                   # Ensure the folder exists
    New-Item -ItemType Directory -Path $ErrorLogFolder | Out-Null
}

if (Test-Path $Global:ErrorLog) {                                         # Clear old log if exists
    Remove-Item $Global:ErrorLog -Force
}
#>

# ==========================================================
<#
FIXES / CLEAN-UPS
-For "Convert-MP4", only show "Running MP4 convert" when not doing batches
-All errors, if batched, should show up in the error log; not just the one in MP4 Convert, Time difference (there might actually be more, not 100% sure)
-#7 and #8 probably need fixing
-Possibly need more Global variables


#>

# ======================= FUNCTIONS ========================


function Get-VideoDuration {
    param([string]$VideoPath)
    
    $duration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$VideoPath"
    return [math]::Round([double]$duration, 2)
}


function Log-Errors {
    param([string[]]$Errors)
    foreach ($e in $Errors) {
        Write-Host $e -ForegroundColor Red
        Add-Content -Path $Global:ErrorLog -Value $e
        $Global:ErrorCount++
    }
}


function Convert-JPG { #1
    param([string]$ImagePath)

    $errs = @()
    $shortName = [IO.Path]::GetFileName($ImagePath)
    $ext = [IO.Path]::GetExtension($ImagePath).ToLower()

    if ($ext -notin @(".jpg",".png",".bmp",".tif",".tiff",".gif",".webp",".jpeg",".avif",".svg",".ico",".jfif")) {
        Write-Host "Skipping non-image file: $shortName" -ForegroundColor Yellow; return
    }

    if (-not $BatchMode) { Write-Host "Running JPG Convert on: $shortName" }

    $jpg = [IO.Path]::ChangeExtension($ImagePath, ".jpg")

    if (Test-Path $jpg) { return $jpg }
    elseif (-not (Test-Path $ImagePath)) {
        $errs += "Image not found: $ImagePath"
        Log-Errors $errs
        return
    }

    ffmpeg -hide_banner -loglevel error -y -i "$ImagePath" "$jpg" 2>>"$Global:ErrorLog" -nostdin


    if (Test-Path $jpg) {
        Write-Host "JPG image available: $jpg" -ForegroundColor Green
        return $jpg
    } else {
        $errs += "Failed to convert image to JPG: $ImagePath"
        Log-Errors $errs
    }
}


function Convert-MP4 { #2
    param([string]$VideoPath, [switch]$BatchMode)

    if (-not (Test-Path $VideoPath)) {   Write-Host "Video file not found: $VideoPath" -ForegroundColor DarkRed; return }

    $errs = @()
    $shortName = [IO.Path]::GetFileName($VideoPath)
    $ext = [IO.Path]::GetExtension($VideoPath).ToLower()

    if ($VideoPath -match "\.(tvid|bak)$" -or $ext -notin @(".mp4",".mkv",".avi",".mov",".wmv",".flv",".m4v",".divx")) {
        Write-Host "Skipping non-video or backup file: $shortName" -ForegroundColor Yellow; return
    }

    if (-not $BatchMode) { Write-Host "Running MP4 Convert on: $shortName" }

    $mp4 = [IO.Path]::ChangeExtension($VideoPath, ".mp4")

    if (Test-Path $mp4) { return $mp4 }

    ffmpeg -hide_banner -loglevel error -y -i "$VideoPath" -c copy "$mp4" -nostdin 2>&1 | Out-Null

    if (-not (Test-Path $mp4)) {
        $errs += "Failed to convert video: $VideoPath"
        Log-Errors $errs
        return
    }

    $origDuration = Get-VideoDuration -VideoPath $VideoPath
    $newDuration  = Get-VideoDuration -VideoPath $mp4
    $diff = [math]::Abs($origDuration - $newDuration)

    if ($diff -gt 0.5) {
        $errs += "Duration mismatch for $shortName → Original $origDuration sec, Converted $newDuration sec"
        Log-Errors $errs
    }

    if (-not $errs) {
        $Global:SuccessCount++
        Write-Host "MP4 video available: $mp4" -ForegroundColor Green
    }

    return $mp4
}




function Embed-Thumbnail { #3
    param([string]$VideoPath, [string]$ImagePath)

    $jpg = Convert-JPG -ImagePath $ImagePath
    $mp4 = Convert-MP4 -VideoPath $VideoPath
    Write-Host "Running Embed on: $ImagePath, $VideoPath"

    $oldSize = (Get-Item $mp4).Length

    if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }


    if (-not (Test-Path $jpg)) { Write-Host "Embedding Failed. Image not found: $jpg" -ForegroundColor Red; return }
    if (-not (Test-Path $mp4)) { Write-Host "Embedding Failed. Video not found: $mp4" -ForegroundColor Red; return } 

    ########################    

    $dir  = Split-Path $mp4
    $name = [IO.Path]::GetFileNameWithoutExtension($mp4)
    $ext  = [IO.Path]::GetExtension($mp4)
    $temp1 = Join-Path $dir "$name`_temp1$ext"
    $temp2 = Join-Path $dir "$name`_temp2$ext"
    $bak   = "$mp4.tvid"
    if (Test-Path $bak) { $bak = "$mp4.tvid_$(Get-Date -Format yyyyMMddHHmmss)" }




##############################################
##############################################

#<#

    try {

	    # Remove existing attached images before embedding the new one
	    ffmpeg -hide_banner -loglevel error -nostdin -y `
		    -i "$mp4" -map 0 -map -0:v:m:attached_pic -c copy "$temp1" 2>>"$VideoFolder\errorLog.txt"

	    # Now embed the new thumbnail
	    ffmpeg -hide_banner -loglevel error -nostdin -y `
		    -i "$temp1" -i "$jpg" -map 0 -map 1 -c copy -disposition:v:1 attached_pic "$temp2" 2>>"$VideoFolder\errorLog.txt"

	    Remove-Item "$temp1" -Force
	    #Rename-Item "$temp.tmp" "$temp"

    }
    catch {
        $Global:ErrorCount++; Write-Host "Error converting file: $mp4 ; $_" -ForegroundColor Red
    }
#>

##############################################
<#
    # Check if MP4 already has an embedded image
    $hasThumbnail = $false
    $ffmpegOutput = ffmpeg -hide_banner -loglevel error -i $mp4 2>&1

    if ($ffmpegOutput -match "Video: mjpg") {
        $hasThumbnail = $true
    }

    if ($hasThumbnail) {
        Write-Host "Thumbnail already embedded in: $VideoInput" -ForegroundColor Cyan

	    # Remove existing attached images before embedding the new one
	    ffmpeg -hide_banner -loglevel error -nostdin -y `
		    -i "$mp4" -map 0 -map -0:v:m:attached_pic -c copy "$temp1" 2>>"$VideoFolder\errorLog.txt"

	    # Now embed the new thumbnail
	    ffmpeg -hide_banner -loglevel error -nostdin -y `
		    -i "$temp1" -i "$jpg" -map 0 -map 1 -c copy -disposition:v:1 attached_pic "$temp2" 2>>"$VideoFolder\errorLog.txt"

	    Remove-Item "$temp1" -Force
	    #Rename-Item "$temp.tmp" "$temp"


    } else {
        Write-Host "No embedded thumbnail found for: $VideoInput" -ForegroundColor DarkGray


        ffmpeg -hide_banner -loglevel error -nostdin -y `
            -i "$mp4" -i "$jpg" -map 0 -map 1 -c copy -disposition:v:1 attached_pic "$temp2" 2>>"$VideoFolder\errorLog.txt"
    }

#>
##############################################



    if (Test-Path $temp2) {
        $newSize = (Get-Item $temp2).Length

        <#
        if ($newSize -le $oldSize) {
            $Global:ErrorCount++
            Write-Host "Warning: New file size ($newSize bytes) is not larger than original ($oldSize bytes). Thumbnail may not have embedded correctly." -ForegroundColor Yellow
        }
        #>

        # Convert to MB
        $oldMB = [math]::Round($oldSize / 1MB, 2)
        $newMB = [math]::Round($newSize / 1MB, 2)
        $diffMB = [math]::Round([math]::Abs($newMB - $oldMB), 2)

        if ($newMB -lt $oldMB -and $diffMB -gt 1) {
            $Global:ErrorCount++
            Write-Host "Warning: New file ($newMB MB) is smaller than original ($oldMB MB). Thumbnail may not have embedded correctly." -ForegroundColor Yellow
        }

        Rename-Item -LiteralPath "$mp4" -NewName "$bak"
        Rename-Item -LiteralPath "$temp2" -NewName "$mp4"
        Write-Host "Thumbnail embedded → $mp4  (backup: $bak)" -ForegroundColor Green
    } else {
        Write-Host "Embedding failed — no output created. Original left untouched." -ForegroundColor Red; return
    }


}


function TimestampThumbnail { #4
    param([string]$VideoPath, [string]$Timestamp)
    $mp4 = Convert-MP4 -VideoPath $VideoPath
    if (-not $mp4) { $Global:ErrorCount++; Write-Host "Video file does not exist: $mp4" -ForegroundColor Red; return }

    $frame = [IO.Path]::ChangeExtension($mp4, "_frame.jpg")
    ffmpeg -y -ss $Timestamp -i "$mp4" -frames:v 1 "$frame" 2>$null -nostdin
    if (Test-Path $frame) {
        Embed-Thumbnail -VideoPath $mp4 -ImagePath $frame
        Remove-Item "$frame" -Force
    } else {
        $Global:ErrorCount++; Write-Host "Failed to extract frame at $Timestamp" -ForegroundColor Red
    }
}


function BackupAndFinalize-Mp4Rename { #5
    param(
        [string]$mp4
    )

    # Fix accidental double extension (".mp4.mp4")
    if ($mp4 -like "*.mp4.mp4") {
        $fixed = $mp4 -replace "\.mp4\.mp4$", ".mp4"
        if (Test-Path $fixed) { $Global:ErrorCount++; Write-Host "Error: Cannot auto-fix .mp4.mp4 → $fixed because target already exists" -ForegroundColor Red; return  }
        Rename-Item -LiteralPath $mp4 -NewName $fixed
        Write-Host "Fixed double '.MP4' extension on file: $mp4 → $fixed" -ForegroundColor Cyan
        $mp4 = $fixed
    }


    $dir  = Split-Path $mp4
    $name = [IO.Path]::GetFileNameWithoutExtension($mp4)
    $ext  = [IO.Path]::GetExtension($mp4)
    $temp = Join-Path $dir "$name`_withthumbnail$ext"
    $bak  = "$mp4.tvid"

    # Ensure the following: 1) Input exists;   2) Thumbnail version exists;   Avoid overwriting an existing .tvid
    if (-not (Test-Path $mp4)) { $Global:ErrorCount++; Write-Host "Error: Original file not found: $mp4" -ForegroundColor Red; return }
    if (-not (Test-Path $temp)) { $Global:ErrorCount++; Write-Host "Error: Thumbnail file not found: $temp" -ForegroundColor Red; return }
    if (Test-Path $bak) { $Global:ErrorCount++; Write-Host "Note: Backup already exists: $bak" -ForegroundColor Yellow; return }


    try {
        Rename-Item -LiteralPath "$mp4" -NewName "$bak"         # Backup original
        Rename-Item -LiteralPath "$temp" -NewName "$mp4"        # Promote temp thumbnail file to final

        Write-Host "Renamed original → $bak and thumbnail file → $mp4" -ForegroundColor Green

        # Rename any sidecar files (same basename, non-mp4)
        Get-ChildItem -Path $dir -File | Where-Object {
            $_.BaseName -eq $name -and $_.Extension -ne ".mp4" -and $_.Extension -ne ".tvid"
        } | ForEach-Object {
            $sidecarBak = "$($_.FullName).tvid"
            if (-not (Test-Path $sidecarBak)) {
                Rename-Item -LiteralPath $_.FullName -NewName $sidecarBak
                Write-Host "Renamed sidecar $_ to $sidecarBak" -ForegroundColor Cyan
            } else {
                $Global:ErrorCount++; Write-Host "Note: Sidecar backup already exists: $sidecarBak" -ForegroundColor Yellow
            }
        }
    }
    catch {
        $Global:ErrorCount++; Write-Host "Error renaming files for $mp4 : $_" -ForegroundColor Red
    }
}



function BatchConvert-JPG { #6
    param([string]$ImageFolder)

    $images = Get-ChildItem -Path $ImageFolder -File
    $count = 0
    foreach ($img in $images) {
        $count++
        Write-Host "[$count] Converting $($img.Name)..."
        Convert-JPG -ImagePath $img.FullName -BatchMode
    }

    Write-Host "Batch complete. $Global:SuccessCount successful, $Global:ErrorCount errors." -ForegroundColor Cyan
    if ($Global:ErrorCount -gt 0) {
        Write-Host "See error log at $Global:ErrorLog" -ForegroundColor Magenta
    }
}


function BatchConvert-MP4 { #7
    param([string]$VideoFolder)

    $videos = Get-ChildItem -Path $VideoFolder -File
    $count = 0
    foreach ($v in $videos) {
        $count++
        Write-Host "[$count] Converting $($v.Name)..."
        Convert-MP4 -VideoPath $v.FullName -BatchMode
    }

    Write-Host "Batch complete. $Global:SuccessCount successful, $Global:ErrorCount errors." -ForegroundColor Cyan
    if ($Global:ErrorCount -gt 0) {
        Write-Host "See error log at $Global:ErrorLog" -ForegroundColor Magenta
    }
}


#========================================================================================================================
#========================================================================================================================





#8
function BatchEmbed-Thumbnail {
    param([string]$CsvPath, [string]$VideoFolder, [string]$ImageFolder)

    $rows = Import-Csv -Path $CsvPath -Header "Video","Image"
    $cnt = 0

    <#
    foreach ($r in $rows) {
        $v = Join-Path $VideoFolder $r.Video
        $i = Join-Path $ImageFolder $r.Image

        Write-Host "Running Embed-Thumbnail on: $v with $i"
        Embed-Thumbnail -VideoPath $v -ImagePath $i
    }
    #>

    foreach ($r in $rows) {
        $cnt++; Write-Host "Batch File #$cnt"
        $v = if ([IO.Path]::IsPathRooted($r.Video)) { $r.Video } else { Join-Path $VideoFolder $r.Video }
        $i = if ([IO.Path]::IsPathRooted($r.Image)) { $r.Image } else { Join-Path $ImageFolder $r.Image }

        if (-not (Test-Path $v)) {   
            Write-Host "Video file not found: $v" -ForegroundColor DarkRed
        } elseif (-not (Test-Path $i)) {   
            Write-Host "Image file not found: $i" -ForegroundColor DarkRed        
        } else {

            Write-Host "Running Embed-Thumbnail on: $v with $i"
            Embed-Thumbnail -VideoPath $v -ImagePath $i

            $mp4 = [IO.Path]::ChangeExtension($v, ".mp4")

            # --- NEW CLEANUP SECTION ---
            if ($cleanBackups.ToLower() -in @("yes","y")) {
                $bak = "$mp4.tvid"
                if (Test-Path $bak) {
                    try {
                        Remove-Item -LiteralPath $bak -Force
                        Write-Host "Deleted backup file: $bak" -ForegroundColor DarkGray
                    }
                    catch { Write-Host "Warning: Could not delete backup file: $bak ($_)" -ForegroundColor Yellow  }
                }
            }
        }
    }
}


#10
function GetMoviesWithMultipleAudio {
    param(
        [string]$Path = ".",
        [string]$OutFile = "AudioReport.txt"
    )
    $ffprobe = "C:\ProgramData\chocolatey\bin\ffprobe.exe"  # full path here

    # Extensions you want to scan
    $extensions = @("*.mkv","*.mp4","*.avi","*.mov","*.wmv","*.m4v","*.divx")

    $results = @()

    foreach ($ext in $extensions) {
        Get-ChildItem -Path $Path -Include $ext -Recurse | ForEach-Object {
            $file = $_.FullName
            try {
                # Run ffprobe safely
                $streams = & $ffprobe -v error -select_streams a `
                    -show_entries stream=index:stream_tags=language `
                    -of default=noprint_wrappers=1:nokey=0 "$file" 2>$null

                if ($streams) {
                    $count = ($streams | Select-String "index=").Count
                    if ($count -gt 1) {
                        # Extract just language tags
                        $langs = ($streams | Select-String "TAG:language=").Line `
                            -replace "TAG:language=", "" `
                            -join ", "
                        $results += "$file has $count audio tracks: $langs"
                    }
                }
            }
            catch {
                Write-Warning "Skipped file due to error: $file"
            }
        }
    }

    if ($results.Count -gt 0) {
        $results | Out-File -FilePath $OutFile -Encoding UTF8
        Write-Host "Done! Results saved to $OutFile"
    }
    else {
        Write-Host "No video files with multiple audio tracks found."
    }
}




function GetMoviesWithMultipleAudio2 {
    param(
        [string]$Path = ".",
        [string]$OutFile = "AudioReport.txt"
    )

    # Extensions you want to scan
    $extensions = @("*.mkv","*.mp4","*.avi","*.mov","*.wmv","*.m4v")
    $results = @()

    foreach ($ext in $extensions) {
        Get-ChildItem -Path $Path -Include $ext -Recurse | ForEach-Object {
            $file = $_.FullName
            try {
                # Run ffprobe silently and capture output
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "ffprobe"
                $psi.Arguments = "-v error -select_streams a -show_entries stream=index:stream_tags=language -of default=noprint_wrappers=1:nokey=0 `"$file`""
                $psi.RedirectStandardOutput = $true
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true

                $proc = New-Object System.Diagnostics.Process
                $proc.StartInfo = $psi
                $proc.Start() | Out-Null
                $streams = $proc.StandardOutput.ReadToEnd()
                $proc.WaitForExit()

                if ($streams) {
                    $count = ($streams | Select-String "index=").Count
                    if ($count -gt 1) {
                        # Extract just language tags
                        $langs = ($streams | Select-String "TAG:language=").Line -replace "TAG:language=", "" -join ", "
                        $results += "$file has $count audio tracks: $langs"
                    }
                }
            }
            catch {
                Write-Warning "Skipped file due to error: $file"
            }
        }
    }

    if ($results.Count -gt 0) {
        $results | Out-File -FilePath $OutFile -Encoding UTF8
        Write-Host "Done! Results saved to $OutFile"
    }
    else {
        Write-Host "No video files with multiple audio tracks found."
    }
}


function Embed-Thumbnail-And-Subtitles {  #11
    param( [string]$VideoPath, [string]$ImagePath, [string]$SubPath )

    $jpg = Convert-JPG -ImagePath $ImagePath
    $mp4 = Convert-MP4 -VideoPath $VideoPath

    if (-not (Test-Path $jpg)) { Write-Host "Image missing: $jpg" -ForegroundColor Red; return }
    if (-not (Test-Path $mp4)) { Write-Host "Video missing: $mp4" -ForegroundColor Red; return }
    if (-not (Test-Path $SubPath)) { Write-Host "Subtitles missing: $SubPath" -ForegroundColor Red; return }


    $dir  = Split-Path $mp4
    $name = [IO.Path]::GetFileNameWithoutExtension($mp4)
    $ext  = [IO.Path]::GetExtension($mp4)
    $temp1 = Join-Path $dir "$name`_nosplash$ext"
    $temp2 = Join-Path $dir "$name`_withthumb$ext"

    <#
    # 1) Remove existing attached images
    # -----------------------------------------------------------
    ffmpeg -hide_banner -loglevel error -nostdin -y `
        -i "$mp4" -map 0 -map -0:v:m:attached_pic -c copy "$temp1" `
        2>>"$Global:ErrorLog"


    #>

    # 2) Add the thumbnail and optionally SRT subtitle
    # -----------------------------------------------------------
    if (Test-Path $SubPath) {


        ffmpeg -hide_banner -loglevel error -nostdin -y `
            -i "$mp4" -i "$jpg" -i "$SubPath" `
            -map 0:v -map 0:a -map 1:v -map 2:s `
            -c copy `
            -c:s mov_text `
            -disposition:v:1 attached_pic `
            "$temp2" 2>>"$VideoFolder\errorLog.txt"


<#
        ffmpeg -hide_banner -loglevel error -nostdin -y `
            -i "$temp1" -i "$jpg" -i "$SubPath" `
            -map 0 -map 1 -map 2 `
            -c copy `
            -metadata:s:s:0 language=eng `
            -disposition:v:1 attached_pic `
            "$temp2" 2>>"$VideoFolder\errorLog.txt"
            #>

 #       ffmpeg -hide_banner -loglevel error -nostdin -y `
	#	    -i "$temp1" -i "$jpg" -map 0 -map 1 -c copy -disposition:v:1 attached_pic "$temp2" 2>>"$VideoFolder\errorLog.txt"

    }

    ffmpeg -i input.mp4 -i subtitles.srt -map 0:v -map 0:a -map 1:s -c copy -c:s mov_text output.mp4

    <#

    # 3) Finalize
    # -----------------------------------------------------------
    $bak = "$mp4.tvid"
    if (Test-Path $bak) {
        $bak = "$mp4.tvid_$(Get-Date -Format yyyyMMddHHmmss)"
    }

    if (Test-Path $temp2) {
        Rename-Item -LiteralPath "$mp4"  -NewName "$bak"
        Rename-Item -LiteralPath "$temp2" -NewName "$mp4"
        Remove-Item "$temp1" -Force
        Write-Host "Embedded thumbnail + subs → $mp4   (backup: $bak)" -ForegroundColor Green
    }
    else {
        Write-Host "Embedding failed — no output file created." -ForegroundColor Red
        if (Test-Path $temp1) { Remove-Item "$temp1" -Force }
    }

    #>
}


#========================================================================================================================


function BatchEmbed-Thumbnailv2 {
    param([string]$CsvPath, [string]$VideoFolder, [string]$ImageFolder)
    $rows = Import-Csv -Path $CsvPath -Header "Video","Image"
    foreach ($r in $rows) {
        Embed-Thumbnail -VideoPath $v -ImagePath $i
    }
}


function BatchFinalize-Renames {
    param([string]$CsvPath, [string]$VideoFolder)
    $rows = Import-Csv -Path $CsvPath -Header "Video","Image"
    foreach ($r in $rows) {
        $v = if ([IO.Path]::IsPathRooted($r.Video)) { $r.Video } else { Join-Path $VideoFolder $r.Video }
        if (-not (Test-Path $v)) { Write-Host "Video not found: $v" -ForegroundColor Red; continue }

        $dir  = Split-Path $v
        $name = [IO.Path]::GetFileNameWithoutExtension($v)
        $ext  = [IO.Path]::GetExtension($v)

        $temp = Join-Path $dir "$name`_withthumbnail$ext"
        $bak  = "$v.tvid"
        if (Test-Path $temp) {
            Rename-Item -LiteralPath "$v" -NewName "$bak"
            Rename-Item -LiteralPath "$temp" -NewName "$v"
            Write-Host "Renamed original → $bak and thumbnail file → $v" -ForegroundColor Green
        } else {
            Write-Host "No _withthumbnail file found for $v" -ForegroundColor Yellow
        }
    }
}

# ================== SWITCH MENU ==================
Write-Host "Choose an option:"
Write-Host "1. Convert image to JPG"
Write-Host "2. Convert video to MP4"
Write-Host "3. Embed image into video (convert if needed)"
Write-Host "4. Extract internal frame as thumbnail"
Write-Host "5. One-off rename fix"
Write-Host "6. Batch JPG Convert"
Write-Host "7. Batch MP4 Convert"
Write-Host "8. Batch embed (CSV)"
Write-Host "9. Batch finalize renames (CSV)"
Write-Host "10. Dual Audio Track Checking"
Write-Host "11. SRT Embedding"

$choice = Read-Host "Enter number"

switch ($choice) {
    "1" { 
            $jpg = Convert-JPG -ImagePath $ImageInput                    
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "2" { 
            $mp4 = Convert-MP4 -VideoPath $VideoInput                    
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "3" { 
            Embed-Thumbnail -VideoPath $VideoInput -ImagePath $ImageInput 
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "4" { 
            TimestampThumbnail -VideoPath $VideoInput -Timestamp $Timestamp

            ### I like the idea of confirming the file is larger after embedding the image

            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "5" { 
           <#
               -Not 100% sure, but it likely makes sense to have BATCH_RENAME call a function 'ONE-OFF-RENAME' (or something like that)
               -things to check - No ".mp4.mp4" - fix if so (do this first) - obviously give error if there's already a file of that name
               -confirm both files exist before renaming - abort with error of which file is missing beforehand
               -make a mention if ".tvid" exists already "Note: backup .tvid already 
           #>

           BackupAndFinalize-Mp4Rename -mp4 $VideoInput
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "6" { 
            BatchConvert-JPG -ImageFolder $ImageFolder
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "7" { 
            BatchConvert-MP4 -VideoFolder $VideoFolder
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "8" { 
            BatchEmbed-Thumbnail -CsvPath $MapCsv -VideoFolder $VideoFolder -ImageFolder $ImageFolder 
            ## BATCH ERRORS
            <## For Batch errors, send these to a log. 
                Make sure this includes any conversions from MKV/other to MP4
                Also include for any photo embedding, or photo conversions;
                List move name first, then the error?? Maybe not?
                Confirm file size fits/matches
            #>

            #if ($Global:ErrorCount -gt 0) { Write-Host " Total errors: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "9" { 
            BatchFinalize-Renames -CsvPath $MapCsv -VideoFolder $VideoFolder 
            if ($Global:ErrorCount -gt 0) { Write-Host " Total errors so far: $($Global:ErrorCount) " -ForegroundColor DarkRed -BackgroundColor DarkGray }
    }
    "10" { 
            GetMoviesWithMultipleAudio -Path $VideoFolder -OutFile "C:\Users\Danny\Videos\AudioReport.txt"

            #ffprobe -v error -select_streams a -show_entries stream=index:stream_tags=language -of default=noprint_wrappers=1:nokey=0 "C:\Users\Danny\Videos\~TCT_Workshop\Test2\Princess Mononoke.mkv"

    
    }
    "11" {
        Embed-Thumbnail-And-Subtitles -VideoPath $VideoInput -ImagePath $ImageInput -SubPath $subInput

    }
    default { Write-Host "Invalid choice." }
}
