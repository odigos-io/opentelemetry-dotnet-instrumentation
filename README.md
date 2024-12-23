# OpenTelemetry .NET Instrumentation - Patched Version
This repository contains patched versions of the OpenTelemetry .NET Instrumentation packages. The patches are applied to the original OpenTelemetry .NET Instrumentation packages to fix issues that are not yet resolved in the official releases.

## File Structure
The repository contains the following directories:
- `patched`: Contains the patched versions of the OpenTelemetry .NET Instrumentation packages.
- `source`: Contains the original versions of the OpenTelemetry .NET Instrumentation packages.
- `latest_version.txt`: Contains the version number of the latest patched version of the OpenTelemetry .NET Instrumentation packages. This file is used to track the latest version of the patched packages and is updated automatically when a new version is published.
- `.github/workflows`: Contains the GitHub Actions workflow file that is used to build and publish the patched versions of the OpenTelemetry .NET Instrumentation packages.

The `patched` directory structure is similar to the original OpenTelemetry .NET Instrumentation package structure. The patched versions of the OpenTelemetry .NET Instrumentation packages are stored in the `patched` directory with the same directory structure as the original packages.

## Sync 
The patched versions of the OpenTelemetry .NET Instrumentation packages are automatically synced with the official releases. The GitHub Actions workflow file in the `.github/workflows` directory is used to build and publish the patched versions of the OpenTelemetry .NET Instrumentation packages. The workflow is triggered when a new release is published in the official OpenTelemetry .NET Instrumentation repository.