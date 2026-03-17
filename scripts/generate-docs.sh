#!/bin/bash
set -e

OUTPUT_DIR=$1
VERSION=$2

if [ -z "$OUTPUT_DIR" ] || [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/generate-docs.sh <output_directory> <version_tag>"
  exit 1
fi

if [[ "$GITHUB_REPOSITORY" == "googleapis/mcp-toolbox-sdk-go" ]]; then
  BASE_PREFIX="/"
else
  REPO_NAME=$(echo "$GITHUB_REPOSITORY" | cut -d'/' -f2)
  BASE_PREFIX="/${REPO_NAME}/"
fi

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

find "$OUTPUT_DIR/$VERSION" -type f -name "*.html" -exec sed -i \
    -e "s|http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go@v0.0.0/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|/files/home/runner/work/mcp-toolbox-sdk-go/mcp-toolbox-sdk-go/github.com/googleapis/mcp-toolbox-sdk-go/|https://github.com/googleapis/mcp-toolbox-sdk-go/tree/main/|g" \
    -e "s|href=\"/\"|href=\"${BASE_PREFIX}\"|g" \
    -e "s|http://localhost:8080/|${BASE_PREFIX}${VERSION}/|g" \
    {} +

cat <<EOF > "$OUTPUT_DIR/$VERSION/collapsible.js"
document.addEventListener('DOMContentLoaded', () => {
  const directorySection = document.querySelector('.UnitDirectories');
  if (!directorySection) return;
  
  const rows = Array.from(directorySection.querySelectorAll('tr'));
});
EOF

mv "$OUTPUT_DIR/$VERSION/mcp-toolbox-sdk-go@v0.0.0.html" "$OUTPUT_DIR/$VERSION/index.html" || true

echo "Documentation generated successfully in $OUTPUT_DIR/$VERSION"
