#!/bin/bash
set -e

OUTPUT_DIR=$1
VERSION=$2

if [ -z "$OUTPUT_DIR" ] || [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/generate-docs.sh <output_directory> <version_tag>"
  exit 1
fi

MODULE_PATH="googleapis/mcp-toolbox-sdk-go" 
MODULE_NAME=$(basename "$MODULE_PATH")

REPO_PATH=${GITHUB_REPOSITORY:-$MODULE_PATH}
REPO_NAME=$(basename "$REPO_PATH")

DEFAULT_BRANCH=${GITHUB_REF_NAME:-"main"}
PORT=8080
PKGSITE_VERSION="v0.0.0"
WAIT_TIME=60

if [[ "$REPO_PATH" == "googleapis/mcp-toolbox-sdk-go" ]]; then
  BASE_PREFIX="/"
else
  BASE_PREFIX="/${REPO_NAME}/"
fi

go work init . ./core ./tbadk ./tbgenkit
go install golang.org/x/pkgsite/cmd/pkgsite@latest

pkgsite -http=:${PORT} &
PKGSITE_PID=$!

sleep ${WAIT_TIME}

wget -nv --recursive --page-requisites --convert-links \
     --restrict-file-names=windows --no-parent \
     -nH --adjust-extension --cut-dirs=3 \
     --reject-regex '(\?|&)(tab=versions|tab=importedby)' \
     -P "$OUTPUT_DIR/$VERSION" \
     "http://localhost:${PORT}/github.com/${MODULE_PATH}@${PKGSITE_VERSION}" || true

kill $PKGSITE_PID
rm -f go.work go.work.sum

find "$OUTPUT_DIR/$VERSION" -type f -name "*.html" -exec sed -i \
    -e "s|http://localhost:${PORT}/github.com/${MODULE_PATH}@${PKGSITE_VERSION}/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|http://localhost:${PORT}/github.com/${MODULE_PATH}/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|http://localhost:${PORT}/files/.*${MODULE_PATH}/|https://github.com/${REPO_PATH}/blob/${DEFAULT_BRANCH}/|g" \
    -e "s|/files/.*${MODULE_PATH}/|https://github.com/${REPO_PATH}/blob/${DEFAULT_BRANCH}/|g" \
    -e "s|http://localhost:${PORT}https://|https://|g" \
    -e "s|href=\"/\"|href=\"${BASE_PREFIX}\"|g" \
    -e "s|http://localhost:${PORT}/|${BASE_PREFIX}${VERSION}/|g" \
    -e "s|?tab=source|#source|g" \
    {} +

cat << EOF > inject-payload.html
<style>
  tr.is-hidden { display: table-row !important; }
  button.js-expandAll, 
  button.UnitDirectories-toggleButton,
  .UnitDirectories-toggleButton { display: none !important; }
  
  #custom-version-selector { 
    margin-left: 5px; 
    padding: 2px 8px; 
    border-radius: 4px; 
    border: 1px solid #ccc; 
    font-size: 14px; 
    background-color: #f8f9fa;
    color: #202224;
    cursor: pointer;
  }
</style>
<script>
  document.addEventListener("DOMContentLoaded", () => {
    fetch('${BASE_PREFIX}versions.json')
      .then(res => res.json())
      .then(versions => {
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
        
        const metaDetails = document.querySelectorAll('.UnitMeta-details a, .UnitMeta a');
        const v0Link = Array.from(metaDetails).find(a => a.textContent.trim() === '${PKGSITE_VERSION}');
        
        if (v0Link) {
          v0Link.style.display = 'none';
          v0Link.parentNode.insertBefore(select, v0Link.nextSibling);
        } else {
          const header = document.querySelector('.js-headerMenu, .Header-menu') || document.body;
          header.prepend(select);
        }
      }).catch(err => console.error('Failed to load version dropdown:', err));

    document.querySelectorAll('p, .Documentation-overview').forEach(el => {
      if (el.innerHTML.includes('[!NOTE]')) {
        el.innerHTML = el.innerHTML.replace('[!NOTE]', '<strong><svg style="width:16px;height:16px;vertical-align:text-bottom;margin-right:4px;" viewBox="0 0 16 16" fill="#0969da"><path d="M0 8a8 8 0 1 1 16 0A8 8 0 0 1 0 8Zm8-6.5a6.5 6.5 0 1 0 0 13 6.5 6.5 0 0 0 0-13ZM6.5 7.75A.75.75 0 0 1 7.25 7h1a.75.75 0 0 1 .75.75v2.75h.25a.75.75 0 0 1 0 1.5h-2a.75.75 0 0 1 0-1.5h.25v-2h-.25a.75.75 0 0 1-.75-.75ZM8 6a1 1 0 1 1 0-2 1 1 0 0 1 0 2Z"></path></svg>Note</strong><br>');
        el.style.borderLeft = '4px solid #0969da';
        el.style.padding = '10px 15px';
        el.style.color = '#24292f';
        el.style.backgroundColor = '#ddf4ff';
        el.style.borderRadius = '6px';
        el.style.marginTop = '15px';
        el.style.marginBottom = '15px';
      }
    });

    document.querySelectorAll('a').forEach(link => {
      let href = link.getAttribute('href');
      if (!href) return;

      if (link.href.includes('http://localhost:${PORT}https://')) {
        link.href = link.href.replace('http://localhost:${PORT}https://', 'https://');
      }

      if (link.href.includes('#source') || link.href.endsWith('.go')) {
        try {
          if (link.href.includes('github.com/${MODULE_PATH}')) {
            link.href = link.href.replace('github.com/${MODULE_PATH}', 'github.com/${REPO_PATH}');
            link.href = link.href.replace('/tree/main/', '/blob/${DEFAULT_BRANCH}/');
            link.href = link.href.replace('/tree/${DEFAULT_BRANCH}/', '/blob/${DEFAULT_BRANCH}/');
            link.target = '_blank';
            return;
          }

          const url = new URL(link.href, window.location.origin);
          const pathParts = url.pathname.split('/');
          
          const versionIndex = pathParts.findIndex(p => p === '${VERSION}');
          if (versionIndex !== -1) {
            const repoPath = pathParts.slice(versionIndex + 1).join('/');
            link.href = 'https://github.com/${REPO_PATH}/blob/${DEFAULT_BRANCH}/' + repoPath;
            link.target = '_blank';
          }
        } catch(e) {
          console.error("Failed to parse source link:", link.href, e);
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

mv "$OUTPUT_DIR/$VERSION/${MODULE_NAME}@${PKGSITE_VERSION}.html" "$OUTPUT_DIR/$VERSION/index.html" || true

echo "Documentation generated successfully in $OUTPUT_DIR/$VERSION"