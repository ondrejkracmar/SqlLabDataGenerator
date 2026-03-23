---
document type: module
Help Version: 1.0.0.0
HelpInfoUri: 
Locale: cs-CZ
Module Guid: 82fb705b-c1c0-4c63-b5f0-aae7e9b5f962
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: SqlLabDataGenerator Module
---

# SqlLabDataGenerator Module

## Description

AI-assisted synthetic data generation platform for SQL Server, SQLite and more. Discovers database schema, classifies columns semantically (with OpenAI, Azure OpenAI, or Ollama), generates realistic FK-consistent test data with locale support (en-US, cs-CZ, ...), and transforms output to Entra ID objects and other formats.

## SqlLabDataGenerator

### [Connect-SldgDatabase](Connect-SldgDatabase.md)

Connects to a database for schema discovery and data generation.

### [Disconnect-SldgDatabase](Disconnect-SldgDatabase.md)

Disconnects from the active database connection.

### [Export-SldgGenerationProfile](Export-SldgGenerationProfile.md)

Exports the current generation plan and rules to a JSON profile file.

### [Export-SldgTransformedData](Export-SldgTransformedData.md)

Transforms generated data into a target format (e.g., Entra ID users, Entra ID groups).

### [Get-SldgAIProvider](Get-SldgAIProvider.md)

Returns the current AI provider configuration and any per-purpose model overrides.

### [Get-SldgColumnAnalysis](Get-SldgColumnAnalysis.md)

Performs semantic analysis on database columns.

### [Get-SldgDatabaseSchema](Get-SldgDatabaseSchema.md)

Discovers and returns the complete schema of the connected database.

### [Get-SldgTransformer](Get-SldgTransformer.md)

Lists available data transformers.

### [Import-SldgGenerationProfile](Import-SldgGenerationProfile.md)

Imports generation rules from a JSON profile file.

### [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)

Executes data generation according to a generation plan.

### [New-SldgGenerationPlan](New-SldgGenerationPlan.md)

Creates a data generation plan from an analyzed schema.

### [Register-SldgLocale](Register-SldgLocale.md)

Registers a locale data pack for data generation — manually or via AI.

### [Register-SldgTransformer](Register-SldgTransformer.md)

Registers a custom data transformer.

### [Set-SldgAIProvider](Set-SldgAIProvider.md)

Configures the AI provider for semantic analysis and data generation. Supports per-purpose model overrides.

### [Set-SldgGenerationRule](Set-SldgGenerationRule.md)

Sets custom generation rules for specific columns or tables.

### [Test-SldgAIProvider](Test-SldgAIProvider.md)

Tests connectivity to the configured AI provider.

### [Test-SldgGeneratedData](Test-SldgGeneratedData.md)

Validates the quality and integrity of generated data.

### [Get-SldgPromptTemplate](Get-SldgPromptTemplate.md)

Lists or reads AI prompt templates available to the module (built-in and custom).

### [Set-SldgPromptTemplate](Set-SldgPromptTemplate.md)

Creates or updates a custom prompt template override.

### [Remove-SldgPromptTemplate](Remove-SldgPromptTemplate.md)

Removes a custom prompt template override (falls back to built-in).

