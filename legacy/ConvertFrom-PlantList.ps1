<#
.DESCRIPTION
    This script transforms a text file with latin plant names into a plant data
    objects.

    This module generates map elements and management cards for your permaculture
    design management game. The aim of these elements is to make the design 
    process easier, more flexible and simpler, more flexible and to the point. 
    There are several game components targeting different steps within the 
    permaculture design process.

.Notes
    Copyright (c) 2024 Sebastian Schucht

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
function global:ConvertFrom-PlantList {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\PlantNames.txt",
        
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OutputPath = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $OverrideFile = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\override.csv",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]
        $AssetPath = "$((Get-Module PermacultureTreeGuildsDesigner).ModuleBase)\Assets",

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [int[]]
        $Scales = $(1, 10, 20, 50, 100)
    )

    Begin {
        Write-Progress -Activity "Processing plant list" -Status "Reading plant list from $Path" -PercentComplete 1 -Id 1 
        $PlantNames = Get-Content $Path
        $SvgFiles = Get-ChildItem -Path $AssetPath -Filter *.svg
        Remove-Item "$OutputPath\warnings.log" -Force -ErrorAction SilentlyContinue
    }

    Process {
        Write-Progress -Activity "Processing PlantList" -Status "Downloading plant data" -PercentComplete 33 -Id 1
        $PlantData = $PlantNames | ForEach-Object {
            Write-Verbose "Downloading Data of $_"
            Write-Progress -Activity "Downloading plant data" -Status "Downloading plant data of $_" -PercentComplete (([array]::IndexOf($PlantNames, $_)) / $PlantNames.Count * 100) -Id 2 -ParentId 1
            Import-PlantData $_ 3>> "$OutputPath\warnings.log"
            
        }
        Write-Progress -Id 2 -Completed -Activity "Downloading plant data"

        Write-Progress -Activity "Processing PlantList" -Status "Converting to SVG Tree cycles" -PercentComplete 66 -Id 1
        Export-Clixml -Path "$OutputPath\PlantData.xml" -InputObject $PlantData -Encoding utf8
        $PlantData | ForEach-Object { 
            $Plant = $_
            $SvgFiles | ForEach-Object {
                $SvgFile = $_
                $Scales | ForEach-Object {
                    Write-Progress -Activity "Converting to SVG Tree cycles" -Status "Converting to SVG Tree cycles for $($Plant."t_latin-name_text") with template $SvgFile at Scale $_)" -PercentComplete (([array]::IndexOf($PlantNames, $Plant."t_latin-name_text")) / $PlantNames.Count * 100) -Id 3 -ParentId 1
                    if (-not (Test-Path "$OutputPath\1 to $_" -PathType Container)) {
                        New-Item -Path "$OutputPath\1 to $_" -ItemType Directory | Out-Null
                    }
                    $Plant | ConvertTo-TreeCircle -SvgPath $SvgFile.FullName -OutputPath "$OutputPath\1 to $_" -Scale $_ 3>> "$OutputPath\warnings.log"
                }
            }
        }
        Write-Progress -Id 3 -Completed -Activity "Converting to SVG Tree cycles" -PercentComplete 100
        Write-Progress -Activity "Processing PlantList" -Status "Done" -Id 1 -Completed -PercentComplete 100
    }

    End {
        $PlantData 
    }
}