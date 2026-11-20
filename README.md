# OpenFL render tests

Scenes rendered by OpenFL and compared with what Adobe AIR shows for the same scene: blend modes,
groups and cutters, coverage and alpha, fill-seam bleed, stage quality and the bitmap filters, plus
a performance benchmark. Every test is a plain OpenFL project that runs, scores and reports by
itself; the suite runner does the same for every test and renderer and writes one report. Only
Haxe, haxelib, lime and openfl are needed, on Windows, Linux and macOS alike.

## Running

One test, in its folder:

```
cd tests/coverage
lime test hl              # OpenGL
lime test hl -Dsoftware   # Cairo
```

It writes `tests/coverage/results/<renderer>/` (the capture, difference masks, `results.json`)
and `tests/coverage/results/report.html`, which covers every renderer run so far.

Every test, from this folder:

```
haxe run.hxml                                  # all tests, every renderer they list
haxe run.hxml coverage blend --renderers hl_cairo
haxe run.hxml --skip perf --openfl ../../openfl --out results-branch
haxe run.hxml --list                           # the tests and their runs
```

The suite report is `results/index.html`; each test's report is `results/<test>/report.html`.

| Option | |
|---|---|
| `--renderers a,b` | only these renderers: `hl_opengl`, `hl_cairo`, `neko_cairo` |
| `--skip a,b` | leave these tests out |
| `--openfl DIR`, `--lime DIR` | build against these checkouts instead of the current haxelibs |
| `--out DIR` | where results and reports go (default `results`) |
| `--baseline DIR` | another build's results folder: the reports add the change against it, with the baseline's own results in a collapsed block |
| `-D NAME` | an extra define for every build |
| `--timeout S` | stop a run that has not captured after S seconds (default 60; a test can set its own) |
| `--visible` | Cairo runs open a window (default: SDL's dummy driver, no window) |
| `--report-only` | rebuild the reports from the results in `--out` |
| `--strict` | exit with 1 when a run is over a limit (errors always exit with 2) |
| `--summary FILE` | also write the result table as Markdown |

To compare a branch with develop: run the suite once with `--openfl <develop checkout> --out
results-develop`, then with `--openfl <branch checkout> --baseline results-develop`.

## Which openfl and lime

Every result records the openfl and lime it was compiled against, read when the test is
compiled: the version, and for a git checkout the branch, commit, commit date and message, and how
many files differ from the commit. The reports show them at the top and in an Environment table;
more than one row per library means the runs were not all built from the same code. Without
`--openfl`/`--lime`, a build uses the haxelibs that are current where it runs: `haxelib list`
shows them, and a folder with its own `.haxelib` uses that one.

## Layout

```
run.hxml, air.hxml     the suite runner and the AIR reference tool (tools/Suite.hx, tools/Air.hx)
common/                the shared code every test includes (common/rendertest.xml):
  src/rendertest/      Harness (capture and finish), TestRun (what a scorer records), Compare and
                       Pixels (pixel comparison), Results, TestReport, SuiteReport, Html, Build
  template.html        the report page
tests/<id>/            one test: project.xml, test.json, Source/Main.hx (the scene), Source/Score.hx
                       (the comparison), reference/ (the AIR pictures); see tests/README.md
tests/groups.json      the groups the reports order the tests by
tools/air/             the AIR window capture (PrintWindow)
original/              the kits this suite was made from, unchanged, for reference
```

## The tests

| Test | | Renderers | Variants |
|---|---|---|---|
| `alphaswitch` | Switching to ALPHA later | hl_opengl, hl_cairo | |
| `bleed` | Fill-seam bleed | hl_cairo | nosupersample |
| `blend` | Every blend mode (bitmap, vector paths, drawRect, discs) | hl_opengl, hl_cairo | vector, rect, circle |
| `cachebitmap` | Inside cacheAsBitmap | hl_opengl, hl_cairo | |
| `canvasalpha` | Blended container at half alpha | hl_opengl, hl_cairo | |
| `coverage` | ALPHA on a changing shape | hl_opengl, hl_cairo, neko_cairo | |
| `coveragealpha` | ALPHA container at half alpha | hl_opengl, hl_cairo | |
| `cutters` | Where ERASE and ALPHA cut | hl_opengl, hl_cairo | |
| `drawnhole` | What counts as drawn | hl_opengl, hl_cairo, neko_cairo | |
| `drawroot` | The mode given to BitmapData.draw | hl_opengl, hl_cairo | |
| `filters` | Filter parameter sweep | hl_opengl, hl_cairo | p0 to p3 (pages) |
| `hidden` | Objects that draw nothing | hl_opengl, hl_cairo | |
| `hittest` | Hit tests do not change drawing | hl_opengl, hl_cairo, neko_cairo | nohit |
| `nested` | Nested groups | hl_opengl, hl_cairo | |
| `perf` | Software rendering performance | hl_cairo | filters, vector, text |
| `quality` | Stage quality | hl_cairo | nosupersample |
| `runs` | Runs of SUBTRACT and INVERT | hl_opengl, hl_cairo, neko_cairo | |
| `sizes` | Object sizes | hl_opengl, hl_cairo, neko_cairo | |
| `spin` | Rotated objects | hl_opengl, hl_cairo, neko_cairo | |
| `stage` | Straight on the stage | hl_opengl, hl_cairo | t (transparent stage) |
| `textblend` | Blend modes on text | hl_opengl, hl_cairo, neko_cairo | |
| `textfield` | Text that changes every frame | hl_opengl, hl_cairo | |

A score is lower-is-better and 0 is a match with AIR. A test's `limits` (test.json) turn its
scores into pass or fail; known differences are explained in each test's `notes`. `perf` has no
reference and no limits: compare builds with `--baseline`.

## The references

`tests/<id>/reference/` holds what AIR showed: `air.png` is the AIR window (captured with
PrintWindow, the screen being the truth), `air_draw.png` AIR's own `BitmapData.draw` of the stage,
and `air_<variant>.png` for variants with their own scene. To capture them again (Windows, an AIR
SDK):

```
haxe air.hxml coverage --adl "<AIR SDK>/bin/adl.exe"
```

## Continuous integration

`.github/workflows/render-tests.yml` runs every test on GitHub's Linux runners for five openfl
builds: openfl/openfl `develop`, and from the repository owner's openfl fork (`<owner>/openfl`)
`castlewars/prod` and the pull-request branches `pr/cairo-supersampling`,
`pr/filters-flash-parity` and `pr/blend-modes-v2`. Each build runs on two runners in parallel, the
Cairo renderer under SDL's dummy driver (HashLink and neko) and OpenGL under Xvfb with Mesa's
llvmpipe (on one thread, `LP_NUM_THREADS=0`), so ten jobs run at once. A report job per build merges its two halves:

| Build | Artifact | |
|---|---|---|
| develop | `render-test-report-develop` | the baseline; only reports |
| castlewars/prod | `render-test-report-castlewars-prod` | with the change against develop; a test over its limit fails the job |
| pr/cairo-supersampling | `render-test-report-cairo-supersampling` | with the change against develop: what the pull request fixes; only reports |
| pr/filters-flash-parity | `render-test-report-filters-flash-parity` | the same |
| pr/blend-modes-v2 | `render-test-report-blend-modes-v2` | the same |

A pull-request branch carries one fix on top of develop, so the tests for the other fixes still
show develop's failures; that is why only castlewars/prod can fail the run. Each run's summary page
shows the five result tables. Pushes and pull requests run it; from the Actions tab the refs, the
fork, the lime release and the tests can be chosen. With the repository variable
`RENDER_TESTS_PAGES` set to `true` and Pages set to "GitHub Actions", the reports are also published
as web pages under one index. A lime git checkout needs its native libraries rebuilt, so the
workflow takes lime releases only.

## Adding a test

See `tests/README.md`: a project, a `test.json`, the scene with one `Harness.capture` call, a
scorer, and the AIR references.
