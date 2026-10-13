# Duplicate names in Lean, Rocq and Isabelle

This note compares how Lean, Rocq and Isabelle handle two imports that declare the same name. It explains why Lean merges duplicate theorems, and how Rocq and Isabelle avoid the merge.

The Lean results come from tests and from the Lean source. [README.md](README.md) lists the tested Lean versions. Below, "the newer versions" means the tested versions from 4.31.0 on: 4.31.0, 4.33.1, 4.34.1, 4.35.0 and `nightly-2026-10-13`. "The older versions" means 4.28.0-rc1 and 4.29.0-rc4. The Rocq results come from tests with Coq 8.20.1 in `rocq/`. The Isabelle results come from tests with an Isabelle development version (Mercurial `b391142bd2d2`) in `isabelle/`. Points that come only from documentation or source are marked "not tested".

## Summary

| | Lean 4 | Rocq | Isabelle |
|---|---|---|---|
| Full name of a public theorem in the tests | `foo`, without the module | library path and name, for example `B.foo` | by default, theory name and name, for example `B.foo` |
| `B` and `C` both declare `foo` | one entry: merged or import error | two constants, `B.foo` and `C.foo` | two facts, `B.foo` and `C.foo` |
| Short name `foo` after importing `B` and `C` | the one merged entry | the last import, no warning | the last import, no warning |
| Two imports declare the same full name | merged or import error | not tested | import error |
| Shared base file in a diamond | loaded once | loaded once. Two compiled versions of `A` give an error | loaded once |
| Scheme from the tested dependent `rewrite` | not applicable | `Qed` proof: inlined in the proof. `Defined` proof: a global constant | not applicable |
| Equation lemmas of a recursive function | global declarations, generated on demand, also in other modules | `Function` generates them with the definition (not tested) | `fun` generates them with the definition (not tested) |
| How admitted proofs are represented and audited | `sorryAx` in the proof term. On the newer versions, `#print axioms` can disagree with the kept copy of a duplicate | the lemma becomes an axiom, reported by `Print Assumptions` | the oracle `Pure.skip_proof` in the derivation of each theorem that uses it |

A diamond import is two modules `B` and `C` that both import `A`, and a module `D` that imports `B` and `C`.

## Lean 4

Lean does not add the module to the name of a public declaration. Private names are an exception: they contain the module. Lean has namespaces, but they are independent of the module structure. The environment is one table of full names.

When Lean imports modules, `finalizeImport` adds their constants to this table in import order. If a name is already in the table, Lean calls `subsumesInfo` in both directions. The check passes in three cases, and all of them require the same name, the same type and the same universe parameters:

- Two theorems with the same `all` list.
- A theorem whose `all` list is `[foo]`, and an axiom `foo` that is not `unsafe`.
- Two axioms whose type passes a cheap check that it is a proposition, and that agree on `unsafe`.

Lean compares the types by expression equality, not by definitional equality. It never compares the proofs. If the check fails in both directions, the import fails with `environment already contains 'foo'`. [README.md](README.md) holds the tests for each case.

If the check passes, Lean keeps one `ConstantInfo` in the table. When the later copy subsumes the earlier copy, the later copy replaces it. Here, "first" and "last" refer to the modules that declare the name, in the order in which Lean processes the imports. Thus the last module wins between two theorems, and a theorem wins against an axiom in both orders. `#print foo` shows this kept copy on all tested versions.

`#print axioms` does not always read the kept copy. On the older versions, it walks the proof in the table. On the newer versions, it first looks up axiom data that each module stores in its `.olean` file. If it finds data for an imported constant, it uses the data and does not walk the proof. Lean finds that data through `const2ModIdx`, which keeps the first module that declares the name. Thus `#print axioms` reports the first module, while the table holds the last module. [leanprover/lean4#13117](https://github.com/leanprover/lean4/pull/13117) added the stored data. We believe that this PR caused the change, but we did not bisect.

Lean merges duplicates because of equation lemmas such as `f.eq_1`. Lean generates these lemmas on demand. The definition of `f` does not always generate them. A module that uses a lemma and does not import a copy generates the lemma itself. The lemma gets the same full name in every such module, so a user can write `f.eq_1` in any file. The docstring of `subsumesInfo` gives this as the motivation.

The `diamond/` directory shows the case. `A.lean` defines a recursive `f` and does not use `f.eq_1`. `B.lean` and `C.lean` both import `A` and use `f.eq_1`. Thus `B` and `C` each generate `f.eq_1`. `Where.lean` imports `B` and `C` and lists the modules that declare `f.eq_1`. On 4.28.0-rc1 and 4.35.0, it lists `B` and `C`, but not `A`. `D.lean` imports `B` and `C` without an error, and `#print axioms f.eq_1` reports no axioms.

The merge cannot tell two copies of a generated lemma from two unrelated hand-written theorems with the same statement. Thus a `sorry` copy can be the kept copy, or the copy that `#print axioms` reports. The import order decides which. On the newer versions, the two choices differ.

To run the diamond test, compile the files in order with one toolchain:

```bash
cd diamond
L=~/.elan/toolchains/leanprover--lean4---v4.35.0/bin/lean
set -e
for m in A B C; do LEAN_PATH=. $L -o $m.olean $m.lean; done
LEAN_PATH=. $L D.lean
LEAN_PATH=. $L Where.lean
```

## Rocq

`rocq/run.sh` runs the Rocq tests.

The kernel name of a Rocq constant includes the library path. If `B` and `C` both declare `foo`, the environment holds two constants, `B.foo` and `C.foo`. Nothing merges.

The short name `foo` refers to the constant from the last import. After `Require Import B C.`, `foo` is `C.foo`. After `Require Import C B.`, it is `B.foo`. Rocq gives no warning. `Locate foo` lists both constants and shows the one that `foo` selects.

To see which constant a proof uses, run `Print bar`. Rocq prints the shortest name that refers to the constant in the current context. Thus `bar = foo` means the constant that `foo` selects, and `bar = B.foo` means the other one. `Print Assumptions bar` does not answer this question. It reports the axioms that `bar` depends on, not the constants that it uses. Two different constants can give the same list, for example two axiom-free proofs.

In `rocq/`, `B.foo` has a proof and `C.foo` uses `Admitted`. `Admitted` turns the lemma into an axiom. `Print Assumptions` then lists `C.foo` under "Axioms", in the same way as an `Axiom` declaration.

Rocq generates some schemes on demand. In `rocq/`, a dependent `rewrite` needs the scheme `internal_eq_rew_r_dep`. In `B` and `C`, the proofs end with `Qed`. There, Rocq inlines the scheme as a `let` in each proof term. `Print B.b` shows the `let`, and `Locate internal_eq_rew_r_dep` in the importing file finds nothing. In `E`, the same proof ends with `Defined`. There, Rocq declares the global constant `E.internal_eq_rew_r_dep`. Its name contains the library path, so two such copies do not collide.

The core `Fixpoint` command generates no equation lemmas. The `Function` command and the Equations plugin generate them with the definition (not tested).

Rocq also checks diamonds for consistency. In the last test of `rocq/run.sh`, `B` is compiled against `Definition a := 1.` in `A`. Then `A` changes to `Definition a := 2.`, and `A` and `C` are compiled again. `Require Import B C.` then fails with "Compiled library B ... makes inconsistent assumptions over library A".

## Isabelle

`isabelle/run.sh` runs the Isabelle tests. It prints all messages except timing lines, and the exit code of each theory.

Isabelle keeps constants and facts in separate namespaces. A fact is a named list of theorems, and a theorem can also exist without a name. This note compares facts, because the Lean and Rocq examples compare theorems. By default, a global fact gets the theory name as a prefix, for example `B.foo`.

If `B` and `C` both declare the fact `foo`, a theory that imports both holds `B.foo` and `C.foo`. The short name `foo` refers to the fact from the last import. With `imports B C`, `foo` is `C.foo`. With `imports C B`, it is `B.foo`. Isabelle gives no warning. The control theory `Warn` shows that `isabelle process` prints warnings, with the prefix `###`.

Isabelle rejects two separate facts with the same full name. In `isabelle/`, `RB` and `RC` use `Sign.root_path`, so both declare a fact with the full name `foo`. A theory that imports both fails with `Duplicate fact declaration "foo" vs. "foo"`. Thus Isabelle has no merge rule like `subsumesInfo`.

The status of a theorem is part of the theorem value, not of its name. Isabelle records `sorry` as the oracle `Pure.skip_proof` in the derivation of the theorem. In `isabelle/`, `C.foo` uses `sorry`. A theorem `bar` that uses `C.foo` carries this oracle. A theorem `bar` that uses `B.foo` carries no oracle. An oracle is a separate category from an axiom of the logic.

For a recursive function, `fun` generates the equations `f.simps` with the definition. `function` generates `f.psimps` first, and `f.simps` after the termination proof (not tested).

## Why Lean differs

Lean chose two things together. Module names are not part of public constant names, and equation lemmas are generated on demand in the module that uses them. With both, two copies of a generated lemma in a diamond have the same full name. Lean must then reject them or merge them, and it merges them by type.

Rocq and Isabelle avoid this case in the tests above. Both provers put the library or theory name in the full name. Rocq also inlines the tested on-demand scheme in proofs that end with `Qed`. Other designs are possible for Lean, for example generating the lemmas in the defining module, or allowing the merge only for generated lemmas. We did not examine the cost of these designs.

The Rocq and Isabelle short-name rules also depend on the import order. But in both provers, the proof term or the theorem value records the copy that a proof uses. On the newer Lean versions, `#print axioms` and the kept proof can disagree.
