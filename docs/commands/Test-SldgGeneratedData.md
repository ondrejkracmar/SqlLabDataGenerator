---
document type: cmdlet
external help file: SqlLabDataGenerator-Help.xml
HelpUri: ''
Locale: cs-CZ
Module Name: SqlLabDataGenerator
ms.date: 03.16.2026
PlatyPS schema version: 2024-05-01
title: Test-SldgGeneratedData
---

# Test-SldgGeneratedData

## SYNOPSIS

Validates the quality and integrity of generated data.

## SYNTAX

### __AllParameterSets

```
Test-SldgGeneratedData [-Schema] <Object> [[-ConnectionInfo] <Object>] [<CommonParameters>]
```

## DESCRIPTION

Runs a suite of validation checks against the generated data in the target database:
- Foreign key referential integrity
- Primary key and unique constraint uniqueness
- NOT NULL constraint compliance
- Row count verification

## EXAMPLES

### EXAMPLE 1

$results = Test-SldgGeneratedData -Schema $schema

Validates all constraints in the connected database.

### EXAMPLE 2

$results = Test-SldgGeneratedData -Schema $schema | Where-Object { -not $_.Passed }

Shows only failed validations.

## PARAMETERS

### -ConnectionInfo

The database connection.
If not specified, uses the active connection.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Schema

The schema model to validate against.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS

- [Invoke-SldgDataGeneration](Invoke-SldgDataGeneration.md)
- [New-SldgGenerationPlan](New-SldgGenerationPlan.md)