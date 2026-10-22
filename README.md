# Terraform provider-version compatibility experiments

A throwaway Terraform provider and a set of runnable experiments that pin down
how Terraform behaves when a module has to support more than one major version
of a provider.

The provider is derived from the [HashiCups provider
tutorial](https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework).
It is not published to the registry and is not for real use. It exists so the
behavior below can be reproduced without a cloud account or a live API.

## The problem

Terraform validates every resource and attribute a module declares against the
provider the caller has installed, before it evaluates `count` or any value. A
module's provider constraint is therefore load-bearing: the moment a module
names a resource type or an attribute that an older provider does not define,
every caller on that older provider fails. That is what stops a module from
adopting a new provider major without a module major of its own.

## Findings

### Schema validation

A resource type or an attribute the installed provider does not define is a
hard error. It is raised at validate time, independent of `count`, and a `null`
value does not make an unknown attribute disappear.

```text
Error: Invalid resource type
  The provider hashicorp.com/edu/hashicups does not support resource type
  "hashicups_not_a_resource".

Error: Unsupported argument
  An argument named "not_a_real_field" is not expected here.
```

The same error comes from a `count = 0` submodule, so a module cannot hide a
new resource behind a conditional submodule either.

Consequence: a module cannot pass `null` for callers on an older provider and a
value for callers on a newer one. The attribute name has to exist in the schema
the caller has installed.

### `moved` blocks

- A `moved` block cannot be conditional. `count` is rejected with
  `An argument named "count" is not expected here`.
- A `moved` block whose source is absent is a no-op, so a module can ship one
  unconditionally and it only acts for callers who still have the old resource.
- A source still declared at the same address is a hard error:
  `Moved object still exists`. The check is address-exact, so when the resource
  block carries `count`, the unindexed address is not declared and a
  `moved { from = old; to = old[0] }` block is accepted.
- Adding `count` to a resource that had none is already handled by Terraform.
  It proposes moving the single object to instance `0` with no `moved` block at
  all. The
  [documentation](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
  recommends writing the block anyway, for readability. This is specific to
  `count`; a `for_each` conversion still needs a block to name the key.
- A destination that is conditionally absent (`count = 0`) is not moved but
  destroyed, with no error. This is the sharp edge of gating a resource behind
  a variable.
- A `moved` block shipped inside a module moves every instance, with no caller
  action. A root-level `moved` targeting a resource inside a module also works.

### Migration patterns

Two mechanisms let a module adopt a new provider feature without a module
major. Each applies to a different kind of change.

- **New field, or new resource type: backport the schema.** If the provider
  ships the attribute, or the type, in its final 2.x release, present in the
  schema but rejected when set, and implements it in 3.x, a module can name it
  across the whole supported range. Callers on 2.x who set it get a clear
  error; callers who leave it unset are unaffected. The module floor still
  rises within 2.x, which forces `terraform init -upgrade` for callers below
  it.
- **Resource-type switch: staged opt-in.** When a module wants to offer a new
  resource type while leaving existing callers on the old one, it declares
  both, gates them on a `use_3x_features` variable that defaults to `false`,
  and lets callers choose when to migrate. A caller who opts in flips the
  variable and adds a root-level
  `moved { from = module.x.old[0]; to = module.x.new[0] }` in the same apply;
  omitting that move destroys and recreates the resource. The module cannot
  ship the move itself, because it keeps the old resource declared for callers
  who have not opted in, and a `moved` block whose source is still declared is
  an error. Both resource types have to exist across the module's supported
  provider range, so this stages a migration within a range; it does not span a
  range that lacks the new type.

A new field on an existing resource type needs neither mechanism. Nothing
changes address, so there is no migration: the field is either backported or
the module floor moves. A field rename or a field deletion needs a module major
that drops 2.x, because a module can only name one form of a field across its
supported range.

## Layout

- `internal/provider/` is the provider: `hashicups_order`,
  `hashicups_order_legacy`, and `mode.go`, which holds a build-time
  `FeatureMode` selecting whether the `channel` attribute on `hashicups_order`
  is implemented (`3x`) or present but rejected when set (`2x`).
- `experiments/` holds the runnable experiments and `experiments/run.sh`, which
  builds both provider variants and runs all of them.

## Reproducing

```shell
make build build-2x
./experiments/run.sh
```

`experiments/run.sh` prints one `PASS` or `FAIL` line per check. The schema and
backport experiments run `terraform validate` against a `dev_overrides` CLI
config, so they need no `terraform init` and no network. The `moved` and
staged-opt-in experiments use the built-in `terraform_data` resource, so they
need no provider at all. Every `terraform init` is pinned offline with
`TF_CLI_ARGS_init=-get=false`, except where a local module has to be installed.

The suite passes on Terraform 1.11.0 and 1.15.9.

| Experiment          | What it shows                                                                                                         |
| :------------------ | :-------------------------------------------------------------------------------------------------------------------- |
| `schema-validation` | Unknown type and unknown attribute are hard errors, including at `count = 0` and inside a `count = 0` submodule.      |
| `backport-gate`     | The 2.x build accepts an unset backported attribute and rejects a set one; the 3.x build accepts both.                |
| `moved-matrix`      | The `moved` findings above, one case each.                                                                            |
| `staged-opt-in`     | The staged opt-in migration, including the implicit `count` move and the destroy when the root-level move is omitted. |

## Provenance

Derived from the HashiCorp Terraform provider tutorial provider. Licensed under
MPL-2.0; see `LICENSE`.
