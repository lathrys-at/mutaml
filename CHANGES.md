Next release
------------

- Add mutation operators for the comparisons `<`, `<=`, `>` and `>=`,
  for the equality tests `=` and `<>`, for the `equal` function of the
  modules of the standard library, for the Boolean connectives `&&`
  and `||`, for `not e`, for `Some e`, and for the integer arguments of
  a known list of functions
- Add two mutation operators that are off by default: a `when` guard
  made always true, and any string literal made empty
- Name every mutation operator, and give every operator, the ones
  upstream already had as well as the new ones, a command-line option
  and an environment variable that turn it off. Every operator that
  was on before is still on by default, so a project that sets nothing
  sees no change
- List every mutation operator in the README, with its default and
  what it cannot see
- Use dune.3.18 support to generate `x-maintenance-intent` entry
- Patch `ppx_yojson_conv` dependency which was missing a `v`-prefix
- Introduce a `mutaml.opam.template` to avoid opam linting failure #41
- Adjust RE to support `runtest` on OpenBSD too #40
- Remove `which` and `conf-which` dependency #39
- Support ppxlib.0.34 and runtest on OCaml 5.3 #36

0.3
---

- Avoid mutations in attribute parameters #29
- Avoid polymorphic equality which is incompatible with Core #30

0.2
---

- Add support for ppxlib.0.28 and above #27
- Avoid triggering 2 mutations of a pattern incl. a when-clause
  causing a redundant sub-pattern warning #22, #23

0.1
---

- Initial opam release of `mutaml`
