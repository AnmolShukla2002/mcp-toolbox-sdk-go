#!/bin/bash
set -e

OUTPUT_DIR=$1
VERSION=$2

if [ -z "$OUTPUT_DIR" ] || [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/generate-docs.sh <output_directory> <version_tag>"
  exit 1
fi

echo "Generating documentation for version $VERSION..."

go work init . ./core ./tbadk ./tbgenkit

go install golang.org/x/pkgsite/cmd/pkgsite@latest

pkgsite -http=:8080 &
PKGSITE_PID=$!

sleep 15

wget -nv --recursive --page-requisites --convert-links \
     --restrict-file-names=windows --no-parent \
     -nH --adjust-extension --cut-dirs=3 \
     --reject-regex '(\?|&)(tab=versions|tab=importedby)' \
     -P "$OUTPUT_DIR/$VERSION" \
     "http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go@v0.0.0" || true

kill $PKGSITE_PID
rm go.work go.work.sum

echo "Sanitizing links in generated HTML..."
find "$OUTPUT_DIR/$VERSION" -type f -name "*.html" -exec sed -i \
    -e "s|http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go@v0.0.0/||g" \
    -e "s|http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go/||g" \
    -e "s|http://localhost:8080/|/|g" \
    {} +

mv "$OUTPUT_DIR/$VERSION/mcp-toolbox-sdk-go@v0.0.0.html" "$OUTPUT_DIR/$VERSION/index.html" || true

if [ -f "$OUTPUT_DIR/$VERSION/index.html" ]; then
  echo "Documentation generated successfully in $OUTPUT_DIR/$VERSION"
else
  echo "Error: index.html was not created. Check logs for wget failures."
  exit 1
fi
