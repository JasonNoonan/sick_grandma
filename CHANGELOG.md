# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive HexDocs documentation
- Type specifications for all public functions
- Detailed guides for getting started and advanced usage
- Enhanced module documentation with examples
- Function grouping and organization for better documentation navigation

### Changed
- Improved documentation structure and formatting
- Enhanced error handling documentation
- Better examples in function documentation

## [0.1.0] - 2024-01-15

### Added
- Initial release of SickGrandma
- ETS table discovery functionality
- Complete table dumping to log files
- Single table dumping capability
- Automatic log directory creation
- Structured log file formatting
- Safe handling of table permissions and concurrent access
- Comprehensive error handling and reporting

### Features
- **Core API**: `dump_all_tables/0`, `dump_table/1`, `list_tables/0`
- **ETSDumper Module**: Table discovery and data extraction
- **Logger Module**: File formatting and writing operations
- **Safety Features**: Graceful handling of deleted tables and permission errors
- **Performance**: Memory-efficient processing and configurable data limits

### Documentation
- Complete README with usage examples
- Inline documentation for all public functions
- Error handling patterns and best practices

### Dependencies
- `ex_doc` for documentation generation
- Elixir ~> 1.12 compatibility

## [0.0.1] - 2024-01-01

### Added
- Initial project structure
- Basic ETS interaction capabilities
- Proof of concept implementation