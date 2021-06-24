## Salt States: Salt Formula

### Requirements

This formula requires the following additional formulas:

```yaml
  dependencies:
    - name: letsencrypt
      repo: git
      source: https://gitlab.dylanwilson.dev/infrastructure/salt-formulas/letsencrypt-formula.git
    - name: munin
      repo: git
      source: https://gitlab.dylanwilson.dev/infrastructure/salt-formulas/munin-formula.git
    - name: vault
      repo: git
      source: https://gitlab.dylanwilson.dev/infrastructure/salt-formulas/vault-formula.git
```
