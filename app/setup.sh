#!/bin/bash
# Run this after a fresh clone to install dependencies and generate code.
set -e

echo "Installing dependencies..."
flutter pub get

echo "Installing sub-package dependencies..."
(cd packages/fitness_data && flutter pub get)
(cd packages/fitness_domain && flutter pub get)

echo "Running code generation..."
dart run build_runner build --delete-conflicting-outputs

echo "Done! Run 'flutter run' to start the app."
