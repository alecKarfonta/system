#!/bin/bash

# Default values
REQUIREMENTS_FILE="requirements.txt"
DESTINATION_DIR="./packages"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--requirements)
            REQUIREMENTS_FILE="$2"
            shift 2
            ;;
        -d|--destination)
            DESTINATION_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if requirements file exists
if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo "Error: Requirements file '$REQUIREMENTS_FILE' not found"
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$DESTINATION_DIR"

# Download packages
echo "Downloading packages from $REQUIREMENTS_FILE to $DESTINATION_DIR"
python -m pip download -r "$REQUIREMENTS_FILE" -d "$DESTINATION_DIR"

echo "Download complete!"





