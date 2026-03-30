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
		$TableResults
	)

	$auditLogPath = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Audit.LogPath'
	if (-not $auditLogPath) { return }

	try {
		$auditLogPath = [System.IO.Path]::GetFullPath($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($auditLogPath))
		$auditDir = Split-Path $auditLogPath -Parent
		if ($auditDir -and -not (Test-Path $auditDir)) {
			$null = New-Item -Path $auditDir -ItemType Directory -Force
		}

		$duration = (Get-Date) - $StartTime
		$auditRecord = [PSCustomObject]@{
			Timestamp  = (Get-Date).ToString('o')
			User       = $User
			Database   = $Plan.Database
			Mode       = $Plan.Mode
			TableCount = $Plan.TableCount
			TotalRows  = $TotalInserted
			Duration   = $duration.TotalSeconds
			Success    = -not $GenerationFailed
			Tables     = @($TableResults | ForEach-Object { @{ TableName = $_.TableName; RowCount = $_.RowCount; Success = $_.Success } })
		}
		$auditJson = $auditRecord | ConvertTo-Json -Depth 4 -Compress
		Add-Content -Path $auditLogPath -Value $auditJson -Encoding UTF8
		Write-PSFMessage -Level Verbose -String 'Generation.AuditWritten' -StringValues $auditLogPath
	}
	catch {
		Write-PSFMessage -Level Warning -String 'Generation.AuditWriteFailed' -StringValues $_
	}
}
