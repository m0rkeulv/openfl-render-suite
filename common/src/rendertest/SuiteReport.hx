package rendertest;

import haxe.io.Path;
import rendertest.Html;
import rendertest.Results;

typedef SuiteTest =
{
	settings:Dynamic,
	/** The test's results folder, relative to the suite report. **/
	dir:String,
	runs:Array<RunResults>,
	/** The same test's runs in the baseline build, when there is one. **/
	?baseline:Array<RunResults>
}

/** The suite's index.html: every test against every renderer, the build environment, and a link to each test's report. **/
class SuiteReport
{
	public static function build(tests:Array<SuiteTest>, groups:Array<Dynamic>):String
	{
		var doc = new HtmlDoc();
		var keys:Array<String> = [];
		var all:Array<RunResults> = [];
		for (t in tests)
			for (run in t.runs)
			{
				all.push(run);
				if (keys.indexOf(Results.renderer(run.key)) < 0) keys.push(Results.renderer(run.key));
			}
		keys.sort(function(a, b) return Results.order(a) - Results.order(b));
		var labels = [for (k in keys) k => Results.label(k)];

		var counts = new Map<String, Int>();
		for (run in all)
			counts.set(run.status, (counts.exists(run.status) ? counts.get(run.status) : 0) + 1);

		doc.heading(1, "Summary", "summary");
		var line = [for (s in [Results.PASS, Results.FAIL, Results.ERROR, Results.INFO]) if (counts.exists(s)) counts.get(s) + " " + s].join(", ");
		doc.add(Html.paragraph('${tests.length} tests, ${all.length} runs: $line. Each chip is the first score of the test on that renderer, '
			+ "the worst of its variants when it has some (\"4 runs\"); it links to the test's report, where every variant is listed."));
		var rows:Array<Array<Dynamic>> = [];
		for (t in sortedByGroup(tests, groups))
		{
			var id:String = t.settings.id;
			var row:Array<Dynamic> = [
				'<td><a href="${t.dir}/report.html">${Html.escape(t.settings.title != null ? t.settings.title : id)}</a></td>',
				groupTitle(t.settings.group, groups)
			];
			for (k in keys)
			{
				var folded = fold(t.runs, k);
				if (folded == null)
				{
					row.push(null);
					continue;
				}
				var href = '${t.dir}/report.html#${TestReport.anchor(id, folded.first)}';
				var count = folded.runs > 1 ? ' · ${folded.runs} runs' : "";
				if (folded.score == null || folded.status == Results.ERROR)
				{
					row.push(TestReport.statusChip(folded.status, href));
				}
				else
				{
					var s = folded.score;
					var text = Html.scoreText(s.value, s.unit) + count;
					var cls = folded.status == Results.FAIL ? "off" : (folded.status == Results.PASS ? (s.value == 0 ? "match" : "minor") : null);
					row.push(Html.chip(s.value, text, cls, href));
				}
			}
			rows.push(row);
		}
		doc.add(Html.table(["Test", "Group"].concat([for (k in keys) labels.get(k)]), rows, null,
			"Green: within the test's limit and 0. Amber: within the limit, or under 1% where the test sets none. Red: over the limit, or 1% and more.",
			"summary"));
		var withBaseline = [for (t in tests) if (t.baseline != null && t.baseline.length > 0) t];
		if (withBaseline.length > 0)
		{
			var changes:Array<Array<Dynamic>> = [];
			var baseRows:Array<Array<Dynamic>> = [];
			var allBase:Array<RunResults> = [];
			for (t in sortedByGroup(withBaseline, groups))
			{
				var id:String = t.settings.id;
				var name = t.settings.title != null ? t.settings.title : id;
				var change:Array<Dynamic> = [name];
				var base:Array<Dynamic> = [name];
				for (k in keys)
				{
					var run = TestReport.findRun(t.runs, k);
					var old = TestReport.findRun(t.baseline, k);
					// a renderer column holds the plain run; the variants are compared in the test's report
					var first = run != null && run.scores.length > 0 ? run.scores[0] : null;
					change.push(first != null ? TestReport.changeCell(first, TestReport.findScore(old, first.name)) : null);
					var oldFirst = old != null && old.scores.length > 0 ? old.scores[0] : null;
					base.push(oldFirst != null ? TestReport.scoreChip(oldFirst) : (old != null ? TestReport.statusChip(old.status) : null));
				}
				changes.push(change);
				baseRows.push(base);
				for (r in t.baseline)
					allBase.push(r);
			}
			doc.add(Html.table(["Test"].concat([for (k in keys) labels.get(k)]), changes, "Change of each run's first score against the baseline",
				"Green: lower than the baseline (better), red: higher; times within 5% are grey."));
			doc.add(Html.collapsed(Html.table(["Test"].concat([for (k in keys) labels.get(k)]), baseRows), "Show baseline results",
				"Hide baseline results", TestReport.baselineNote(allBase)));
		}

		doc.heading(1, "Environment", "environment");
		doc.add(Html.paragraph("Which openfl and lime the tests were compiled against. More than one row per library means the runs were not all built from the same code."));
		doc.add(TestReport.environmentTable(all));
		var oses = new Map<String, Bool>();
		for (run in all)
			oses.set(run.environment.os + ", Haxe " + run.environment.haxe + (run.environment.hashlink != null ? ", HashLink " + run.environment.hashlink : ""), true);
		doc.add(Html.table(["System"], [for (o in oses.keys()) [o]]));

		doc.heading(1, "Tests", "tests");
		for (t in sortedByGroup(tests, groups))
		{
			var id:String = t.settings.id;
			doc.heading(2, t.settings.title != null ? t.settings.title : id, "test-" + id);
			if (t.settings.text != null) doc.add(Html.paragraph(t.settings.text));
			doc.add('<p class="meta"><a href="${t.dir}/report.html">Report of this test</a> &middot; <code>tests/$id</code></p>');
			var trows:Array<Array<Dynamic>> = [];
			for (run in t.runs)
			{
				var r:Array<Dynamic> = [
					'<td><a href="${t.dir}/report.html#${TestReport.anchor(id, run.key)}">${Html.escape(run.label)}</a></td>',
					TestReport.statusChip(run.status)
				];
				r.push([for (s in run.scores) s.name + " " + Html.scoreText(s.value, s.unit)].join(", "));
				trows.push(r);
			}
			if (trows.length > 0) doc.add(Html.table(["Renderer", "Status", "Scores"], trows));
		}

		var facts = TestReport.facts(all);
		return doc.render("OpenFL render tests", "OpenFL render tests", "OpenFL render tests · suite report",
			"Every test rendered by OpenFL and compared with the picture Adobe AIR shows for the same scene. Lower is better; 0 is a match.", facts);
	}

	/**
		The summary as Markdown: one row per test, one column per renderer, each cell the status
		and the first score; the libraries above it. For GitHub's job summary.
	**/
	public static function markdown(tests:Array<SuiteTest>, groups:Array<Dynamic>, reportLink:String, title:String = "OpenFL render tests"):String
	{
		var keys:Array<String> = [];
		var all:Array<RunResults> = [];
		for (t in tests)
			for (run in t.runs)
			{
				all.push(run);
				if (keys.indexOf(Results.renderer(run.key)) < 0) keys.push(Results.renderer(run.key));
			}
		keys.sort(function(a, b) return Results.order(a) - Results.order(b));
		var counts = new Map<String, Int>();
		for (run in all)
			counts.set(run.status, (counts.exists(run.status) ? counts.get(run.status) : 0) + 1);
		var b = new StringBuf();
		b.add("## " + title + "\n\n");
		var seen = new Map<String, Bool>();
		for (run in all)
			for (lib in run.environment.libraries)
			{
				var line = '**${lib.name}** ${Results.describe(lib)}';
				if (seen.exists(line)) continue;
				seen.set(line, true);
				b.add(line + "  \n");
			}
		b.add("\n" + [for (s in [Results.PASS, Results.FAIL, Results.ERROR, Results.INFO]) if (counts.exists(s)) counts.get(s) + " " + s].join(", ")
			+ (reportLink != null ? ' &middot; $reportLink' : "") + "\n\n");
		b.add("| Test | " + [for (k in keys) Results.label(k)].join(" | ") + " |\n");
		b.add("|---|" + [for (k in keys) "---"].join("|") + "|\n");
		for (t in sortedByGroup(tests, groups))
		{
			var cells = [];
			for (k in keys)
			{
				var folded = fold(t.runs, k);
				if (folded == null)
				{
					cells.push(" ");
					continue;
				}
				var mark = switch (folded.status)
				{
					case Results.PASS: "✅";
					case Results.FAIL: "❌";
					case Results.ERROR: "⚠️";
					default: "ℹ️";
				}
				var s = folded.status != Results.ERROR ? folded.score : null;
				cells.push(mark + (s != null ? " " + Html.scoreText(s.value, s.unit) : " " + folded.status)
					+ (folded.runs > 1 ? ' (${folded.runs} runs)' : ""));
			}
			b.add('| ${t.settings.title != null ? t.settings.title : t.settings.id} | ${cells.join(" | ")} |\n');
		}
		return b.toString();
	}

	/**
		A test's runs on one renderer (its plain run and its variants) as one: the worst status, the
		highest value of the first score, the number of runs, and the key of the run to link to (the
		worst one).
	**/
	static function fold(runs:Array<RunResults>, renderer:String):{status:String, score:Results.Score, runs:Int, first:String}
	{
		var mine = [for (r in runs) if (Results.renderer(r.key) == renderer) r];
		if (mine.length == 0) return null;
		var status = Results.worst([for (r in mine) r.status]);
		var score:Results.Score = null;
		var link = mine[0].key;
		for (r in mine)
		{
			if (r.status == status && link == mine[0].key && r.status != Results.PASS) link = r.key;
			if (r.scores.length == 0) continue;
			var first = r.scores[0];
			if (score == null || first.value > score.value)
			{
				score = first;
				if (status == Results.PASS || status == Results.INFO) link = r.key;
			}
		}
		return {status: status, score: score, runs: mine.length, first: link};
	}

	static function groupTitle(id:String, groups:Array<Dynamic>):String
	{
		if (id == null) return "";
		for (g in groups)
			if (g.id == id) return g.title;
		return id;
	}

	static function sortedByGroup(tests:Array<SuiteTest>, groups:Array<Dynamic>):Array<SuiteTest>
	{
		var order = [for (i in 0...groups.length) (groups[i].id : String) => i];
		var list = tests.copy();
		list.sort(function(a, b)
		{
			var ga = order.exists(a.settings.group) ? order.get(a.settings.group) : 999;
			var gb = order.exists(b.settings.group) ? order.get(b.settings.group) : 999;
			if (ga != gb) return ga - gb;
			return Reflect.compare(a.settings.order != null ? a.settings.order : 0, b.settings.order != null ? b.settings.order : 0);
		});
		return list;
	}
}
