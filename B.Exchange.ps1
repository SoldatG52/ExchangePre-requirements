# Global Variable and Function Definitions ##########################################
$DownloadFolder = "C:\Software"
$Error.clear()
Import-Module BitsTransfer -erroraction STOP
Clear-Host

Function FileDownload {
    Param ($sourcefile)
    [string] $DownloadFile = $sourcefile.Substring($sourcefile.LastIndexOf("/") + 1)
    Try {
        Start-BitsTransfer -Source "$SourceFile" -Destination "$DownloadFolder\$DownloadFile" -ErrorAction STOP
    } Catch {
        Write-host "Failed to download file." -ForegroundColor Red
    }
}

Function ConfigurePageFile {
    $Stop = $False
    $WMIQuery = $False

    # Remove Existing PageFile
    try {
        Set-CimInstance -Query “Select * from win32_computersystem” -Property @{automaticmanagedpagefile=”False”}
    } catch {
        Write-Host "Cannot remove the existing pagefile." -ForegroundColor Red
        $WMIQuery = $True
    }
    # Remove PageFile with WMI if CIM fails
    If ($WMIQuery) {
		Try {
			$CurrentPageFile = Get-WmiObject -Class Win32_PageFileSetting
            $name = $CurrentPageFile.Name
            $CurrentPageFile.delete()
		} catch {
			Write-Host "The server $server cannot be reached via CIM or WMI." -ForegroundColor Red
			$Stop = $True
		}
    }

    Try {
        $RamInMb = (Get-CIMInstance -computername $name -Classname win32_physicalmemory -ErrorAction Stop | measure-object -property capacity -sum).sum/1MB
        $ExchangeRAM = $RAMinMb * 0.25
    } catch {
        Write-Host "Cannot acquire the amount of RAM in the server." -ForegroundColor Red
        $stop = $true
    }

    # Get RAM and set ideal PageFileSize - WMI Method
    If ($WMIQuery) {
		Try {
            $RamInMb = (Get-wmiobject -computername $server -Classname win32_physicalmemory -ErrorAction Stop | measure-object -property capacity -sum).sum/1MB
            $ExchangeRAM = $RAMinMb * 0.25
		} catch {
			Write-Host "Cannot acquire the amount of RAM in the server with CIM or WMI queries." -ForegroundColor Red
			$stop = $true
		}
    }

    # For possible addition at a later time
    # If ($ExchangeRAM -lt 32768) {
    #      $ExchangeRAM = 32768
    # }

    # Reset WMIQuery
    $WMIQuery = $False

    If ($Stop -Ne $True) {
        # Configure PageFile
        try {
            Set-CimInstance -Query “Select * from win32_PageFileSetting” -Property @{InitialSize=$ExchangeRAM;MaximumSize=$ExchangeRAM}
        } catch {
            Write-Host "Cannot configure the PageFile correctly." -ForegroundColor Red
        }
        If ($WMIQuery) {
		    Try {
                Set-WMIInstance -computername $server -class win32_PageFileSetting -arguments @{name ="$name";InitialSize=$ExchangeRAM;MaximumSize=$ExchangeRAM}
		    } catch {
			    Write-Host "Cannot configure the PageFile correctly." -ForegroundColor Red
                $stop = $true
		    }
        }
        if ($stop -ne $true) {
            $pagefile = Get-CimInstance win32_PageFileSetting -Property * | select-object Name,initialsize,maximumsize
            $name = $pagefile.name;$max = $pagefile.maximumsize;$min = $pagefile.initialsize
            Write-Host " "
            Write-Host "This server's pagefile, located at " -ForegroundColor white -NoNewline
            Write-Host "$name" -ForegroundColor green -NoNewline
            Write-Host ", is now configured for an initial size of " -ForegroundColor white -NoNewline
            Write-Host "$min MB " -ForegroundColor green -NoNewline
            Write-Host "and a maximum size of " -ForegroundColor white -NoNewline
            Write-Host "$max MB." -ForegroundColor Green
            Write-Host " "
        } else {
            Write-Host "The PageFile cannot be configured at this time." -ForegroundColor Red
        }
    } else {
        Write-Host "The PageFile cannot be configured at this time." -ForegroundColor Red
    }
}

Function TLS101112 {
    $LogDestination = $Path+'\TLSLog.txt'
    # TLS Disable 1.0 / TLS 1.1 / Enable TLS 1.2 (default)
    # Examples of setting an existing value creating a new value
    # $KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\$DeviceNumber"
    # Set-ItemProperty -Path $KeyPath -Name "PnPCapabilities" -Value 24 | Out-Null
    # New-ItemProperty -Path $TCPPath -Name "KeepAliveTime" -Value 1800000 -Force -PropertyType DWord
    # $TCPPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

  # TLS 1.0 - Server
    #Variables
    $TLS10ServerPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS10ServerPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0'
    $TLS10ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
    $TLS10ServerEnabled = (Get-ItemProperty -Path $TLS10ServerPath -ErrorAction SilentlyContinue).Enabled
    $TLS10ServerDisabledByDefault = (Get-ItemProperty -Path $TLS10ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS10ServerPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ServerPathBase -Name 'TLS 1.0' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 base reg key created." | Out-File  $LogDestination -Append
            $TLS10BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10BasePath = $False
        }
    } else {
        $TLS10BasePath = $True
    }
    If ((Get-Item -Path $TLS10ServerPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ServerPathShort -Name 'Server' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 Server base reg key created." | Out-File  $LogDestination -Append
            $TLS10ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 Server base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10ShortPath = $False
        }
    } Else {
        $TLS10ShortPath = $True
    }
    # Add Entries
    If (($TLS10BasePath) -and ($TLS10ShortPath)) {
        If ($Null -eq $TLS10ServerEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS10ServerPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Server." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ServerEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS10ServerPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.0 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Server." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS10ServerEnabled -eq '0') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 Server is disabled." | Out-File  $LogDestination -Append
        }
        If ($Null -eq $TLS10ServerDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS10ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Server is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.0 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS10ServerDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS10ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.0 Server is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ServerDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : Success - TLS 1.0 Server is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }
    # TLS 1.0 - Client
    #Variables
    $TLS10ClientPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS10ClientPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0'
    $TLS10ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'
    $TLS10ClientEnabled = (Get-ItemProperty -Path $TLS10ClientPath -ErrorAction SilentlyContinue).Enabled
    $TLS10ClientDisabledByDefault = (Get-ItemProperty -Path $TLS10ClientPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS10ClientPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ClientPathBase -Name 'TLS 1.0' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 base reg key created." | Out-File  $LogDestination -Append
            $TLS10BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10BasePath = $False
        }
    } else {
        $TLS10BasePath = $True
    }
    If ((Get-Item -Path $TLS10ClientPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS10ClientPathShort -Name 'Client' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.0 Client base reg key created." | Out-File  $LogDestination -Append
            $TLS10ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.0 Client base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS10ShortPath = $False
        }
    } Else {
        $TLS10ShortPath = $True
    }
    # Add Entries
    If (($TLS10BasePath) -and ($TLS10ShortPath)) {
        If ($Null -eq $TLS10ClientEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS10ClientPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Client." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ClientEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS10ClientPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is now disabled." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date ; $Output = "$Date : FAILED - Could not disable TLS 1.0 Client." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS10ClientEnabled -eq '0') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.0 Client is disabled." | Out-File $LogDestination -Append
        }
        If ($Null -eq $TLS10ClientDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS10ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.0 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS10ClientDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS10ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.0 Client is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS10BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.0 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS10ClientDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : Success - TLS 1.0 Client is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.1 - Server
    #Variables
    $TLS11ServerPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS11ServerPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1'
    $TLS11ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
    $TLS11ServerEnabled = (Get-ItemProperty -Path $TLS11ServerPath -ErrorAction SilentlyContinue).Enabled
    $TLS11ServerDisabledByDefault = (Get-ItemProperty -Path $TLS11ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS11ServerPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ServerPathBase -Name 'TLS 1.1' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 base reg key created." | Out-File  $LogDestination -Append
            $TLS11BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11BasePath = $False
        }
    } else {
        $TLS11BasePath = $True
    }
    If ((Get-Item -Path $TLS11ServerPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ServerPathShort -Name 'Server' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Server base reg key created." | Out-File  $LogDestination -Append
            $TLS11ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 Server base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11ShortPath = $False
        }
    } Else {
        $TLS11ShortPath = $True
    }
    # Add Entries
    If (($TLS11BasePath) -and ($TLS11ShortPath)) {
        If ($Null -eq $TLS11ServerEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS11ServerPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Server." | Out-File  $LogDestination -Append
                $Output= "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ServerEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS11ServerPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Server is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Server." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } ElseIf ($TLS11ServerEnabled -eq '0') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Server disabled." | Out-File $LogDestination -Append
        }
        If ($Null -eq $TLS11ServerDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS11ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Server is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.1 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS11ServerDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS11ServerPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date 
                $Output = "$Date : SUCCESS - TLS 1.1 Server is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Server by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ServerDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Server is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.1 - Client
    #Variables
    $TLS11ClientPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS11ClientPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1'
    $TLS11ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
    $TLS11ClientEnabled = (Get-ItemProperty -Path $TLS11ClientPath -ErrorAction SilentlyContinue).Enabled
    $TLS11ClientDisabledByDefault = (Get-ItemProperty -Path $TLS11ClientPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS11ClientPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ClientPathBase -Name 'TLS 1.1' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 base reg key created." | Out-File  $LogDestination -Append
            $TLS11BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11BasePath = $False
        }
    } else {
        $TLS11BasePath = $True
    }
    If ((Get-Item -Path $TLS11ClientPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS11ClientPathShort -Name 'Client' -Force -ErrorAction STOP
            $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.1 Client base reg key created." | Out-File  $LogDestination -Append
            $TLS11ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.1 Client base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS11ShortPath = $False
        }
    } Else {
        $TLS11ShortPath = $True
    }
    # Add Entries
    If (($TLS11BasePath) -and ($TLS11ShortPath)) {
        If ($Null -eq $TLS11ClientEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS11ClientPath -Name 'Enabled' -Value 0 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ClientEnabled -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS11ClientPath -Name "Enabled" -Value 0 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 is now disabled." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS11ClientEnabled -eq '0') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Client is disabled." | Out-File  $LogDestination -Appen
        }
        If ($Null -eq $TLS11ClientDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS11ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Client is now disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disabled TLS 1.1 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        }  ElseIf ($TLS11ClientDisabledByDefault -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS11ClientPath -Name "DisabledByDefault" -Value 1 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.1 Client is Disabled by Default." | Out-File  $LogDestination -Append
                $TLS11BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not disable TLS 1.1 Client by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS11ClientDisabledByDefault -eq '1') {
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.1 Client is Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.2 - Server
    #Variables
    $TLS12ServerPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS12ServerPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
    $TLS12ServerPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
    $TLS12ServerEnabled = (Get-ItemProperty -Path $TLS12ServerPath -ErrorAction SilentlyContinue).Enabled
    $TLS12ServerDisabledByDefault = (Get-ItemProperty -Path $TLS12ServerPath -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS12ServerPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ServerPathBase -Name 'TLS 1.2' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 base reg key created." | Out-File  $LogDestination -Append
            $TLS12BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12BasePath = $False
        }
    } Else {
        $TLS12BasePath = $True
    }
    If ((Get-Item -Path $TLS12ServerPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ServerPathShort -Name 'Server' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 Server base reg key created." | Out-File  $LogDestination -Append
            $TLS12ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 Server base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12ShortPath = $False
        }
    } Else {
        $TLS12ShortPath = $True
    }
    # Add Entries
    If (($TLS12BasePath) -and ($TLS12ShortPath)) {
        If ($Null -eq $TLS12ServerEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS12ServerPath -Name 'Enabled' -Value 1 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ServerEnabled -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS12ServerPath -Name "Enabled" -Value 1 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Appen
            } 
        } Elseif ($TLS12ServerEnabled -eq '1') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Server is enabled." | Out-File  $LogDestination -Append
        }
        If ($Null -eq $TLS12ServerDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS12ServerPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2 by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ServerDisabledByDefault -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS12ServerPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date ; $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2 by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } Else {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Server is not Disabled by Default." | Out-File  $LogDestination -Append
        }
    }

    # TLS 1.2 - Client
    #Variables
    $TLS12ClientPathBase = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'
    $TLS12ClientPathShort = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
    $TLS12ClientPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
    $TLS12ClientEnabled = (Get-ItemProperty -Path $TLS12ClientPath -ErrorAction SilentlyContinue).Enabled
    $TLS12ClientDisabledByDefault = (Get-ItemProperty -Path $TLS12ClientPath  -ErrorAction SilentlyContinue).DisabledByDefault
    #Create Keys
    If ((Get-Item -Path $TLS12ClientPathShort -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ClientPathBase -Name 'TLS 1.2' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 base reg key created." | Out-File  $LogDestination -Append
            $TLS12BasePath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12BasePath = $False
        }
    } else {
        $TLS12BasePath = $True
    }
    If ((Get-Item -Path $TLS12ClientPath -ErrorAction SilentlyContinue) -eq $Null) {
        Try {
            New-Item -Path $TLS12ClientPathShort -Name 'Client' -Force -ErrorAction STOP
            $Date = Get-Date
            $Output = "$Date : SUCCESS - TLS 1.2 Client base reg key created." | Out-File  $LogDestination -Append
            $TLS12ShortPath = $True
        } Catch {
            $Date = Get-Date
            $Output = "$Date : FAILED - Could not create TLS 1.2 Client base reg key." | Out-File  $LogDestination -Append
            $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            $TLS12ShortPath = $False
        }
    } Else {
        $TLS12ShortPath = $True
    }
    # Add Entries
    If (($TLS12BasePath) -and ($TLS12ShortPath)) {
        If ($Null -eq $TLS12ClientEnabled){
            # Set value in the path:
            Try {
                New-ItemProperty -Path $TLS12ClientPath -Name 'Enabled' -Value 1 -Force -PropertyType DWord -ErrorAction STOP
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ClientEnabled -eq '0') {
            Try {
                Set-ItemProperty -Path $TLS12ClientPath -Name "Enabled" -Value 1 -ErrorAction STOP| Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is now enabled." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            } 
        } Elseif ($TLS12ClientEnabled -eq '1') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Client is enabled." | Out-File  $LogDestination -Append
        }
        If ($Null -eq $TLS12ClientDisabledByDefault) {
            Try {
                New-ItemProperty -Path $TLS12ClientPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - Could not enabled TLS 1.2 by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ClientDisabledByDefault -eq '1') {
            Try {
                Set-ItemProperty -Path $TLS12ClientPath -Name "DisabledByDefault" -Value 0 -ErrorAction STOP | Out-Null
                $Date = Get-Date
                $Output = "$Date : SUCCESS - TLS 1.2 is not Disabled by Default." | Out-File  $LogDestination -Append
                $TLS12BasePath = $True
            } Catch {
                $Date = Get-Date
                $Output = "$Date : FAILED - TLS 1.2 is Disabled by Default." | Out-File  $LogDestination -Append
                $Output = "$Date : Error message - $_.Exception.Message" | Out-File $LogDestination -Append
            }
        } ElseIf ($TLS12ClientDisabledByDefault -eq '0') {
            $Date = Get-Date 
            $Output = "$Date : SUCCESS - TLS 1.2 Client is not Disabled by Default." | Out-File  $LogDestination -Append
        }
    }
}

# Start #############################################################################
Write-Host Start
mkdir $DownloadFolder | Out-Null
Import-Module BitsTransfer | Out-Null
Clear-Host
# ISO Exchange ######################################################################
Write-Host ISO exchange
Set-Location $DownloadFolder
FileDownload "https://download.microsoft.com/download/7/5/f/75f4d77e-002c-419c-a03a-948e8eb019f2/ExchangeServer2019-x64-CU13.ISO"
Mount-DiskImage "$DownloadFolder\ExchangeServer2019-x64-CU13.ISO"
Clear-Host
# All windows-feature ###############################################################
Write-Host ALL Windows-feature
Install-WindowsFeature Server-Media-Foundation, NET-Framework-45-Core, NET-Framework-45-ASPNET, NET-WCF-HTTP-Activation45, NET-WCF-Pipe-Activation45, NET-WCF-TCP-Activation45, NET-WCF-TCP-PortSharing45, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-PowerShell, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Metabase, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, RSAT-ADDS
Clear-Host
#.Net 4.8 ###########################################################################
Write-Host .net 4.8
Set-Location $DownloadFolder
FileDownload "https://download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe"
.\ndp48-x86-x64-allos-enu.exe /q /norestart | Out-Null
Clear-Host
# UCMA ##############################################################################
Write-Host UCMA
Set-Location "E:\UCMARedist\" 
.\Setup.exe -q /norestart | Out-Null
Clear-Host
# vcRedist 2013 #####################################################################
Write-Host vcRedist 2013
Set-Location $DownloadFolder
FileDownload "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
.\vcRedist_x64.exe /q /norestart | Out-Null
Clear-Host
# High perf #########################################################################
Write-Host High perf
$HighPerf = powercfg -l | %{if($_.contains("High performance")) {$_.split()[3]}}
$CurrPlan = $(powercfg -getactivescheme).split()[3]
powercfg -setactive $HighPerf
Clear-Host
# High perf 2.0 #####################################################################
Write-Host High perf 2.0
$NICs = Get-WmiObject -Class Win32_NetworkAdapter|Where-Object{$_.PNPDeviceID -notlike "ROOT\*" -and $_.Manufacturer -ne "Microsoft" -and $_.ConfigManagerErrorCode -eq 0 -and $_.ConfigManagerErrorCode -ne 22} 
Foreach($NIC in $NICs) {
    $NICName = $NIC.Name
    $DeviceID = $NIC.DeviceID
    If([Int32]$DeviceID -lt 10) {
        $DeviceNumber = "000"+$DeviceID 
    } Else {
        $DeviceNumber = "00"+$DeviceID
    }
    $KeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\$DeviceNumber"
  
    If(Test-Path -Path $KeyPath) {
        $PnPCapabilities = (Get-ItemProperty -Path $KeyPath).PnPCapabilities
        # Check to see if the value is 24 and if not, set it to 24
        If($PnPCapabilities -ne 24){Set-ItemProperty -Path $KeyPath -Name "PnPCapabilities" -Value 24 | Out-Null}
        # Verify the value is now set to or was set to 24
        If($PnPCapabilities -eq 24) {Write-Host " ";Write-Host "Power Management has already been " -NoNewline;Write-Host "disabled" -ForegroundColor Green;Write-Host " "}
    } 
}
Clear-Host
# TCP alive #########################################################################
Write-Host TCP alive
New-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters -Name "KeepAliveTime" -Value 1800000 -Force -PropertyType DWord
Clear-Host
# IIS rewrite module ################################################################
Write-Host IIS rewrite module
Set-Location $DownloadFolder
FileDownload "https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi"
Start-Process 'rewrite_amd64_en-US.msi' -ArgumentList /quiet -Wait
Clear-Host
# ConfigurePageFile #################################################################
Write-Host ConfigurePageFile
ConfigurePageFile
Clear-Host
# TLS 1.0 1.1 1.2 ###################################################################
Write-Host TLS 1.0 1.1 1.2
TLS101112
Clear-Host
# Install Exchange ##################################################################
Write-Host Install Exchange
cd E:\
.\Setup.Exe /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /ps
.\Setup.Exe /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /preparead /OrganizationName:exchange
.\Setup.exe /m:install /IAcceptExchangeServerLicenseTerms_DiagnosticDataOFF /roles:m /InstallWindowsComponents
Clear-Host
# End ###############################################################################
shutdown /r