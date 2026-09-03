# Release Mirrors

DataMind supports GitHub and Gitee as release sources. The default
repositories are:

```text
GitHub: https://github.com/hujiangyi/data-mind-server
Gitee:  https://gitee.com/hujiangyi/data-mind-server
```

Both repositories should use the same `main` branch, version tags, release
asset names, and `checksums.txt` contents. A Gitee repository must be created
and its Release assets synchronized before the Gitee fallback can serve
downloads.

## Source Selection

The Go installers support:

```text
DATAMIND_RELEASE_SOURCE=auto
DATAMIND_RELEASE_SOURCE=github
DATAMIND_RELEASE_SOURCE=gitee
```

`auto` checks the Gitee and GitHub Release endpoints and uses the first
reachable source. The default order is Gitee first, then GitHub, which is
useful for networks where GitHub is slow or blocked. This is an endpoint
reachability check, not an IP geolocation decision.

Override the source URLs when using a private mirror:

```bash
export DATAMIND_GITHUB_RELEASE_BASE="https://github.com/hujiangyi/data-mind-server/releases/download"
export DATAMIND_GITEE_RELEASE_BASE="https://gitee.com/hujiangyi/data-mind-server/releases/download"
export DATAMIND_RELEASE_BASE="https://mirror.example.com/datamind/releases"
```

`DATAMIND_RELEASE_BASE` has the highest priority and skips automatic source
selection.

## Synchronization

After creating the Gitee repository, add it as a second Git remote and push
the public branch and tags:

```bash
git remote add gitee git@gitee.com:hujiangyi/data-mind-server.git
git push gitee main --tags
```

Release assets must also be uploaded to the matching Gitee Release. The
following top-level asset names are required by the installers:

```text
datamind-go-linux-amd64.tar.gz
datamind-go-linux-arm64.tar.gz
datamind-docker-linux-amd64.zip
datamind-docker-linux-arm64.zip
checksums.txt
```

Every `datamind-go-*.tar.gz` must also contain `bin/datamind-upgrade`,
`migrations/`, `migration-manifest.json`, `configs/config.yaml`, and `VERSION`.
The asset bytes must be identical between GitHub and Gitee. Do not regenerate
an archive during mirroring, because that would invalidate `checksums.txt`.

## One-Line Install

The Linux bootstrap command can choose the raw script source:

```bash
{ curl -fsSL --connect-timeout 8 https://raw.githubusercontent.com/hujiangyi/data-mind-server/main/install/install-go.sh ||
  curl -fsSL --connect-timeout 8 https://gitee.com/hujiangyi/data-mind-server/raw/main/install/install-go.sh; } |
  sudo DATAMIND_GO_VERSION=v0.1.4 bash
```

The installer then independently selects the reachable Release source.
