# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-Tool is a PowerShell WPF GUI application designed for Windows system administration tasks. The application provides a graphical interface for remote system management operations including system information gathering, remote connections, and Windows 11 upgrades.

## Architecture

### Core Components

- **Main Application**: `tool.txt` contains the complete PowerShell application with WPF GUI
- **XAML GUI**: Embedded XAML defines the user interface with input fields, buttons, and output areas
- **Event Handlers**: Click event handlers for each functional button (ping, system info, remote sessions, etc.)
- **Remote Operations**: Uses PowerShell remoting (Invoke-Command, CIM sessions) for remote system management

### Key Functionality Areas

1. **Network Operations**: DNS resolution, ping tests, connectivity validation
2. **System Information**: Hardware details, OS info, uptime, installed software
3. **Remote Management**: PowerShell sessions, GPUpdate, Event Viewer access
4. **Remote Tools**: MSRA (Remote Assistance), RDC (Remote Desktop)
5. **Windows 11 Upgrade**: Automated upgrade process with compatibility checking

## Development Workflow

### Running the Application
```powershell
# Execute the main script
.\tool.txt
# or
powershell.exe -ExecutionPolicy Bypass -File "tool.txt"
```

### Testing
- Test with local machine first: Use local hostname/IP in input field
- Test remote connectivity: Verify WinRM is enabled on target machines
- Validate credentials: Ensure proper domain/local admin rights for remote operations

## Code Conventions

### PowerShell Standards
- Functions use Verb-Noun naming convention
- Error handling with try-catch blocks and -ErrorAction Stop
- CIM/WMI queries preferred over legacy WMI
- Proper disposal of CIM sessions and runspaces

### GUI Patterns
- Controls retrieved using `$Window.FindName("controlName")`
- Event handlers added with `$control.Add_Event({})`
- UI updates wrapped in `$Window.Dispatcher.Invoke()` for thread safety
- Progress bar visibility toggled for long operations

### Remote Operations
- Always validate hostname/IP input before remote calls
- Use `-ComputerName` parameter for remote operations
- Credential prompts when required for authenticated access
- Proper error handling for network connectivity issues

## Security Considerations

This codebase contains several security concerns that should be addressed:

1. **Input Validation**: Hostname/IP inputs need proper sanitization
2. **Credential Management**: Credentials should use Windows Credential Manager
3. **Remote Execution**: User inputs are directly executed in remote commands
4. **Web Downloads**: Windows 11 upgrade downloads executables without verification

## Common Operations

### Adding New Remote Functions
1. Create button in XAML section
2. Retrieve button control: `$btnNewFunction = $Window.FindName("btnNewFunction")`
3. Add click event handler with validation and error handling
4. Use `Invoke-Command` for remote execution
5. Update terminal output box with results

### Modifying System Information Queries
- Extend the existing CIM queries in the system info handler
- Use `Get-CimInstance` with appropriate class names
- Format output using StringBuilder or array joining
- Handle datetime conversions properly for uptime calculations

### Adding Progress Tracking
- Show progress bar: `$progressBar.Visibility = [System.Windows.Visibility]::Visible`
- Update progress: `$progressBar.Value = $percentComplete`
- Hide when complete: `$progressBar.Visibility = [System.Windows.Visibility]::Hidden`

## File Structure

- `tool.txt` - Main PowerShell application
- `README.md` - Basic project description
- `InitialWrite\Up.md` - Security analysis and code review
- `Multi-Tool.code-workspace` - VS Code workspace configuration

The application is entirely self-contained in the single `tool.txt` file with no external dependencies beyond standard PowerShell modules and WPF assemblies.