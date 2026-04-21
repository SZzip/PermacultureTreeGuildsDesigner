<#


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
function ConvertFrom-Hashtable {
    [CmdletBinding()]
    Param([Parameter(Mandatory = $true)]
        [hashtable]$hashTable
    )
    Begin {
        $Object = New-Object psobject;
    }
    Process {
        $hashTable.keys | ForEach-Object {
            $Object | Add-Member -MemberType NoteProperty -Name $_ -Value $hashTable[$_] | Out-Null;
        }
    }
    End {
        $Object
    }
}


function global:Import-PlantData {

    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true )]
        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$OutputPath = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\",

        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string]$OverrideFile = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\override.csv",

        [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
        [string[]]$NaturaDbPriorityFields = @("t_common-name_text")
    )

    Begin {
        $LookUp = @{
            "Nitrogen Fixer"                   = "b_nitrogen-fix-element"
            "Ground Cover"                     = "b_ground-cover_element"
            "Attracts Wildlife"                = "b_insects_element"
            "Agroforestry Services: Windbreak" = "b_wind-breaking_element"
            "Fuel"                             = "b_fuel_element"
            "Fodder"                           = "b_fodder_element"
            "Repellent"                        = "b_pest_element"
            "Living trellis"                   = "b_animal-protection_element"
            "Dynamic accumulator"              = "b_mineral-fix-element"
            "Condiment"                        = "b_culinaric_element"
        }
        $Name = $Name.Trim()
    }

    Process {
        Write-Verbose "Reading override file ""$OverrideFile"""
        if (Test-Path $OverrideFile -PathType Leaf) {
            $OverrideData = Import-Csv $OverrideFile
        }
        else {
            Write-Information "No override file found."
        }
        #Write-Host "Processing $Name"
        $NaturaDbUri = "https://www.naturadb.de/pflanzen/$($Name -replace ' ','-')/"
        $PfafUri = "https://pfaf.org/user/Plant.aspx?LatinName=$($Name -replace ' ','+')"

        $old = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'
        Write-Verbose "Requesting $NaturaDbUri"
        $NaturaDbResponse = try { 
            Invoke-WebRequest -Uri "$NaturaDbUri" 
        }
        catch [System.Net.WebException] { Write-Warning "An exception was caught: $($_.Exception.Message) $NaturaDbUri" } 
        Write-Verbose "Requesting $PfafUri"
        $PfafResponse = try { 
            Invoke-WebRequest -Uri "$PfafUri"
        }
        catch [System.Net.WebException] { Write-Warning "An exception was caught: $($_.Exception.Message) $PfafUri" } 
        $Global:ProgressPreference = $old
        $NaturaDbData = @{}
        $PfafData = @{}
        $PfafFieldData = @{}
        
        Write-Verbose "Parsing NaturaDb data"
        $NaturaDbHtml = New-Object -Com "HTMLFile"
        if ($NaturaDbResponse.StatusCode -eq 200) {
            try {
                $NaturaDbHtml.write([System.Text.Encoding]::Unicode.GetBytes($NaturaDbResponse.Content)) | Out-Null
            }
            catch {
                $NaturaDbHtml.IHTMLDocument2_write([System.Text.Encoding]::Unicode.GetBytes($NaturaDbResponse.Content)) | Out-Null
            }
            $NaturaDbHtml.all.tags("tr") | 
            Where-Object { $_.parentElement.parentElement.className -eq "mt-1" } | ForEach-Object { 
                $key = ($_.firstChild.innerText.Trim() -replace ":", "").Trim()
                if ($key -eq "Fruchtreife" -or $key -eq "Blühzeit") {
                    $value = $_.lastChild.innerHtml.Trim()
                }
                else {
                    $value = $_.lastChild.innerText.Trim()
                }
                if ($null -ne $key -and $null -ne $value) {
                    $NaturaDbData.Add($key, $value)
                }
            }
        }
        
        Write-Verbose "Parsing PFAF data..."
        $PfafDbHtml = New-Object -Com "HTMLFile"
        if ($PfafResponse.StatusCode -eq 200) {
            try {
                $PfafDbHtml.write([System.Text.Encoding]::Unicode.GetBytes($PfafResponse.Content)) | Out-Null
            }
            catch {
                $PfafDbHtml.IHTMLDocument2_write([System.Text.Encoding]::Unicode.GetBytes($PfafResponse.Content)) | Out-Null
                <#Do this if a terminating exception happens#>
            }
            Write-Verbose "Reading Main Table"
            $PfafDbHtml.all.tags("tr") | Where-Object {
                $_.parentElement.parentElement.className -like "*table-striped*" 
            } | ForEach-Object { 
                $key = $_.firstChild.innerText.Trim()
                if ( $null -ne $_.lastChild -and $null -ne $_.lastChild.innerText ) {
                    Write-Verbose "  Reading Main Table $key = $($_.lastChild.innerText.Trim())"
                    $PfafData.Add($key, $_.lastChild.innerText.Trim())
                }
                else {
                    Write-Verbose "  Reading Main Table => Dropping $key"
                }
            }
            Write-Verbose "Reading Fields"
            $PfafDbHtml.all.tags("a") | 
            Where-Object { $_.parentElement.parentElement.parentElement.className -like "boots*" } |
            ForEach-Object { 
                $key = $_.innerText.trim()
                if ( $LookUp.ContainsKey($key) ) {
                    $key = $LookUp[$key]
                }
                if ( -not $PfafFieldData.ContainsKey($key) ) {
                    Write-Verbose "  Reading Fields $key = true"
                    $PfafFieldData.Add($key, $true) 
                }
            }
            $pysicals = $PfafDbHtml.getElementById("ContentPlaceHolder1_lblPhystatment").innerText
        }
        if (($pysicals -split "`n")[0] -match 'growing to (?<height>\d+(\.\d+)?)\s*(?<unit>m|cm)') {
            $heigth = "$($Matches.height) $($Matches.unit)"
        }
        else {
            $heigth = $null
        }
        if (($pysicals -split "`n")[0] -match 'by (?<width>\d+(\.\d+)?)\s*(?<unit>m|cm)') {
            $width = "$($Matches.width) $($Matches.unit)"
        }
        else {
            $width = $null
        }

        if ($NaturaDbResponse.StatusCode -ne 200 -and [string]::IsNullOrEmpty($PfafDbHtml.getElementById("ContentPlaceHolder1_lbldisplatinname").innerText)) {
            Write-Error "ERROR: `n`tNo data found for $Name. `n`tPlease check the spelling of the Plant $Name.`n`t`n`t" -ErrorAction SilentlyContinue
        }
        else { 

            $PfafPlantData = @{
                "h_PFAF_URI"                  = $PfafUri    
                "h_NaturaDB_URI"              = $NaturaDbUri
                "b_sun-full_element"          = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/sun.jpg" })
                "b_sun_mid_element"           = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/partsun.jpg" })
                "b_sun_shadow_element"        = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/fullsun.jpg" })
                "b_water-dry_element"         = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/water1.jpg" })
                "b_water-mid_element"         = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/water2.jpg" })
                "b_water-wet_element"         = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/water3.jpg" })
                "b_water-plant_element"       = $null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.href -like "*/water4.jpg" })
                "b_grow-speed-high_icon"      = $pysicals -like "*at a fast rate*" 
                "b_grow-speed-low_icon"       = $pysicals -like "*at a slow rate*" 
                "b_grow-speed-mid_icon"       = $pysicals -like "*at a medium rate*" 
                "b_ph-very-acid_element"      = $pysicals -like "*pH:*very acid*soils.*"
                "b_ph-acid_element"           = $pysicals -like "*pH:*mildly acid*soils.*"
                "b_ph-neutral_element"        = $pysicals -like "*pH:*neutral*soils.*"
                "b_ph-alkaline_element"       = $pysicals -like "*pH:mildly alkaline*soils.*"
                "b_ph-very-alkaline_element"  = $pysicals -like "*pH:very alkaline*soils.*"
                "b_ph-saline_element"         = $pysicals -like "*pH:*saline*soils.*"
                "b_wind-breaking-on-sea_icon" = $pysicals -like "*tolerate maritime exposure*"
                #"pysicals"                    = $pysicals
                "t_common-name_text"          = ($PfafData["Common Name"] -split "," | Select-Object -First 1).Trim()
                "t_latin-name_text"           = "$Name"
                "t_height_text"               = $heigth
                "t_width_text"                = $width
                "t_eatable-score_text"        = $PfafData["Edibility Rating"] -replace "\((\d) of (\d)\)", '$1'
                "b_eatable_element"           = $PfafData["Edibility Rating"] -replace "\((\d) of (\d)\)", '$1' -gt 2
                "t_climate-zone_text"         = $PfafData["USDA hardiness"] 
                "t_meds-score_text"           = $PfafData["Medicinal Rating"] -replace "\((\d) of (\d)\)", '$1'
                "b_meds_element"              = $PfafData["Medicinal Rating"] -replace "\((\d) of (\d)\)", '$1' -gt 2
                "t_material_score_text"       = $PfafData["Other Uses"] -replace "\((\d) of (\d)\)", '$1'
                "b_material_element"          = $PfafData["Other Uses"] -replace "\((\d) of (\d)\)", '$1' -gt 2
                "b_flower-0_element"          = $null
                "b_flower-1_element"          = $null
                "b_flower-2_element"          = $null
                "b_flower-3_element"          = $null
                "b_flower-4_element"          = $null
                "b_flower-5_element"          = $null
                "b_flower-6_element"          = $null
                "b_flower-7_element"          = $null
                "b_flower-8_element"          = $null
                "b_flower-9_element"          = $null
                "b_flower-10_element"         = $null
                "b_flower-11_element"         = $null
                "b_fruit-0_element"           = $null
                "b_fruit-1_element"           = $null
                "b_fruit-2_element"           = $null
                "b_fruit-3_element"           = $null
                "b_fruit-4_element"           = $null
                "b_fruit-5_element"           = $null
                "b_fruit-6_element"           = $null
                "b_fruit-7_element"           = $null
                "b_fruit-8_element"           = $null
                "b_fruit-9_element"           = $null
                "b_fruit-10_element"          = $null
                "b_fruit-11_element"          = $null
                "b_root-system_flat"          = $null
                "b_root-system_heart"         = $null
                "b_root-system_tap"           = $null
                "b_root-system_deep"          = $null
            }

            $NaturaDbHtml = New-Object -Com "HTMLFile"
            $NaturaDbPlantData = @{
                "h_PFAF_URI"                  = $PfafUri    
                "h_NaturaDB_URI"              = $NaturaDbUri
                "b_sun-full_element"          = $NaturaDbData["Licht"] -like "*icon--x-sun_0*"
                "b_sun_mid_element"           = $NaturaDbData["Licht"] -like "*icon--x-sun_1*"
                "b_sun_shadow_element"        = $NaturaDbData["Licht"] -like "*icon--x-sun_2*"
                "b_water-dry_element"         = $NaturaDbData["Wasser"] -like "*icon--x-water_0*"
                "b_water-mid_element"         = $NaturaDbData["Wasser"] -like "*icon--x-water_1*"
                "b_water-wet_element"         = $NaturaDbData["Wasser"] -like "*icon--x-water_2*"
                "b_water-plant_element"       = $NaturaDbData["Wasser"] -like "*Wasserpflanze*" #$null -ne ($PfafDbHtml.all.tags("img") | Where-Object { $_.title -eq "Water Plants" })
                "b_grow-speed-high_icon"      = $null
                "b_grow-speed-low_icon"       = $null
                "b_grow-speed-mid_icon"       = $null
                "b_ph-very-acid_element"      = $null
                "b_ph-acid_element"           = $null
                "b_ph-neutral_element"        = $null
                "b_ph-alkaline_element"       = $null
                "b_ph-very-alkaline_element"  = $null
                "b_ph-saline_element"         = $null
                "b_wind-breaking-on-sea_icon" = $null
                "b_root-system_flat"          = $NaturaDbData["Wurzelsystem"] -like "*Flachwurzler*"
                "b_root-system_heart"         = $NaturaDbData["Wurzelsystem"] -like "*Herzwurzler*"
                "b_root-system_tap"           = $NaturaDbData["Wurzelsystem"] -like "*Pfahlwurzler*"
                "b_root-system_deep"          = $NaturaDbData["Wurzelsystem"] -like "*Tiefwurzler*"
                "t_common-name_text"          = $($NaturaDbHtml.all.tags("h1")[0].innerHtml -replace "<SPAN.*<[\\/]SPAN>").Trim()
                "t_latin-name_text"           = "$Name"
                "t_height_text"               = $NaturaDbData["Höhe"] -replace ".*>", "" -replace " ", ""
                "t_width_text"                = $NaturaDbData["Breite"] -replace ".*>", "" -replace " ", ""
                "t_eatable-score_text"        = $null
                "b_eatable_element"           = $null
                "t_climate-zone_text"         = $null
                "t_meds-score_text"           = $null
                "b_meds_element"              = $null
                "t_material_score_text"       = $null
                "b_material_element"          = $null
            }
            $Fruchtmonate = $NaturaDbData["Fruchtreife"] -split "`n" | Select-String "month-indicator"
            $Fruchtmonate | ForEach-Object {
                $NaturaDbData.Add( "b_fruit-" + [array]::IndexOf($Fruchtmonate, $_) + "_element", $_ -like "*data-active=*" )
            }
            if ($null -eq $Fruchtmonate) {
                $(0..11) | ForEach-Object {
                    $NaturaDbData.Add( "b_fruit-" + $_ + "_element", $false )
                }
            }
            
            $Blütenmonate = $NaturaDbData["Blühzeit"] -split "`n" | Select-String "month-indicator"
            $Blütenmonate | ForEach-Object {
                Write-Verbose "$_"
                $NaturaDbData."b_flower-$([array]::IndexOf($Blütenmonate, $_))_element" = $_ -like "*data-active=*"
            }
            if ($null -eq $Blütenmonate) {
                $(0..11) | ForEach-Object {
                    $NaturaDbData["b_flower-" + $_ + "_element"] = $false 
                }
            }
            Write-Verbose "$($NaturaDbData | Convertto-json -Depth 10)"

            # Replace empty values with data from Natura DB
            $PlantData = $PfafPlantData
            
            $emptyKeys = $PlantData.Keys | Where-Object {
                $null -eq $PlantData."$_"
            } 
            Write-Verbose "emptyKeys: $($emptyKeys | Out-String)"
            Write-Verbose "NaturaDbPlantData: $($NaturaDbPlantData | Out-String)"
            $emptyKeys | ForEach-Object {
                Write-Verbose "$_ => $($NaturaDbData[$_])"
                $PlantData."$_" = $NaturaDbData."$_"
            }
        
            $LookUp.Keys | ForEach-Object {
                if ( -not $PlantData.ContainsKey($LookUp[$_]) ) {
                    $PlantData[$LookUp[$_]] = $false
                }
            }

            # if ($PlantData."t_width_text" -eq "") {
            #     if (($pysicals -split "`n")[0] -match 'by (?<width>\d+(\.\d+)?)\s*(?<unit>m|cm)') {
            #         $width = $Matches.width
            #         $PlantData."t_width_text" = "$width - $width m"
            #     }
            # }
        
            # if ($PlantData."t_climate-zone_text" -eq "" -and $PlantData."t_climate-zone_text" -eq "Coming soon") {
            #     $PlantData["t_climate-zone_text"] = ">$($NaturaDbData["frostverträglich"] -replace ".*bis Klimazone (\d[abc]?).*", '$1')"
            # }
        
            # if ($PlantData."t_common-name_text" -eq "") {
            #     $PlantData."t_common-name_text" = $($($NaturaDbHtml.all.tags("h1")[0].innerHtml -replace "<SPAN.*>(.*)<[\\/]SPAN>", "`$1") -split ",")[0]
            # }
        
            $OverrideFields = $OverrideData | Where-Object {
                $_."t_latin-name_text" -eq $PlantData."t_latin-name_text"
            }
            $OverrideFields.psobject.Properties | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Value) -and $_.Value -ne "???" } | ForEach-Object {
                $PlantData[$_.Name] = $_.Value
            }
            ConvertFrom-HashTable $PlantData
        }
    }
}