function New-SldgStaticJson {
	<#
	.SYNOPSIS
		Generates a static JSON fallback based on column/table name heuristics.
	#>
	[CmdletBinding()]
	param (
		[string]$ColumnName,
		[string]$TableName,
		[int]$MaxLength
	)

	$name = ($ColumnName + $TableName).ToLower()

	$json = if ($name -match 'setting|config|preference|option') {
		$templates = @(
			'{"theme":"dark","language":"en","notifications":true,"pageSize":25}',
			'{"theme":"light","language":"cs","notifications":false,"pageSize":50}',
			'{"theme":"auto","language":"de","notifications":true,"pageSize":10}',
			'{"autoSave":true,"timeout":300,"retryCount":3,"debug":false}',
			'{"fontSize":14,"showToolbar":true,"compactMode":false,"region":"EU"}'
		)
		$templates | Get-Random
	}
	elseif ($name -match 'metadata|propert|attribute') {
		$templates = @(
			'{"createdBy":"system","version":"1.0","tags":["important","reviewed"]}',
			'{"source":"import","format":"csv","rows":1500,"validated":true}',
			'{"author":"admin","priority":"high","category":"finance","archived":false}',
			'{"origin":"api","clientId":"app-001","processedAt":"2025-01-15T10:30:00Z"}',
			'{"department":"IT","costCenter":"CC-100","approved":true,"level":2}'
		)
		$templates | Get-Random
	}
	elseif ($name -match 'address|location|geo') {
		$templates = @(
			'{"street":"123 Main St","city":"Prague","zip":"11000","country":"CZ"}',
			'{"street":"456 Oak Ave","city":"New York","zip":"10001","country":"US"}',
			'{"street":"789 High St","city":"London","zip":"EC1A 1BB","country":"GB"}',
			'{"lat":50.0755,"lon":14.4378,"altitude":235,"accuracy":10}',
			'{"street":"10 Rue de Rivoli","city":"Paris","zip":"75001","country":"FR"}'
		)
		$templates | Get-Random
	}
	elseif ($name -match 'payload|data|content|body|message') {
		$templates = @(
			'{"action":"update","entity":"order","id":12345,"status":"completed"}',
			'{"event":"user.login","userId":987,"ip":"10.0.0.1","timestamp":"2025-03-01T08:00:00Z"}',
			'{"type":"notification","title":"New message","body":"You have 3 unread items","read":false}',
			'{"operation":"transfer","amount":250.00,"currency":"CZK","reference":"TXN-001"}',
			'{"items":[{"sku":"A100","qty":2},{"sku":"B200","qty":1}],"total":150.50}'
		)
		$templates | Get-Random
	}
	else {
		# Generic JSON
		$templates = @(
			'{"key":"value","count":42,"active":true}',
			'{"name":"item-001","type":"standard","priority":1}',
			'{"code":"A1","label":"Default","enabled":true,"order":0}',
			'{"id":1,"value":"sample","tags":["test"]}',
			'{"status":"ok","message":"processed","timestamp":"2025-06-15T12:00:00Z"}'
		)
		$templates | Get-Random
	}

	if ($json.Length -gt $MaxLength) {
		$json = $json.Substring(0, $MaxLength)
	}

	$json
}
