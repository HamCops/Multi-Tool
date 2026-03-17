# Multi-Tool UI/UX Overhaul — Phase 2

## Context
The first overhaul (async infrastructure, keyboard shortcuts, search, status bar, etc.) is complete and committed. This plan covers the next round of improvements: RichTextBox with colored output, right-click context menu, collapsible button groups, resizable layout, operation counter, and enhanced tooltips.

**File:** `C:\Users\cameron.admin\Multi-Tool\Multi-Tool.PS1` (~2026 lines, only file modified)

---

## Phase 1: Right-Click Context Menu on Output (Low Risk)

Add a `ContextMenu` to the output TextBox in XAML. This is purely additive and works with the current TextBox (and survives the RichTextBox migration in Phase 5 with minor tweaks).

**XAML changes** — Add inside the `<TextBox Name="terminalOutputBox" ...>` element (line ~275):
```xml
<TextBox.ContextMenu>
    <ContextMenu Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White">
        <MenuItem Name="ctxCopy" Header="Copy" InputGestureText="Ctrl+Shift+C"/>
        <MenuItem Name="ctxSelectAll" Header="Select All"/>
        <Separator/>
        <MenuItem Name="ctxSearch" Header="Search" InputGestureText="Ctrl+F"/>
        <MenuItem Name="ctxClear" Header="Clear" InputGestureText="Ctrl+L"/>
        <Separator/>
        <MenuItem Name="ctxSaveToFile" Header="Save to File..."/>
    </ContextMenu>
</TextBox.ContextMenu>
```

**Code changes** — After control references (~line 335), add FindName calls and click handlers:
- `ctxCopy` → `Set-Clipboard` with output text
- `ctxSelectAll` → `$terminalOutputBox.SelectAll()`
- `ctxSearch` → toggle search bar (same as Ctrl+F)
- `ctxClear` → clear output (same as Ctrl+L)
- `ctxSaveToFile` → `SaveFileDialog` (.txt filter), write output text to file

~40 new lines.

---

## Phase 2: Status Bar Operation Counter (Low Risk)

Track total operations completed in the session and display in the status bar.

**XAML changes** — Add a right-aligned label to the StatusBar (line ~290):
```xml
<StatusBar Grid.Row="5" ...>
    <StatusBarItem>
        <Label Name="lblStatus" .../>
    </StatusBarItem>
    <StatusBarItem HorizontalAlignment="Right">
        <Label Name="lblOpCount" Content="Ops: 0" Foreground="#8BB8D8" Padding="4,0" FontSize="12"/>
    </StatusBarItem>
</StatusBar>
```

**Code changes:**
- Add `$script:OperationCount = 0` near async infrastructure (~line 340)
- Add `$lblOpCount = $Window.FindName("lblOpCount")` in control references
- In the DispatcherTimer tick handler, when an operation completes successfully, increment `$script:OperationCount` and update `$lblOpCount.Content = "Ops: $script:OperationCount"`

~10 new lines.

---

## Phase 3: Collapsible GroupBoxes via Expander (Moderate Risk)

Replace each of the 4 `GroupBox` elements with WPF `Expander` controls. Expander is the native WPF collapsible container — it provides a built-in toggle arrow.

**XAML changes** — Replace each GroupBox (lines ~135-215). Example for Diagnostics:
```xml
<!-- Before -->
<GroupBox Header="Diagnostics" Grid.Column="0" Grid.Row="0" Style="{StaticResource GroupHeader}">
    <WrapPanel>...</WrapPanel>
</GroupBox>

<!-- After -->
<Expander Header="Diagnostics" Grid.Column="0" Grid.Row="0" IsExpanded="True"
          Foreground="#4A90D9" BorderBrush="#2A5A8F" Margin="6" Padding="6,4" FontWeight="SemiBold">
    <WrapPanel>...</WrapPanel>
</Expander>
```

All 4 GroupBoxes → Expanders: Diagnostics, Remote Tools, Management, Utilities. All start `IsExpanded="True"`.

**Style changes** — Remove or repurpose the `GroupHeader` style. Add an Expander style that sets the toggle arrow foreground to `#4A90D9` so it's visible on the dark background. May need a simple `Setter` for the `Foreground` on the ToggleButton or a small ControlTemplate override for the arrow.

**Risk:** The default Expander arrow may be invisible on `#012456` background. Will need to verify and potentially add explicit foreground color for the header/arrow area.

~30 lines changed (replacements, not additions).

---

## Phase 4: GridSplitter Between Buttons and Output (Moderate Risk)

Allow users to drag the boundary between the button area and the output area to resize them.

**XAML changes** — Restructure the main Grid layout:

Current 6-row layout:
```
Row 0: Auto  — Input
Row 1: Auto  — Buttons (2x2 grid)
Row 2: Auto  — Progress bar
Row 3: Auto  — Search bar
Row 4: *     — Output
Row 5: Auto  — Status bar
```

New 4-row layout:
```
Row 0: Auto    — Input
Row 1: 2*      — Buttons area (scrollable) + progress + search
Row 2: Auto    — GridSplitter (horizontal, height 5)
Row 3: 5*      — Output
Row 4: Auto    — Status bar
```

The buttons, progress bar, and search bar move into Row 1 inside a nested `Grid` or `StackPanel` wrapped in a `ScrollViewer` (so collapsed expanders let the area shrink, and the ScrollViewer handles overflow if the user drags the splitter up).

**GridSplitter element:**
```xml
<GridSplitter Grid.Row="2" Height="5" HorizontalAlignment="Stretch"
              Background="#2A5A8F" Cursor="SizeNS" ResizeBehavior="PreviousAndNext"/>
```

**Key constraint:** GridSplitter only works between star-sized rows. The `2*`/`5*` ratio gives buttons ~28% and output ~72% by default.

~25 lines changed.

---

## Phase 5: RichTextBox with Colored Output (High Risk, High Impact)

Replace the plain `TextBox` with a `RichTextBox` to support colored/formatted output. This is the most invasive change.

### 5a. XAML Change

Replace the TextBox (line ~275):
```xml
<!-- Before -->
<TextBox Name="terminalOutputBox" Grid.Row="4" ... IsReadOnly="True" .../>

<!-- After -->
<RichTextBox Name="terminalOutputBox" Grid.Row="3" Margin="10,0,10,6" IsReadOnly="True"
             VerticalScrollBarVisibility="Auto" Background="#0D0D0D"
             FontFamily="Consolas" FontSize="12" Foreground="#D4D4D4"
             BorderBrush="#2A5A8F" BorderThickness="1" Padding="6"
             IsDocumentEnabled="True">
    <FlowDocument PageWidth="5000"/>
</RichTextBox>
```

The `PageWidth="5000"` prevents automatic word-wrapping at the RichTextBox width (matching current `TextWrapping="Wrap"` behavior can be toggled by setting `PageWidth` to the control's actual width or removing it).

### 5b. Rewrite `Append-Output` Function (~line 430)

Current implementation uses `$terminalOutputBox.AppendText()`. New implementation creates `Paragraph` and `Run` elements with colors:

```powershell
function global:Append-Output {
    param([string]$Text, [string]$Header = $null)

    $doc = $terminalOutputBox.Document
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $separator = "=" * 60

    # Color definitions
    $headerBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4A90D9")
    $timestampBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#8BB8D8")
    $separatorBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3A5A7F")
    $errorBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E06C75")
    $successBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#98C379")
    $warningBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#E5C07B")
    $normalBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#D4D4D4")
    $sectionBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4A90D9")

    # Header paragraph
    if ($Header) {
        $headerPara = New-Object System.Windows.Documents.Paragraph
        $headerPara.Margin = [System.Windows.Thickness]::new(0, 8, 0, 0)
        $tsRun = New-Object System.Windows.Documents.Run("[$timestamp] ")
        $tsRun.Foreground = $timestampBrush
        $hRun = New-Object System.Windows.Documents.Run($Header)
        $hRun.Foreground = $headerBrush
        $hRun.FontWeight = [System.Windows.FontWeights]::Bold
        $headerPara.Inlines.Add($tsRun)
        $headerPara.Inlines.Add($hRun)
        $doc.Blocks.Add($headerPara)

        # Separator
        $sepPara = New-Object System.Windows.Documents.Paragraph
        $sepPara.Margin = [System.Windows.Thickness]::new(0)
        $sepRun = New-Object System.Windows.Documents.Run($separator)
        $sepRun.Foreground = $separatorBrush
        $sepPara.Inlines.Add($sepRun)
        $doc.Blocks.Add($sepPara)
    }

    # Body lines — color-coded
    foreach ($line in $Text -split "`r?`n") {
        $para = New-Object System.Windows.Documents.Paragraph
        $para.Margin = [System.Windows.Thickness]::new(0)
        $run = New-Object System.Windows.Documents.Run($line)

        # Color logic
        if ($line -match '(?i)^ERROR|FAIL|OFFLINE|NOT REACHABLE|CRITICAL') {
            $run.Foreground = $errorBrush
        } elseif ($line -match '(?i)^SUCCESS|PASS|ONLINE|REACHABLE|COMPLETED|FIXED') {
            $run.Foreground = $successBrush
        } elseif ($line -match '(?i)^WARNING|WARN|CAUTION|LOW') {
            $run.Foreground = $warningBrush
        } elseif ($line -match '^\[.*\]') {
            # Section headers like [CONNECTIVITY], [DISK], etc.
            $run.Foreground = $sectionBrush
            $run.FontWeight = [System.Windows.FontWeights]::SemiBold
        } else {
            $run.Foreground = $normalBrush
        }

        $para.Inlines.Add($run)
        $doc.Blocks.Add($para)
    }

    $terminalOutputBox.ScrollToEnd()

    # Cap document size (prevent memory issues with very long sessions)
    while ($doc.Blocks.Count -gt 500) {
        $doc.Blocks.Remove($doc.Blocks.FirstBlock)
    }
}
```

### 5c. Add `Get-OutputText` Helper

New global function to extract plain text from RichTextBox (used by copy, save, search):
```powershell
function global:Get-OutputText {
    $range = New-Object System.Windows.Documents.TextRange(
        $terminalOutputBox.Document.ContentStart,
        $terminalOutputBox.Document.ContentEnd)
    return $range.Text
}
```

### 5d. Update All Text References

Every place that reads or writes `$terminalOutputBox.Text` must change:

| Location | Before | After |
|----------|--------|-------|
| **Clear output** (btnClearOutput, Ctrl+L) | `$terminalOutputBox.Text = ""` | `$terminalOutputBox.Document.Blocks.Clear()` |
| **Copy output** (btnCopyOutput, Ctrl+Shift+C) | `$terminalOutputBox.Text` | `Get-OutputText` |
| **Search** (TextChanged, F3) | `$terminalOutputBox.Text` with `IndexOf` | `Get-OutputText` with `IndexOf` (search on extracted plain text) |
| **Search highlight** | `$terminalOutputBox.Select()` | TextPointer-based selection (see below) |
| **Context menu Save** | `$terminalOutputBox.Text` | `Get-OutputText` |
| **Context menu SelectAll** | `$terminalOutputBox.SelectAll()` | `$terminalOutputBox.SelectAll()` (works on RichTextBox too) |

### 5e. Rewrite Search to Use TextPointer

The search currently uses `TextBox.Select(index, length)` and `GetLineIndexFromCharacterIndex()`. RichTextBox doesn't support these. New approach:

```powershell
function global:Find-InRichTextBox {
    param([string]$SearchText, [object]$StartPosition = $null)
    
    if (-not $StartPosition) {
        $StartPosition = $terminalOutputBox.Document.ContentStart
    }
    
    $fullText = (New-Object System.Windows.Documents.TextRange(
        $StartPosition, $terminalOutputBox.Document.ContentEnd)).Text
    
    $index = $fullText.IndexOf($SearchText, [System.StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { return $null }
    
    # Walk TextPointers to find the position
    $pointer = $StartPosition
    $charsTraversed = 0
    while ($pointer -ne $null -and $charsTraversed -lt $index) {
        $ctx = $pointer.GetPointerContext([System.Windows.Documents.LogicalDirection]::Forward)
        if ($ctx -eq [System.Windows.Documents.TextPointerContext]::Text) {
            $text = $pointer.GetTextInRun([System.Windows.Documents.LogicalDirection]::Forward)
            $remaining = $index - $charsTraversed
            if ($text.Length -ge $remaining) {
                $pointer = $pointer.GetPositionAtOffset($remaining)
                break
            }
            $charsTraversed += $text.Length
        }
        $pointer = $pointer.GetNextContextPosition([System.Windows.Documents.LogicalDirection]::Forward)
    }
    
    if ($pointer) {
        $endPointer = $pointer.GetPositionAtOffset($SearchText.Length)
        if ($endPointer) {
            return @{ Start = $pointer; End = $endPointer }
        }
    }
    return $null
}
```

Search TextChanged and F3/Enter handlers updated to use `Find-InRichTextBox` and `$terminalOutputBox.Selection.Select($result.Start, $result.End)` for highlighting.

**Known limitation:** Search terms that span across two differently-colored `Run` elements may not match. This is acceptable — the color boundaries align with line breaks, so cross-line searches wouldn't work in the old TextBox either.

~150 new/changed lines.

---

## Phase 6: Enhanced Button Tooltips (Low Risk)

Replace simple string tooltips with structured multi-line tooltips showing a title, description, and the actual command/method used.

**XAML changes** — Replace each button's `ToolTip="..."` attribute with a nested `ToolTip` element:
```xml
<Button Name="btnPing" Content="Ping" Style="{StaticResource ToolBtn}">
    <Button.ToolTip>
        <ToolTip Background="#1E3A5F" BorderBrush="#4A90D9" Foreground="White">
            <StackPanel MaxWidth="280">
                <TextBlock FontWeight="Bold" Text="Ping / Connectivity Test"/>
                <TextBlock TextWrapping="Wrap" Margin="0,4,0,0"
                    Text="Tests DNS resolution, ICMP ping, and WinRM connectivity to the target machine."/>
                <TextBlock FontStyle="Italic" Foreground="#8BB8D8" Margin="0,4,0,0"
                    Text="Command: Test-Connection, Test-WSMan"/>
            </StackPanel>
        </ToolTip>
    </Button.ToolTip>
</Button>
```

All 19 action buttons get enhanced tooltips. The 3 utility buttons (Clear, Copy, IncidentIQ) keep simple tooltips.

**Button tooltip content:**
| Button | Title | Command Hint |
|--------|-------|-------------|
| btnPing | Ping / Connectivity Test | Test-Connection, Test-WSMan |
| btnGetSystemInfo | Get System Info | Get-CimInstance Win32_* |
| btnGetUpTime | Get Uptime | Get-CimInstance Win32_OperatingSystem |
| btnFirewallStatus | Firewall Status | Get-NetFirewallProfile |
| btnHealthScan | Full Health Scan | Multiple diagnostic checks |
| btnDiskCheck | Disk Space Check | Get-CimInstance Win32_LogicalDisk |
| btnResetWiFi | Reset Wi-Fi Adapter | Disable/Enable-NetAdapter |
| btnOpenPSSession | Open PS Session | Enter-PSSession |
| btnMSRA | Remote Assistance | msra.exe /offerRA |
| btnRDC | Remote Desktop | mstsc.exe /v: |
| btnEventLog | Event Viewer | eventvwr.msc /computer: |
| btnGpUpdate | Run GPUpdate | gpupdate /force |
| btnGetInstalledSoftware | Installed Software | Registry query (HKLM) |
| btnLogOff | Remote Log Off | quser, logoff |
| btnClearPrintQueue | Clear Print Queue | Stop/Start Spooler, Clear-Item |
| btnClearDNS | Clear DNS Cache | ipconfig /flushdns |
| btnRestart | Remote Restart | Restart-Computer |
| btnFixMDT | Fix MDT Error | MDT/WDT artifact cleanup |
| btnResolve | DNS Resolve | Resolve-DnsName |

~120 lines changed (replacements).

---

## Implementation Order & Dependencies

```
Phase 1 (Context Menu)  ──┐
Phase 2 (Op Counter)    ──┤── Independent, can be done in any order
Phase 3 (Expanders)     ──┤
Phase 6 (Tooltips)      ──┘
Phase 4 (GridSplitter)  ──── Depends on Phase 3 (Expanders affect Row 1 height behavior)
Phase 5 (RichTextBox)   ──── Last: most invasive, touches search/copy/clear/context menu
```

**Recommended order:** 1 → 2 → 3 → 6 → 4 → 5

---

## Estimated Size Impact
- Current: ~2026 lines
- After: ~2400 lines (+~370 lines for RichTextBox infrastructure, context menu, tooltips, helpers)

---

## Verification

1. **Launch the app** — verify window opens with no errors, all 4 Expanders visible and expanded
2. **Collapse/expand each group** — click Expander arrows, verify buttons hide/show, arrow visible on dark background
3. **Drag GridSplitter** — resize button area vs output area, verify both shrink/grow correctly
4. **Right-click output** — context menu appears with all 6 items, each works:
   - Copy → clipboard
   - Select All → all text selected
   - Search → search bar opens
   - Clear → output cleared
   - Save to File → SaveFileDialog opens, file written
5. **Run any operation** — verify colored output:
   - Header in bright blue, bold
   - Timestamp in muted blue
   - Separator in dim color
   - ERROR lines in red, SUCCESS lines in green
   - Section headers `[DISK]` etc. in blue, bold
6. **Status bar** — "Ops: N" counter increments after each completed operation
7. **Search (Ctrl+F)** — type text, verify match highlighting works in RichTextBox
8. **Copy (Ctrl+Shift+C)** — verify plain text is copied (not RTF)
9. **Hover over buttons** — enhanced tooltips show title, description, and command hint
10. **Test all keyboard shortcuts** — Enter, Ctrl+F, Ctrl+L, Ctrl+Shift+C, Escape, F3 still work
11. **Run multiple operations** — verify output accumulates with colors, op counter increments
12. **Close window during operation** — verify clean shutdown
