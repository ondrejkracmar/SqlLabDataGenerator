function Initialize-SldgGenerationContext {
	<#
	.SYNOPSIS
		Resolves all PSFConfig values + per-run identity used by Invoke-SldgDataGeneration.
	.DESCRIPTION
		Refactor of the original inline config-loading block. Returns a hashtable so the
		caller does not have to keep ~15 separate variables in scope. Pure read-only:
		no module state is mutated and the caller remains the single owner of mutation.
	.OUTPUTS
		Hashtable with keys:
			BatchSize, Seed, StreamingThreshold, StreamingChunkSize, FkQueryLimit,
			UniqueQueryLimit, DbCommandTimeout, ThrottleLimit, CorrelationId,
			ExecutingUser, GenerationStartTime
	#>
	[CmdletBinding()]
	[OutputType([hashtable])]
	param (
		[int]$ThrottleLimitOverride
	)

	$throttle = if ($ThrottleLimitOverride -gt 0) { $ThrottleLimitOverride }
	else { Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.ThrottleLimit' }

	$user = if ($IsLinux -or $IsMacOS) {
		[System.Environment]::UserName
	} else {
		[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
	}

	@{
		BatchSize           = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.BatchSize'
		Seed                = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.Seed'
		StreamingThreshold  = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.StreamingThreshold'
		StreamingChunkSize  = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.StreamingChunkSize'
		FkQueryLimit        = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.ForeignKeyQueryLimit'
		UniqueQueryLimit    = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Generation.UniqueValueQueryLimit'
		DbCommandTimeout    = Get-PSFConfigValue -FullName 'SqlLabDataGenerator.Database.CommandTimeout'
		ThrottleLimit       = $throttle
		CorrelationId       = [guid]::NewGuid().ToString('N')
		ExecutingUser       = $user
		GenerationStartTime = Get-Date
	}
}
