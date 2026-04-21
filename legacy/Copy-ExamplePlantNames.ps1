<#
.DESCRIPTION
    This script copies the example file of latin plant names, typically used in
    the permaculture systems to the output folder.

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
function global:Copy-ExamplePlantNames {

    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]
        $OutputPath = "$([Environment]::GetFolderPath("MyDocuments"))\PermacultureTreeGuildsDesigner\PlantNames.txt",

        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Path -Path $filePath -PathType Leaf })]
        [String]
        $Path = "$((Get-Module PermacultureTreeGuildsDesigner).ModuleBase)/Example/PlantNames.txt"
    )

    Begin {
        $null = New-Item -Path (Split-Path -Parent $OutputPath) -ItemType Directory -Force
        Copy-Item $Path $OutputPath -Force
    }

    End {
        Write-Host "Copied example plant names to $OutputPath."
    }
}