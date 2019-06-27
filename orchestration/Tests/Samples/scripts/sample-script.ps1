[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    [string] $FirstParameter,
    [Parameter(Mandatory=$true)]
    [string] $SecondParameter,
    [Parameter(Mandatory=$true)]
    [string] $ThirdParameter
)

Write-Output "$SecondParameter";