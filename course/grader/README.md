# tina4grade

Grades a course exercise. Two gates, and the second one carries the marks.

## Running it

```bash
export TINA4_MCP_TOKEN=t4_...        # your Tina4 team token
python3 course/grader/tina4grade.py course/exercises/module-01 \
    --submission course/exercises/module-01/solution
```

Flags:

- `--code-only` skips the examiner. No token needed. Useful while writing code.
- `--json` machine-readable output for CI.

Exit code is 0 on a pass, 1 on a fail, 2 on a usage error.

## Gate one: does it run (30 marks at Level 1)

`_runner.py` copies the student's route into a scratch project and dispatches real requests
through `tina4_python.test_client.TestClient`, which enters the REAL front controller:
global middleware, the secure-by-default auth gate, error handling, the lot.

Nothing is mocked. A mock would assert our assumption about the framework rather than the
framework, and a test that passes against a mock and fails in production was never a test.

Checks are declared in each exercise's `rubric.py` under `code_checks`.

## Gate two: do you understand it (70 marks at Level 1)

Four written answers, marked across Explain, Predict, Diagnose and Judge by the Tina4
engine (`tina4_chat` on `mcp.tina4.com`, grounded on the live corpus).

Each question is a separate engine call. An earlier version sent all four in one request and
the reply truncated mid-JSON.

### Parroting is settled in code, not by the model

The first version asked the examiner to notice copied text. It did not. A submission lifted
word for word from the chapter scored 20/20, because a rule buried in a long prompt competes
with everything else in that prompt and loses.

So `parroting.py` measures it instead. Both texts get cut into overlapping six-word windows,
and the check asks what fraction of the answer's windows also appear in the chapter. Copying
a sentence puts every window of it into the chapter's set. Writing the same idea in your own
words does not, because word order diverges within a few words.

Measured on the two fixtures:

| Submission | Overlap | Longest lifted run |
|---|---|---|
| Genuine reasoning | 0.000 | 3 to 4 words |
| Copied from chapter | 0.786 to 1.000 | 37 to 56 words |

The threshold sits at 0.45, in the empty gap between them. Anything over it scores zero on
that question before the engine is asked anything, and the student is told the percentage
and the length of the lifted run rather than just accused.

## Student answers are untrusted input

Answers reach the examiner inside explicit markers, with instructions to treat the contents
as material to mark and never as instructions. An answer that tries to award itself marks
gets marked on its merits and flagged with `injection_attempt`.

## Regression fixtures

`tests/fixtures/strong/` and `tests/fixtures/parrot/` contain **identical, fully working
code** and differ only in the written answers. This is the contract the grader exists to
enforce:

```
strong  ->  code 30/30,  comprehension 64/70,  FINAL 94/100  PASS
parrot  ->  code 30/30,  comprehension  0/70,  FINAL 30/100  FAIL
```

Same code. Opposite outcome. If a change ever lets `parrot` pass, the grader is broken no
matter what else still works.

Run both after touching anything in this folder:

```bash
python3 course/grader/tina4grade.py course/exercises/module-01 \
    --submission course/grader/tests/fixtures/strong
python3 course/grader/tina4grade.py course/exercises/module-01 \
    --submission course/grader/tests/fixtures/parrot
```

## Adding an exercise

Create `course/exercises/module-NN/rubric.py` exporting a `RUBRIC` dict. Plain Python rather
than YAML keeps the grader zero-dependency, the same rule the framework holds itself to.

Required keys: `module`, `title`, `level`, `pass_mark`, `weights`, `route_file`,
`answers_file`, `chapter`, `code_checks`, `questions`.

`chapter` is resolved relative to `docs/`, and the file it points at is what parroting gets
measured against. An exercise with no `chapter` disables the parroting check, so always set
it.
