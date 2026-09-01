# Contributing

## Language

Public user documentation must be available in English and Simplified
Chinese. Keep the two versions behaviorally equivalent.

## Commit messages

Use English commit messages with a conventional prefix:

```text
feat: add data source management
fix: preserve cloud credential compatibility
docs: update the bilingual installation guide
test: cover data-scope enforcement
```

## Pull requests

- Explain the behavior change and security impact.
- Add or update tests for data access and permission changes.
- Do not include credentials, private architecture documents, customer data,
  provider keys, or generated release archives.
- For installer changes, validate shell syntax and review both Linux and
  Windows execution paths.
- For documentation changes, check both language versions and every relative
  link.
