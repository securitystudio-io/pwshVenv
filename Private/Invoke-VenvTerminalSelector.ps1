function Invoke-VenvTerminalSelector {
    <#
    .SYNOPSIS
        Displays an interactive terminal menu with keyboard navigation and live filtering.
    .DESCRIPTION
        Renders a searchable list of venv profiles in the console. Supports Up/Down arrow navigation,
        live substring filtering, Enter to select, and Escape to cancel.
    .PARAMETER Profiles
        Array of PSCustomObject profiles returned by Get-Pwshvenv.
    .OUTPUTS
        The selected PSCustomObject profile, or $null if cancelled.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [array] $Profiles
    )

    if (-not $Profiles -or $Profiles.Count -eq 0) {
        return $null
    }

    # If terminal is non-interactive or input is redirected, return first match
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected -or (-not [Environment]::UserInteractive)) {
        return $Profiles[0]
    }

    $filter = ''
    $selectedIndex = 0
    $previousLineCount = 0
    $esc = [char]27
    $maxPageSize = 8
    $maxRenderHeight = $maxPageSize + 4  # Header, items, pagination, footer

    # Ensure buffer has enough space below cursor so rendering never triggers scrolling
    $startRow = $null
    try {
        $currentTop = [Console]::CursorTop
        $bufferHeight = [Console]::BufferHeight
        $needed = ($currentTop + $maxRenderHeight) - $bufferHeight + 1
        if ($needed -gt 0) {
            [Console]::Write("`n" * $needed)
            [Console]::SetCursorPosition(0, $currentTop - $needed)
        }
        $startRow = [Console]::CursorTop
    } catch {
        # Fallback if Console buffer coordinates are unavailable
    }

    try {
        # Hide cursor during interactive menu
        [Console]::Write("$esc[?25l")

        while ($true) {
            # Filter profiles based on current filter text (case-insensitive substring)
            $filtered = @($Profiles | Where-Object {
                $null -eq $filter -or $filter -eq '' -or
                $_.Name -match [regex]::Escape($filter) -or
                $_.PythonPath -match [regex]::Escape($filter) -or
                ($_.SetLocation -and $_.SetLocation -match [regex]::Escape($filter))
            })

            if ($selectedIndex -ge $filtered.Count) {
                $selectedIndex = [Math]::Max(0, $filtered.Count - 1)
            }

            # Prepare lines to render
            $lines = [System.Collections.Generic.List[string]]::new()
            $filterDisplay = if ($filter) { $filter } else { "$esc[90m(type to filter)$esc[0m" }
            $lines.Add("$esc[1;36m? Select pwshVenv:$esc[0m $filterDisplay")

            if ($filtered.Count -eq 0) {
                $lines.Add("  $esc[90mNo matching virtual environments found.$esc[0m")
            } else {
                $startIdx = [Math]::Max(0, [Math]::Min($selectedIndex - [Math]::Floor($maxPageSize / 2), [Math]::Max(0, $filtered.Count - $maxPageSize)))
                $endIdx = [Math]::Min($filtered.Count - 1, $startIdx + $maxPageSize - 1)

                for ($i = $startIdx; $i -le $endIdx; $i++) {
                    $item = $filtered[$i]
                    $locStr = if ($item.SetLocation) { " ($($item.SetLocation))" } else { '' }
                    $itemText = "$($item.Name) [$($item.PythonPath)]$locStr"

                    if ($i -eq $selectedIndex) {
                        $lines.Add("  $esc[36m>$esc[0m $esc[1;7m $itemText $esc[0m")
                    } else {
                        $lines.Add("    $itemText")
                    }
                }

                if ($filtered.Count -gt $maxPageSize) {
                    $lines.Add("  $esc[90m(Showing $($startIdx + 1)-$($endIdx + 1) of $($filtered.Count))$esc[0m")
                }
            }

            $lines.Add("$esc[90m[Up/Down: Navigate | Type: Filter | Enter: Select | Esc: Cancel]$esc[0m")

            # Reposition to top anchor row
            if ($startRow -ne $null) {
                try {
                    [Console]::SetCursorPosition(0, $startRow)
                } catch {
                    if ($previousLineCount -gt 0) {
                        [Console]::Write("$esc[${previousLineCount}A")
                    }
                }
            } elseif ($previousLineCount -gt 0) {
                [Console]::Write("$esc[${previousLineCount}A")
            }

            # Render lines and overwrite any extra lines from previous frame
            $totalLinesToRender = [Math]::Max($lines.Count, $previousLineCount)
            for ($i = 0; $i -lt $totalLinesToRender; $i++) {
                if ($i -lt $lines.Count) {
                    [Console]::Write("$esc[2K`r$($lines[$i])`n")
                } else {
                    [Console]::Write("$esc[2K`r`n")
                }
            }
            $previousLineCount = $lines.Count

            # Read user key input
            $keyInfo = [Console]::ReadKey($true)

            switch ($keyInfo.Key) {
                ([ConsoleKey]::UpArrow) {
                    if ($filtered.Count -gt 0) {
                        $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $filtered.Count - 1 }
                    }
                }
                ([ConsoleKey]::DownArrow) {
                    if ($filtered.Count -gt 0) {
                        $selectedIndex = if ($selectedIndex -lt $filtered.Count - 1) { $selectedIndex + 1 } else { 0 }
                    }
                }
                ([ConsoleKey]::Enter) {
                    if ($filtered.Count -gt 0) {
                        return $filtered[$selectedIndex]
                    }
                }
                ([ConsoleKey]::Escape) {
                    return $null
                }
                ([ConsoleKey]::Backspace) {
                    if ($filter.Length -gt 0) {
                        $filter = $filter.Substring(0, $filter.Length - 1)
                        $selectedIndex = 0
                    }
                }
                Default {
                    if (-not [char]::IsControl($keyInfo.KeyChar)) {
                        $filter += $keyInfo.KeyChar
                        $selectedIndex = 0
                    }
                }
            }
        }
    } finally {
        # Erase menu lines and restore cursor
        try {
            if ($startRow -ne $null) {
                [Console]::SetCursorPosition(0, $startRow)
                for ($i = 0; $i -lt $previousLineCount; $i++) {
                    [Console]::Write("$esc[2K`r`n")
                }
                [Console]::SetCursorPosition(0, $startRow)
            } elseif ($previousLineCount -gt 0) {
                [Console]::Write("$esc[${previousLineCount}A")
                for ($i = 0; $i -lt $previousLineCount; $i++) {
                    [Console]::Write("$esc[2K`r`n")
                }
                [Console]::Write("$esc[${previousLineCount}A")
            }
        } catch { }
        [Console]::Write("$esc[?25h")
    }
}
