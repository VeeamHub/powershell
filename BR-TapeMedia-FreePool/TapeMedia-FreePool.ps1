
# This script returns the tapes that are assigned to the Unrecognized Media Pool and moves them to the Free Media Pool

# Get the Unrecogized Media Pool ID First
$UnPool = Get-VBRTapeMediaPool -Name "Unrecognized"

# Get the list of tapes
$NewTapes = Get-VBRTapeMedium -MediaPool $UnPool


if ($null -ne $NewTapes) {
    
    # Get the Free Media Pool ID
    $FreePool = Get-VBRTapeMediaPool -Name "Free"

    # Move Media From Unrognized to Free Pool
    $Move = Move-VBRTapeMedium -Medium $NewTapes -MediaPool $FreePool

    # Inventory the new tapes
    $Inventory = Start-VBRTapeInventory -Medium $NewTapes
}
