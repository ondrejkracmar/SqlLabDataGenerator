<#
	.SYNOPSIS
		Verifies that docs/commands/<Cmdlet>.md files are in sync with each public cmdlet's
		comment-based help.

	.DESCRIPTION
		For every exported cmdlet in the SqlLabDataGenerator module the test confirms that:
			1. A markdown file with the matching name exists under docs/commands.
			2. The SYNOPSIS section in the markdown matches Get-Help -Synopsis.

		This catches stale documentation introduced when a cmdlet's help is updated
		without regenerating the docs (or vice versa).
#>
[CmdletBinding()]
param ()

Describe "Docs freshness for exported cmdlets" {
	BeforeAll {
		$script:ModuleName = 'SqlLabDataGenerator'
		$script:DocsRoot = Resolve-Path "$PSScriptRoot\..\..\..\docs\commands"
		$script:Commands = Get-Command -Module $script:ModuleName -CommandType Function
	}

	It "docs/commands directory exists" {
		Test-Path -Path $script:DocsRoot | Should -BeTrue
	}

	It "every exported cmdlet has a docs page" {
		$missing = foreach ($cmd in $script:Commands) {
			$docPath = Join-Path -Path $script:DocsRoot -ChildPath "$($cmd.Name).md"
			if (-not (Test-Path -LiteralPath $docPath)) { $cmd.Name }
		}
		$missing | Should -BeNullOrEmpty -Because "missing docs for: $($missing -join ', ')"
	}

	It "<Name> docs SYNOPSIS matches Get-Help" -ForEach @(
		Get-Command -Module 'SqlLabDataGenerator' -CommandType Function | ForEach-Object { @{ Name = $_.Name } }
	) {
		$docPath = Join-Path -Path $script:DocsRoot -ChildPath "$Name.md"
		if (-not (Test-Path -LiteralPath $docPath)) {
			Set-ItResult -Skipped -Because "doc file missing"
			return
		}

		$lines = Get-Content -LiteralPath $docPath
		$synIndex = ($lines | Select-String -Pattern '^##\s+SYNOPSIS' -SimpleMatch:$false).LineNumber
		if (-not $synIndex) {
			Set-ItResult -Skipped -Because "no SYNOPSIS section"
			return
		}

		# Take first non-empty line after the SYNOPSIS heading, stop at next heading.
		$docSynopsis = $null
		for ($i = $synIndex; $i -lt $lines.Count; $i++) {
			$line = $lines[$i].Trim()
			if ($line -match '^##\s') { break }
			if ($line) { $docSynopsis = $line; break }
		}

		$helpSynopsis = (Get-Help -Name $Name -ErrorAction SilentlyContinue).Synopsis
		if (-not $helpSynopsis) {
			Set-ItResult -Skipped -Because "Get-Help returned no synopsis"
			return
		}
		$helpSynopsis = $helpSynopsis.Trim()

		# PlatyPS sometimes echoes the syntax string when no real synopsis exists; ignore those cases.
		if ($helpSynopsis -like "$Name *" -or $helpSynopsis -eq $Name) {
			Set-ItResult -Skipped -Because "Get-Help fell back to syntax line"
			return
		}

		$docSynopsis | Should -Be $helpSynopsis -Because "docs/commands/$Name.md must mirror the cmdlet's SYNOPSIS"
	}
}
