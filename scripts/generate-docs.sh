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

GITHUB_BLOB="https://github.com/googleapis/mcp-toolbox-sdk-go/blob/main"

VERSION_UI="<div class='v-selector'>Version: <select id='v-drop' onchange='window.location.href=\"${BASE_PREFIX}\"+this.value+\"/\"'></select></div>"

CUSTOM_CSS="<style> \
  .UnitDirectories-table tr.is-hidden { display: table-row !important; } \
  .js-expandAll { display: none !important; } \
  .v-selector { background: #375eab; color: white; padding: 10px; text-align: right; font-family: sans-serif; } \
  #v-drop { margin-left: 10px; padding: 2px 5px; border-radius: 4px; } \
</style>"

find "$OUTPUT_DIR/$VERSION" -type f -name "*.html" -exec sed -i \
    -e "s|http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go@v0.0.0/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|http://localhost:8080/github.com/googleapis/mcp-toolbox-sdk-go/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|/files/home/runner/work/mcp-toolbox-sdk-go/mcp-toolbox-sdk-go/github.com/googleapis/mcp-toolbox-sdk-go/|${GITHUB_BLOB}/|g" \
    -e "s|href=\"/\"|href=\"${BASE_PREFIX}\"|g" \
    -e "s|http://localhost:8080/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|<header|<header>${VERSION_UI}|g" \
    -e "s|</head>|${CUSTOM_CSS}</head>|g" \
    {} +

DROPDOWN_BTN="<script> \
  fetch('${BASE_PREFIX}versions.json').then(r => r.json()).then(vs => { \
    const d = document.getElementById('v-drop'); \
    vs.forEach(v => { const o = document.createElement('option'); o.value = v; o.text = v; if(window.location.pathname.includes(v)) o.selected = true; d.add(o); }); \
  }); \
  document.querySelectorAll('a[href*=\"?tab=source\"], a[href*=\"#source\"]').forEach(l => { \
    const file = l.href.split('/').pop().split('?')[0].split('#')[0]; \
    if(file.endsWith('.go')) { l.href = '${GITHUB_BLOB}/' + file; l.target = '_blank'; } \
  }); \
</script>"

find "$OUTPUT_DIR/$VERSION" -type f -name "*.html" -exec sed -i "s|</body>|${DROPDOWN_BTN}</body>|g" {} +

mv "$OUTPUT_DIR/$VERSION/mcp-toolbox-sdk-go@v0.0.0.html" "$OUTPUT_DIR/$VERSION/index.html" || true

echo "Documentation generated successfully in $OUTPUT_DIR/$VERSION"
