# DataMind Go Docker Runtime

This directory describes the runtime layout used by the versioned Docker
distribution bundles. It does not contain the closed Go source code.

The release bundle must contain:

```text
bin/daas-go
configs/config.yaml
migrations/
Dockerfile.runtime
docker-compose.yml
.env.example
```

The runtime image executes the already compiled Linux binary. It does not
compile Go inside the user's Docker Desktop environment.

On Windows, use `install/install-go.ps1`. The script selects the Linux
container architecture, downloads the matching release bundle, asks for a
DataMind API Key, and runs the service on `127.0.0.1:3001`.
