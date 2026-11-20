# Writing a test

Every folder here is one test and a plain OpenFL project: `lime test hl` (OpenGL) or
`lime test hl -Dsoftware` (Cairo) in the folder builds it, renders the scene, compares what the
window shows with the AIR reference, and writes `results/<renderer>/` and `results/report.html`.
`haxe run.hxml <test>` in the suite folder does the same for every renderer the test lists.

```
tests/<id>/
  project.xml        the OpenFL project; includes ../../common/rendertest.xml
  test.json          id, title, text, renderers, variants, limits (below)
  Source/Main.hx     the scene; calls rendertest.Harness.capture(...) when it is ready
  Source/Score.hx    the comparison: score(run:TestRun), called with the capture
  reference/         air.png (what the AIR window showed), air_draw.png (AIR's BitmapData.draw),
                     air_<variant>.png for variants
  README.md          optional: what the test checks and why
```

## project.xml

```xml
<project>
	<meta title="CoverageBlend" package="rendertest.coverage" version="1.0.0" company="" />
	<app main="Main" file="CoverageBlend" path="Export" />
	<window width="400" height="200" fps="60" />
	<source path="Source" />
	<include path="../../common/rendertest.xml" />
</project>
```

`common/rendertest.xml` adds lime and openfl (the current haxelibs, or checkouts given by
`-DRENDERTEST_OPENFL=<folder>` / `-DRENDERTEST_LIME=<folder>`), the shared code, and the
Cairo window for `-Dsoftware`.

## test.json

```json
{
 "id": "coverage",
 "group": "coverage",
 "title": "ALPHA on a changing shape",
 "text": "One or two sentences for the report: what the scene is and what must hold.",
 "renderers": ["hl_opengl", "hl_cairo", "neko_cairo"],
 "defines": [],
 "variants": [{"suffix": "_t", "label": "transparent stage", "defines": ["transparent_stage"], "renderers": ["hl_cairo"]}],
 "limits": {"worst cell": 0.5, "hl_cairo": {"worst cell": 1.0}},
 "notes": ["Shown in the report's summary, e.g. a known difference and why."]
}
```

- `renderers`: `<target>_<renderer>`; `cairo` builds with `-Dsoftware`, `opengl` without.
- `variants`: extra builds of the same project. Each is built with its `defines` and with
  `-Drendertest_variant=<suffix without the underscore>`, and its runs are keyed
  `<renderer><suffix>` (hl_cairo_t). `TestRun.variant` is the suffix, and
  `run.reference("air")` loads `air<suffix>.png` when it exists.
- `limits`: the largest value a score may have, for every renderer or per renderer key. A run
  with a score over its limit fails; a test without limits only reports (status "info").

## Main.hx

The scene as it was, with the capture code replaced by one call once the frame to compare is
on screen:

```haxe
Harness.capture(stage, Score.score, width, height);
```

The Cairo window's `readPixels` returns the previous frame, so capture one frame after the
last change. The harness crops the capture to `width` x `height`. Under AIR the same call writes
the stage's `draw()` to the user directory and keeps the window up for a reference capture.

## Score.hx

```haxe
public static function score(run:TestRun):Void
{
	var air = run.reference("air");                 // reference/air[_variant].png
	var d = Compare.same(run.capture, air, x, y, w, h, 8);   // d.off percent, d.max, d.count
	run.table("Percent of each cell off by more than 8", ["cell", "OpenGL"], [[1, Html.percent(d.off, d.max)]]);
	run.score("worst cell", d.off);                 // lower is better; limits apply by name
	run.image("mask_air", Compare.mask(run.capture, air, 8), "Pixels off against AIR", "capture");
}
```

Table cells: strings, numbers, `null` (a dash), `Html.percent(v, ?max)` and `Html.value(v, text)`.
Images with the same card are shown side by side; the capture is in card "capture".

To check a scorer against saved captures without rendering, run the built program with
`RENDERTEST_CAPTURE=<png>` and `RENDERTEST_KEY=<name>`; `RENDERTEST_OUT` sets the results folder.
