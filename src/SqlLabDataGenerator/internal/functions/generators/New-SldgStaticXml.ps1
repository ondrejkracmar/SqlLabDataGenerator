function New-SldgStaticXml {
	<#
	.SYNOPSIS
		Generates a static XML fallback based on column/table name heuristics.
	#>
	[CmdletBinding()]
	param (
		[string]$ColumnName,
		[string]$TableName,
		[int]$MaxLength
	)

	$name = ($ColumnName + $TableName).ToLower()

	$xml = if ($name -match 'setting|config|preference|option') {
		$templates = @(
			'<Settings><Theme>dark</Theme><Language>en</Language><Notifications>true</Notifications></Settings>',
			'<Config><AutoSave>true</AutoSave><Timeout>300</Timeout><Debug>false</Debug></Config>',
			'<Preferences><PageSize>25</PageSize><Region>EU</Region><Format>ISO</Format></Preferences>'
		)
		$templates | Get-Random
	}
	elseif ($name -match 'address|location') {
		$templates = @(
			'<Address><Street>123 Main St</Street><City>Prague</City><Zip>11000</Zip><Country>CZ</Country></Address>',
			'<Address><Street>456 Oak Ave</Street><City>New York</City><Zip>10001</Zip><Country>US</Country></Address>',
			'<Location><Lat>50.0755</Lat><Lon>14.4378</Lon><Accuracy>10</Accuracy></Location>'
		)
		$templates | Get-Random
	}
	elseif ($name -match 'message|body|soap|request|response') {
		$templates = @(
			'<Message><Type>notification</Type><Title>Alert</Title><Body>Action required</Body><Priority>high</Priority></Message>',
			'<Request><Action>GetStatus</Action><EntityId>12345</EntityId><Timestamp>2025-03-01T08:00:00Z</Timestamp></Request>',
			'<Response><Status>OK</Status><Code>200</Code><Message>Success</Message></Response>'
		)
		$templates | Get-Random
	}
	else {
		$templates = @(
			'<Data><Item Key="name" Value="sample" /><Item Key="type" Value="default" /></Data>',
			'<Root><Element Id="1"><Name>Item A</Name><Active>true</Active></Element></Root>',
			'<Document Version="1.0"><Record Type="standard"><Value>42</Value></Record></Document>',
			'<Payload><Action>process</Action><Items><Item SKU="A100" Qty="2" /><Item SKU="B200" Qty="1" /></Items></Payload>'
		)
		$templates | Get-Random
	}

	if ($xml.Length -gt $MaxLength) {
		$xml = $xml.Substring(0, $MaxLength)
	}

	$xml
}
