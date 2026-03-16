# ADR-001: PSFramework as Module Foundation

## Status
Accepted

## Date
2025-01-01

## Context
SqlLabDataGenerator needs a robust foundation for configuration management, logging, message localization, and parameter validation. Building these from scratch would be significant effort and error-prone.

## Decision
Use PSFramework (1.13.426+) as the foundational framework, leveraging:
- **PSFConfig** for hierarchical configuration with persistence
- **Write-PSFMessage / Stop-PSFFunction** for structured logging and error handling
- **String localization** via `en-us/strings.psd1`
- **Tab completion** and validation attributes
- **Module state management** patterns

All module state is centralized in `$script:SldgState` hashtable, initialized in `configuration.ps1`.

## Consequences
- **Positive**: Consistent logging, configuration, and error handling across all functions. Built-in support for `-EnableException` pattern. Automatic message localization support.
- **Positive**: Reduced boilerplate — configuration persistence, tab completion, and validation come "for free."
- **Negative**: Hard dependency on PSFramework — module cannot function without it.
- **Negative**: PSFramework's config lookup has performance overhead in hot paths (mitigated by caching critical values).
