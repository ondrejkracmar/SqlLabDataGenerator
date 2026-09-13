function Disconnect-SldgRepositorySession {
	<#
	.SYNOPSIS
		Releases a connection opened by Connect-SldgRepositorySession.
	.DESCRIPTION
		Closes the raw DbConnection and tears down the PSSqlRepository session behind it.
		Connect-PSSqlRepository hands out a non-owning handle and keeps the session as the
		module-wide ambient session, so the release path depends on who still holds it:
		when the ambient session is still ours, Disconnect-PSSqlRepository disposes it (and
		clears the ambient slot); when something else has replaced it in the meantime, the
		session object is disposed directly.
	.PARAMETER ConnectionInfo
		The SqlLabDataGenerator.Connection to release.
	#>
	[CmdletBinding()]
	param (
		[Parameter(Mandatory)]
		[SqlLabDataGenerator.Connection]$ConnectionInfo
	)

	$dbConnection = $ConnectionInfo.DbConnection
	if ($dbConnection -and $dbConnection.State -ne [System.Data.ConnectionState]::Closed) {
		try { $dbConnection.Close() }
		catch { Write-PSFMessage -Level Warning -String 'Disconnect.CloseFailed' -StringValues $ConnectionInfo.Provider, $_.Exception.Message }
	}

	# ADO.NET drivers pool connections per connection string; disposing a pooled connection
	# hands it back to the pool instead of closing it. For file engines that keeps the database
	# file locked (the schema-import probe connection PSSqlRepository opened on connect shares
	# the pool), so flush the pool for this connection string through the driver's static
	# ClearPool(connection) when it offers one (SqliteConnection, SqlConnection, NpgsqlConnection).
	if ($dbConnection) {
		try {
			$clearPool = $dbConnection.GetType().GetMethod('ClearPool', [System.Reflection.BindingFlags]'Public,Static', $null, [type[]]@($dbConnection.GetType()), $null)
			if ($clearPool) { [void]$clearPool.Invoke($null, @($dbConnection)) }
		}
		catch { Write-PSFMessage -Level Debug -String 'Disconnect.ClearPoolFailed' -StringValues $ConnectionInfo.Provider, $_.Exception.Message }
	}

	$handle = $ConnectionInfo.Repository
	if (-not $handle) { return }

	$session = $null
	try { $session = $handle.Session } catch { $session = $null }

	$ambient = $null
	if (Get-Command -Name Get-PSSqlRepositorySession -ErrorAction SilentlyContinue) {
		try { $ambient = (Get-PSSqlRepositorySession -ErrorAction SilentlyContinue).Session } catch { $ambient = $null }
	}

	try {
		if ($session -and $ambient -and [object]::ReferenceEquals($session, $ambient)) {
			Disconnect-PSSqlRepository -Confirm:$false -ErrorAction Stop
		}
		elseif ($session) {
			$session.Dispose()
		}
		Write-PSFMessage -Level Verbose -String 'Disconnect.SessionReleased' -StringValues $ConnectionInfo.Provider
	}
	catch {
		Write-PSFMessage -Level Warning -String 'Disconnect.CloseFailed' -StringValues $ConnectionInfo.Provider, $_.Exception.Message
	}
}
