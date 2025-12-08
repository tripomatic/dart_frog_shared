---
description: Bump package version, update changelog, verify metadata, and create a GitHub release
---

## Preparation

- Ensure you're on the main branch and it's up to date
- Check for any uncommitted changes and refuse to continue if found
- Run all tests to ensure everything is working
- Analyze code to ensure no issues

## Version Bump

- Determine the version bump type based on newly merged pull requests since the latest release
- Read current version from pubspec.yaml
- Calculate new version based on semantic versioning rules
- Update version in pubspec.yaml

## Changelog Update

- Generate changelog based on recent commits since last release
- Update CHANGELOG.md with the new version and changes
- Ensure proper formatting following the existing pattern

## Metadata Verification and Updates

- Verify pubspec.yaml metadata:
  - description is accurate
  - homepage, repository, and issue_tracker URLs are correct
  - topics are relevant
  - environment constraints are appropriate
  - dependencies are up to date
  
- Verify and update README.md:
  - Check if version badge needs updating (if present)
  - Ensure installation instructions reference the new version
  - Verify all links are working
  - Update any version-specific documentation

- Verify LICENSE file exists and is valid

- Check example/pubspec.yaml if it exists and update dependency version

## Pre-release Checks

- Run `flutter analyze` to ensure no issues
- Run `flutter test` to ensure all tests pass
- Generate a summary of all changes

## Commit and Tag

- Stage all modified files
- Commit with message: "Release v{version}"
- Create an annotated git tag: "v{version}"
- Push commit and tag to origin

## GitHub Release

- Create a GitHub release using `gh release create`:
  - Use the new version tag
  - Set release title as "v{version}"
  - Use the changelog entry as release notes
  - Attach any relevant assets if needed

## Post-release

- Confirm the release was created successfully on GitHub
