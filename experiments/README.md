# Experiments

Runnable experiments behind the findings in the [repository
README](../README.md). Run them all with:

```shell
make -C .. build build-2x
./run.sh
```

Each experiment directory has its own `run.sh` and can be run on its own once
`DEV_3X_TFRC` and `DEV_2X_TFRC` point at `dev_overrides` CLI configs (the
top-level `run.sh` writes them). All of them print `PASS` or `FAIL` per check.

- `schema-validation/`: unknown resource type and unknown attribute, at
  `count = 0` and inside a `count = 0` submodule. Uses the dummy provider and
  `terraform validate`, so it needs no `terraform init`.
- `backport-gate/`: the same config validated against the 2.x and 3.x builds of
  the provider. The 2.x build accepts an unset `channel` and rejects a set one.
- `moved-matrix/`: the `moved` findings, one case each, including the implicit
  `count` conversion that needs no block. Uses `terraform_data`, so it needs no
  provider.
- `staged-opt-in/`: the staged opt-in migration for a module, including the
  destroy that happens when the root-level move is omitted and the upgrade that
  works without the module's own move block. Uses `terraform_data`, so it needs
  no provider.
