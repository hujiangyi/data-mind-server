#!/bin/sh
set -eu

/opt/datamind/bin/datamind-upgrade \
  -db /opt/datamind/data/maicong.db \
  -migrations /opt/datamind/migrations \
  -manifest /opt/datamind/migration-manifest.json \
  -config /opt/datamind/configs/config.yaml \
  -backup-dir /opt/datamind/backups \
  -version "$(cat /opt/datamind/VERSION)"

exec /opt/datamind/bin/daas-go -config /opt/datamind/configs/config.yaml
