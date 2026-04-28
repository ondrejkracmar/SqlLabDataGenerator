function Write-SldgAuditRecord {
	<#
	.SYNOPSIS
		Writes a JSON-lines audit record for a data generation run.
	.DESCRIPTION
		Appends a single-line JSON record to the configured audit log file.
		Validates the path to prevent directory traversal. Creates the log
		directory if it does not exist.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		$Plan,

		[Parameter(Mandatory)]
		[int]$TotalInserted,

		[Parameter(Mandatory)]
		[datetime]$StartTime,

		[Parameter(Mandatory)]
		[string]$User,

		[Parameter(Mandatory)]
		[bool]$GenerationFailed,

		[Parameter(Mandatory)]
		$TableResults,

		[string]$CorrelationId
	)

	$auditLogPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Audit.LogPath'
	if (-not $auditLogPath) { return }

	try {
		$auditLogPath = [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($auditLogPath))

		# S-6: Reject symlinks / reparse points to prevent writing to attacker-controlled targets
		if (Test-Path -LiteralPath $auditLogPath) {
			$existing = Get-Item -LiteralPath $auditLogPath -Force
			if ($existing.LinkType) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Audit.SymlinkRejected' -f $auditLogPath)
				return
			}
		}

		$auditDir = Split-Path $auditLogPath -Parent
		if ($auditDir -and -not (Test-Path $auditDir)) {
			$null = New-Item -Path $auditDir -ItemType Directory -Force
		}
		if ($auditDir -and (Test-Path -LiteralPath $auditDir)) {
			$dirItem = Get-Item -LiteralPath $auditDir -Force
			if ($dirItem.LinkType) {
				Write-PSFMessage -Level Warning -Message ($script:strings.'Audit.SymlinkRejected' -f $auditLogPath)
				return
			}
		}

		$duration = (Get-Date) - $StartTime
		$auditRecord = [PSCustomObject]@{
			Timestamp     = (Get-Date).ToString('o')
			CorrelationId = $CorrelationId
			User          = $User
			Database      = $Plan.Database
			Mode          = $Plan.Mode
			TableCount    = $Plan.TableCount
			TotalRows     = $TotalInserted
			Duration      = $duration.TotalSeconds
			Success       = -not $GenerationFailed
			Tables        = @($TableResults | ForEach-Object {
					$durMs = if ($_.PSObject.Properties.Name -contains 'DurationMs') { [int]$_.DurationMs } else { $null }
					@{
						TableName  = $_.TableName
						RowCount   = $_.RowCount
						Success    = $_.Success
						DurationMs = $durMs
					}
				})
		}
		$auditJson = $auditRecord | ConvertTo-Json -Depth 4 -Compress
		Add-Content -Path $auditLogPath -Value $auditJson -Encoding UTF8
		Write-PSFMessage -Level Verbose -Message ($script:strings.'Generation.AuditWritten' -f $auditLogPath)
	}
	catch {
		Write-PSFMessage -Level Warning -Message ($script:strings.'Generation.AuditWriteFailed' -f $_)
	}
}
