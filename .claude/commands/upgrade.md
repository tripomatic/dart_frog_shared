---
description: Upgrade Dart/Flutter dependencies
---

1. Make sure you are on main/master and everything is commited and synced.
2. Research what packages can be updated. If nothing can be upgraded, notify the user and exit the command.

If we have packages to upgrade:

3. Create a branch for the upgrade

4. If there are any major version to upgrade:
- research the respective changelogs
- present concise summary to the user of what is new and any BC breaks to be aware of
- ask the user whether to proceed with major versions upgrade

5. If updating major or minor version, 
- research the respective changelogs
- research whether the code might be affected and correct it accordingly

6. Upgrade dependencies
- Run `flutter pub get` to install the new dependencies
- Run tests, analyzer etc. and fix any related issues.

7. Prepare a pull request and ask the user to review it
