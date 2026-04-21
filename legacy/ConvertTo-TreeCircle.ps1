function global:ConvertTo-TreeCircle {
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true )]
        [PSCustomObject]$PlantData,

        [Parameter(Mandatory = $true)]
        [string]$SvgPath,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\",

        [Parameter(Mandatory = $false)]
        [int]$Scale = 20,

        [Parameter(Mandatory = $false)]
        [double]$pxPerMm = 0.264583
    
    )
    
    $FileBaseName = $(Split-Path $SvgPath -Leaf) -replace ".svg", ""
    if ([string]::IsNullOrEmpty($PlantData.'t_common-name_text')) {
        $FileName = "$FileBaseName-$($PlantData.'t_latin-name_text' -replace " ","_")"
    }
    else {
        $FileName = "$FileBaseName-$($PlantData.'t_common-name_text' -replace " ","_")"
    }
    [xml]$svg = Get-Content $SvgPath
    [System.Xml.XmlNodeList]$elements = $svg.SelectNodes("//*[@id][starts-with(@id,'b_') or starts-with(@id,'t_')]")

    $UnvisibleIds = @(
        "b_grow-speed-high_icon", 
        "b_grow-speed-low_icon", 
        "b_grow-speed-mid_icon"
    )

    
    $PKeys = $PlantData.PSObject.Properties.Name | Where-Object { $_.StartsWith("b_") -or $_.StartsWith("t_") } | Sort-Object -Unique
    $EKeys = $elements.id | Sort-Object -Unique

    $diff = Compare-Object $EKeys $PKeys -PassThru
    if ($null -ne $diff) {
        Write-Warning "Differnz der Felder zwischen PlantData und Svg: $diff."
    }

    #
    # 00 	rgb( 0, 0, 0) 	#000000
    # 01 	rgb( 0, 0, 255) 	#0000FF
    # 02 	rgb( 255, 0, 0) 	#FF0000 => Line         # Cut - Line
    # 03 	rgb( 0, 224, 0) 	#00E000
    # 04 	rgb( 208, 208, 0) 	#D0D000
    # 05 	rgb( 255, 128, 0) 	#FF8000
    # 06 	rgb( 0, 224, 224) 	#00E0E0
    # 07 	rgb( 255, 0, 255) 	#FF00FF => Line         # Outer Line
    # 08 	rgb( 180, 180, 180) 	#B4B4B4 => Line 
    # 09 	rgb( 0, 0, 160) 	#0000A0 => Line
    # 10 	rgb( 160, 0, 0) 	#A00000
    # 11 	rgb( 0, 160, 0) 	#00A000
    # 12 	rgb( 160, 160, 0) 	#A0A000
    # 13 	rgb( 192, 128, 0) 	#C08000
    # 14 	rgb( 0, 160, 255) 	#00A0FF
    # 15 	rgb( 160, 0, 160) 	#A000A0 => Line
    # 16 	rgb( 128, 128, 128) 	#808080 => Line
    # 17 	rgb( 125, 135, 185) 	#7D87B9 => Line
    # 18 	rgb( 187, 119, 132) 	#BB7784 => Line
    # 19 	rgb( 74, 111, 227) 	#4A6FE3 => Line
    # 20 	rgb( 211, 63, 106) 	#D33F6A
    # 21 	rgb( 140, 215, 140) 	#8CD78C
    # 22 	rgb( 240, 185, 141) 	#F0B98D
    # 23 	rgb( 246, 196, 225) 	#F6C4E1
    # 24 	rgb( 250, 158, 212) 	#FA9ED4 => Line
    # 25 	rgb( 80, 10, 120) 	#500A78 => Line
    # 26 	rgb( 180, 90, 0) 	#B45A00 => Line
    # 27 	rgb( 0, 71, 84) 	#004754
    # 28 	rgb( 134, 250, 136) 	#86FA88 => Line
    # 29 	rgb( 255, 219, 102) 	#FFDB66 => Line
    # T1 	rgb(243, 105, 38) 	#F36926 => Frame
    # T2 	rgb(12, 150, 217) 	#0C96D9 => Frame
    #

    $elements | ForEach-Object {
        [System.Xml.XmlNode]$element = $_
        [string]$key = $_.id
        
        if ( $key.StartsWith('b_') -and ( $PlantData."$key" -like "*FALSCH*" -or $PlantData."$key" -like "*FALSE*" -or $PlantData."$key" -eq $false ) ) {
            Write-Verbose "Processing id=$key => $($PlantData."$key")"
            $attribute = $element.OwnerDocument.CreateAttribute("style")
            if ($key.EndsWith("_icon")) {
                if ($UnvisibleIds.Contains($key)) {
                    # Unsichtbare Icons T2 => 0x0c96d9
                    #$attribute.Value = "stroke:#0c96d9; stroke-width:0.01;"
                    Write-Verbose "Unvisible Icon $key => #0c96d9"
                    $element.ParentNode.RemoveChild($element) | Out-Null
                }
                else {
                    # Sichtbare Icons C27
                    Write-Verbose "Visible Icon $key => #004754"
                    $attribute.Value = "stroke:#004754; stroke-width:0.01; fill:none;"
                }
            }
            else {
                # Inaktive Elemente
                Write-Verbose "Inactive Element $key => #FF00FF"
                $attribute.Value = "stroke:#FF00FF; stroke-width:0.01; fill:none;"
            }
            $element.Attributes.Append( $attribute ) | Out-Null
        }
        if ( $key.StartsWith('b_') -and $null -eq $PlantData."$key" ) {
            Write-Warning "$key not found in PlantData => #999."
            $attribute = $element.OwnerDocument.CreateAttribute("style")
            $attribute.Value = "stroke:#999; stroke-width:0.01;"
            $element.Attributes.Append( $attribute ) | Out-Null
        }

        # Text only
        if ( $key.StartsWith('t_') -and $null -ne $PlantData."$key" ) {
            $element.InnerXml = $PlantData."$key"
        }

    }
    $elementMax = $svg.SelectSingleNode('//*[@id="e_max-cut-line"]');
    $elementMin = $svg.SelectSingleNode('//*[@id="e_min-cut-line"]');
    $elementMid = $svg.SelectSingleNode('//*[@id="e_mid-cut-line"]');
    if ($null -ne $PlantData.'t_width_text' -and $PlantData.'t_width_text' -ne "" -and $null -ne $elementMax) {
        Write-Verbose "Getting width $t_width_text"
        if ($PlantData.'t_width_text' -replace ",", "." -replace "((?<min>[\d\.]+)\s*-\s*)?(?<max>[\d\.]+)\s*(?<unit>cm|m)") {
            $Unit = $Matches.unit.Trim()
            switch ($Unit) {
                "cm" { $unitFaktor = 10 }
                "m" { $unitFaktor = 1000 }
                Default {
                    Write-Error "Unknown Unit $Unit of $($PlantData.'t_width_text')"
                }
            }
            Write-Verbose "$($PlantData.'t_width_text') => Unit: $Unit, Faktor: $unitFaktor"
            
            [double]$width = 0.0
            if ([double]::TryParse($Matches.min, [ref]$width)) {
                [double]$minCutLineRadius = $width * $unitFaktor / $pxPerMm / $Scale / 2
            }
            else {
                if ($null -ne $elementMin) {
                    $elementMin.ParentNode.RemoveChild($elementMin) | Out-Null
                }
            }
            if ([double]::TryParse($Matches.max, [ref]$width)) {
                [double]$maxCutLineRadius = $width * $unitFaktor / $pxPerMm / $Scale / 2
            }
            else {
                if ($null -ne $elementMax) {
                    $elementMax.ParentNode.RemoveChild($elementMax) | Out-Null
                }
            }
            if ($null -ne $minCutLineRadius -and $null -ne $maxCutLineRadius) {
                [double]$midCutLineRadius = ($minCutLineRadius + $maxCutLineRadius) / 2
            }
            else {
                if ($null -ne $elementMid) {
                    $elementMid.ParentNode.RemoveChild($elementMid) | Out-Null
                }
            }
            
            if ($null -ne $elementMax) {
                $orgRx = $elementMax.rx
                [double]$ViewportSize = $maxCutLineRadius * 2 + 2 * $pxPerMm
                $attribute = $elementMax.OwnerDocument.CreateAttribute("rx")
                $attribute.Value = $maxCutLineRadius
                $elementMax.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMax.OwnerDocument.CreateAttribute("ry")
                $attribute.Value = $maxCutLineRadius
                $elementMax.Attributes.Append( $attribute ) | Out-Null
                
                $attribute = $elementMax.OwnerDocument.CreateAttribute("cx")
                $attribute.Value = $viewportSize / 2
                $elementMax.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMax.OwnerDocument.CreateAttribute("cy")
                $attribute.Value = $ViewportSize / 2
                $elementMax.Attributes.Append( $attribute ) | Out-Null
                
                $labelGroup = $svg.SelectSingleNode('//*[@id="g_Info-Label_group"]')
                if ($null -ne $labelGroup) {
                    $factor = $($minCutLineRadius / $orgRx)
                    $currentSize = 188 * $factor
                    $translateX = ($ViewportSize - $currentSize) / 2
                    $attribute = $elementMax.OwnerDocument.CreateAttribute("transform")
                    $attribute.Value = "translate($translateX $translateX) scale($factor $factor)"
                    $labelGroup.Attributes.Append( $attribute ) | Out-Null
                }
            
                $SvgElement = $svg.svg
                $attribute = $SvgElement.OwnerDocument.CreateAttribute("viewBox")
                $attribute.Value = "0 0 $ViewportSize $ViewportSize"
                $SvgElement.Attributes.Append( $attribute ) | Out-Null
            
                $attribute = $SvgElement.OwnerDocument.CreateAttribute("height")    
                $attribute.Value = "$($ViewportSize/2*$pxPerMm)mm"
                $SvgElement.Attributes.Append( $attribute ) | Out-Null
                $attribute = $SvgElement.OwnerDocument.CreateAttribute("width")    
                $attribute.Value = "$($ViewportSize/2*$pxPerMm)mm"
                $SvgElement.Attributes.Append( $attribute ) | Out-Null
            }
        
        
            if ($null -ne $elementMin) {
                $attribute = $elementMin.OwnerDocument.CreateAttribute("cx")
                $attribute.Value = $ViewportSize / 2
                $elementMin.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMin.OwnerDocument.CreateAttribute("cy")
                $attribute.Value = $ViewportSize / 2
                $elementMin.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMin.OwnerDocument.CreateAttribute("rx")
                $attribute.Value = $minCutLineRadius
                $elementMin.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMin.OwnerDocument.CreateAttribute("ry")
                $attribute.Value = $minCutLineRadius
                $elementMin.Attributes.Append( $attribute ) | Out-Null
            }
            
            
            if ($null -ne $elementMid) {
                $attribute = $elementMid.OwnerDocument.CreateAttribute("cx")
                $attribute.Value = $ViewportSize / 2
                $elementMid.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMid.OwnerDocument.CreateAttribute("cy")
                $attribute.Value = $ViewportSize / 2
                $elementMid.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMid.OwnerDocument.CreateAttribute("rx")
                $attribute.Value = $midCutLineRadius
                $elementMid.Attributes.Append( $attribute ) | Out-Null
                $attribute = $elementMid.OwnerDocument.CreateAttribute("ry")
                $attribute.Value = $midCutLineRadius
                $elementMid.Attributes.Append( $attribute ) | Out-Null
            }
        }
    }
    else {
        Write-Warning "t_width_text not found in $($PlantData.'t_latin-name_text')."
    }

    if ($null -ne $element4 -and $PlantData.'h_NaturaDB_URI' -ne "") {
        $element4 = $svg.SelectSingleNode('//*[@id="i_NaturaDB_qrcode"]')
        if ($null -ne $attribute) {
            [double]$width = ([double]$element4.width) * $factor
            New-QRCodeURI $PlantData.'h_NaturaDB_URI' -OutPath "$OutputPath/$FileName.qrcode.png"
            $attribute = $element4.OwnerDocument.CreateAttribute("href")
            $attribute.Value = "./$FileName.qrcode.png"
            $element4.Attributes.Append( $attribute ) | Out-Null
            $attribute = $element4.OwnerDocument.CreateAttribute("width")
            $attribute.Value = $width
            $element4.Attributes.Append( $attribute ) | Out-Null
            $attribute = $element4.OwnerDocument.CreateAttribute("height")
            $attribute.Value = $width
            $element4.Attributes.Append( $attribute ) | Out-Null
            $attribute = $element4.OwnerDocument.CreateAttribute("x")
            $attribute.Value = $maxCutLineRadius + $minCutLineRadius / 5
            $element4.Attributes.Append( $attribute ) | Out-Null
            $attribute = $element4.OwnerDocument.CreateAttribute("y")
            $attribute.Value = $maxCutLineRadius - $minCutLineRadius / 3 * 2
            $element4.Attributes.Append( $attribute ) | Out-Null
        }
    }
    $svg.Save( "$OutputPath/$FileName.svg" )
}