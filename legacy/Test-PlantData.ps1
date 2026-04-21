<#
.SYNOPSIS
.NOTES
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

function global:Test-PlantData {

    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true )]
        [ValidateNotNullOrEmpty()]
        [hashtable]
        $PlantData,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$OverrideFile = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\override.csv"
    )

    Begin {
        [PSCustomObject[]]$OverrideFileData = $()
        if (Test-Path $OverrideFile -PathType Leaf) {
            $OverrideFileData = Import-Csv $OverrideFile -Encoding utf8 -UseCulture
        }
        $FieldNames = @(
            'b_animal-protection_element'
            'b_culinaric_element'
            'b_eatable_element'
            'b_flower-0_element'
            'b_flower-1_element'
            'b_flower-10_element'
            'b_flower-11_element'
            'b_flower-2_element'
            'b_flower-3_element'
            'b_flower-4_element'
            'b_flower-5_element'
            'b_flower-6_element'
            'b_flower-7_element'
            'b_flower-8_element'
            'b_flower-9_element'
            'b_fodder_element'
            'b_fruit-0_element'
            'b_fruit-1_element'
            'b_fruit-10_element'
            'b_fruit-11_element'
            'b_fruit-2_element'
            'b_fruit-3_element'
            'b_fruit-4_element'
            'b_fruit-5_element'
            'b_fruit-6_element'
            'b_fruit-7_element'
            'b_fruit-8_element'
            'b_fruit-9_element'
            'b_fuel_element'
            'b_ground-cover_element'
            'b_grow-speed-high_icon'
            'b_grow-speed-low_icon'
            'b_grow-speed-mid_icon'
            'b_insects_element'
            'b_material_element'
            'b_meds_element'
            'b_mineral-fix-element'
            'b_nitrogen-fix-element'
            'b_pest_element'
            'b_ph-acid_element'
            'b_ph-alkaline_element'
            'b_ph-neutral_element'
            'b_ph-saline_element'
            'b_ph-very-acid_element'
            'b_ph-very-alkaline_element'
            'b_sun_mid_element'
            'b_sun_shadow_element'
            'b_sun-full_element'
            'b_water-dry_element'
            'b_water-mid_element'
            'b_water-plant_element'
            'b_water-wet_element'
            'b_wind-breaking_element'
            'b_wind-breaking-on-sea_icon'
            't_climate-zone_text'
            't_common-name_text'
            't_eatable-score_text'
            't_height_text'
            't_latin-name_text'
            't_material_score_text'
            't_meds-score_text'
            't_width_text'
        )
    }

    Process {
        $MissingFields = $FieldNames | Where-Object { $PlantData.Keys -notcontains $_ -or [string]::IsNullOrEmpty($PlantData[$_]) }
                        
        if ($MissingFields.Count -gt 0) {
            Write-Warning "Missing fields in $($PlantData.'t_latin-name_text'): $($MissingFields -join ', '). Use Overwrite File to fix it."
            $Plant = $OverrideFileData | Where-Object { $_.'t_latin-name_text' -eq $PlantData.'t_latin-name_text' }
            if ($null -ne $Plant) {
                $MissingFields | Where-Object { $Plant."$_" -eq "" -or $null -eq $Plant."$_" } | ForEach-Object { 
                    $Plant | Add-Member -MemberType NoteProperty -Name $_ -Value "???" | Out-Null
                }
            }
            if ($null -eq $Plant) {
                $Plant = New-Object -TypeName PSObject
                $Plant | Add-Member -MemberType NoteProperty -Name 't_latin-name_text' -Value $PlantData.'t_latin-name_text' | Out-Null
                $MissingFields | ForEach-Object { $Plant | Add-Member -MemberType NoteProperty -Name $_ -Value "???" }
            }
            $OverrideFileData += $Plant
        }
    }

    End {
        if ($null -ne $OverrideFileData) {
            if (Test-Path $OverrideFile -PathType Leaf) {
                Remove-Item $OverrideFile
            }
            $OverrideFileData | Export-Csv $OverrideFile -NoTypeInformation -NoClobber -Encoding UTF8 -UseCulture -Force
        }
    }
}