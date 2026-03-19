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
    -e "s|?tab=source|#source|g" \
    {} +

cat << EOF > inject-payload.html
<style>
  tr.is-hidden { display: table-row !important; }
  button.js-expandAll, 
  button.UnitDirectories-toggleButton,
  .UnitDirectories-toggleButton { display: none !important; }
  
  #custom-version-selector { margin-left: 15px; padding: 5px; border-radius: 4px; border: 1px solid #ccc; font-size: 14px; }
</style>
<script>
  document.addEventListener("DOMContentLoaded", () => {
    fetch('${BASE_PREFIX}versions.json')
      .then(res => res.json())
      .then(versions => {
        const header = document.querySelector('.js-headerMenu, .Header-menu') || document.body;
        const select = document.createElement('select');
        select.id = 'custom-version-selector';
        
        versions.forEach(v => {
          const opt = document.createElement('option');
          opt.value = v;
          opt.textContent = v;
          if (window.location.pathname.includes('/' + v + '/')) opt.selected = true;
          select.appendChild(opt);
        });
        
        select.addEventListener('change', (e) => {
          const targetVersion = e.target.value;
          const currentPath = window.location.pathname;
          const newPath = currentPath.replace(/\/(v[^\/]+|dev-[^\/]+)\//, '/' + targetVersion + '/');
          window.location.href = newPath;
        });
        
        header.prepend(select);
      }).catch(err => console.error('Failed to load version dropdown:', err));

    document.querySelectorAll('a').forEach(link => {
      const href = link.getAttribute('href');
      if (href && (href.includes('#source') || href.endsWith('.go'))) {
        try {
          const url = new URL(link.href, window.location.origin);
          const pathParts = url.pathname.split('/');
          
          const versionIndex = pathParts.findIndex(p => p === '${VERSION}');
          if (versionIndex !== -1) {
            const repoPath = pathParts.slice(versionIndex + 1).join('/');
            link.href = 'https://github.com/googleapis/mcp-toolbox-sdk-go/blob/main/' + repoPath;
            link.target = '_blank';
          }
        } catch(e) {
          console.error("Failed to parse source link:", link.href);
        }
      }
    });
  });
</script>
</body>
EOF

export INJECT_CONTENT=$(cat inject-payload.html)
find "$OUTPUT_DIR/$VERSION" -type f -name "*.html" -exec perl -0777 -pi -e 's|</body>|$ENV{INJECT_CONTENT}|g' {} +
rm inject-payload.html

mv "$OUTPUT_DIR/$VERSION/mcp-toolbox-sdk-go@v0.0.0.html" "$OUTPUT_DIR/$VERSION/index.html" || true

echo "Documentation generated successfully in $OUTPUT_DIR/$VERSION"
