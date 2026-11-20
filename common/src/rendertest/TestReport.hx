package rendertest;

import haxe.io.Path;
import rendertest.Html;
import rendertest.Results;

/**
	A test's report.html, built from every run under its results folder (one per renderer and
	variant). Written by the test itself after each run, and by the suite runner.
**/
class TestReport
{
	/** Writes <dir>/report.html; `baselineDir` is another build's results folder of the same test, to compare with. **/
	public static function write(dir:String, settings:Dynamic, ?baselineDir:String):String
	{
		var runs = Results.runs(dir);
		var baseline = baselineDir != null ? Results.runs(baselineDir) : null;
		var file = Path.join([dir, "report.html"]);
		sys.io.File.saveContent(file, build(runs, settings, "", baseline));
		return file;
	}

	/**
		The change of a score against the baseline's: in percent for times (grey within 5%), in the
		score's own unit for the rest (grey when equal). Lower is better: green is an improvement.
	**/
	public static function changeCell(score:Score, base:Score):String
	{
		if (base == null) return Html.dash();
		if (score.unit == "ms")
		{
			var change = base.value != 0 ? 100 * (score.value - base.value) / base.value : 0.0;
			var cls = change < -5 ? "match" : (change > 5 ? "off" : "none");
			return Html.chip(Html.round(change, 2), (change >= 0 ? "+" : "") + Html.fixed(change, 0) + "%", cls);
		}
		var delta = score.value - base.value;
		var cls = delta < 0 ? "match" : (delta > 0 ? "off" : "none");
		var text = (delta >= 0 ? "+" : "") + Html.fixed(delta, 2) + (score.unit == "%" ? " points" : (score.unit != "" ? " " + score.unit : ""));
		return Html.chip(Html.round(delta, 3), text, cls);
	}

	public static function findRun(runs:Array<RunResults>, key:String):RunResults
	{
		if (runs != null)
			for (r in runs)
				if (r.key == key) return r;
		return null;
	}

	public static function findScore(run:RunResults, name:String):Score
	{
		if (run != null)
			for (s in run.scores)
				if (s.name == name) return s;
		return null;
	}

	/** The baseline in one line: its openfl and lime. **/
	public static function baselineNote(baseline:Array<RunResults>):String
	{
		if (baseline == null || baseline.length == 0) return "";
		return "The baseline, not the build under review: "
			+ [for (lib in baseline[0].environment.libraries) lib.name + " " + Results.describe(lib)].join(", ") + ".";
	}

	/** One chip per score; `href` links the chip to the run's section. **/
	public static function scoreChip(s:Score, ?href:String):String
	{
		var text = Html.scoreText(s.value, s.unit);
		// with a limit: red only over it; within it amber, or green at 0
		var cls = s.limit == null ? null : (s.value > s.limit ? "off" : (s.value == 0 ? "match" : "minor"));
		return Html.chip(s.value, text, cls, href);
	}

	public static function statusChip(status:String, ?href:String):String
	{
		var cls = switch (status)
		{
			case Results.PASS: "match";
			case Results.FAIL, Results.ERROR: "off";
			default: "none";
		}
		var order = switch (status)
		{
			case Results.ERROR: 3;
			case Results.FAIL: 2;
			case Results.INFO: 1;
			default: 0;
		}
		return Html.chip(order, status, cls, href);
	}

	public static function anchor(test:String, key:String):String
	{
		return "run-" + test + "-" + key;
	}

	/** The libraries of the runs, one row per distinct build; differences between runs show as more rows. **/
	public static function environmentTable(runs:Array<RunResults>):String
	{
		var seen = new Map<String, Bool>();
		var rows:Array<Array<Dynamic>> = [];
		for (run in runs)
		{
			for (lib in run.environment.libraries)
			{
				var id = lib.name + "|" + lib.path + "|" + lib.commit + "|" + lib.changedFiles;
				if (seen.exists(id)) continue;
				seen.set(id, true);
				rows.push([
					lib.name,
					lib.version,
					lib.branch != null ? lib.branch : "haxelib release",
					lib.commit,
					lib.commitDate,
					lib.subject,
					lib.changedFiles,
					lib.path
				]);
			}
		}
		return Html.table(["Library", "Version", "Branch", "Commit", "Commit date", "Commit message", "Changed files", "Folder"], rows,
			"openfl and lime the runs were built against (read when each test was compiled)");
	}

	/** The facts row of a report: openfl, lime, haxe of the first run. **/
	public static function facts(runs:Array<RunResults>):Array<Array<String>>
	{
		var list:Array<Array<String>> = [];
		if (runs.length == 0) return list;
		var env = runs[0].environment;
		for (lib in env.libraries)
			list.push([lib.name, Results.describe(lib)]);
		list.push(["haxe", env.haxe]);
		if (env.hashlink != null) list.push(["hashlink", env.hashlink]);
		var latest = "";
		for (run in runs)
			if (run.date > latest) latest = run.date;
		list.push(["run", latest]);
		return list;
	}

	/**
		The page. `prefix` is the path from the page to the test's results folder ("" for the test's
		own report.html).
	**/
	public static function build(runs:Array<RunResults>, settings:Dynamic, prefix:String, ?baseline:Array<RunResults>):String
	{
		var doc = new HtmlDoc();
		var id:String = settings.id != null ? settings.id : (runs.length > 0 ? runs[0].test : "test");
		var title:String = settings.title != null ? settings.title : id;
		addSections(doc, runs, settings, prefix, id, 1, baseline);
		return doc.render(title + " - render test", title, "OpenFL render tests · " + id, Html.escape(settings.text != null ? settings.text : ""),
			facts(runs));
	}

	/** The test's sections, also used inside the suite report. **/
	public static function addSections(doc:HtmlDoc, runs:Array<RunResults>, settings:Dynamic, prefix:String, id:String, level:Int = 1,
			?baseline:Array<RunResults>):Void
	{
		doc.heading(level, "Summary", id + "-summary");
		if (runs.length == 0)
		{
			doc.add(Html.paragraph("No results yet. Run the test (lime test hl) or the suite runner."));
			return;
		}
		var names:Array<String> = [];
		for (run in runs)
			for (s in run.scores)
				if (names.indexOf(s.name) < 0) names.push(s.name);
		var rows:Array<Array<Dynamic>> = [];
		for (run in runs)
		{
			var row:Array<Dynamic> = ['<td><a href="#${anchor(id, run.key)}">${Html.escape(run.label)}</a></td>', statusChip(run.status)];
			for (n in names)
			{
				var found:Score = null;
				for (s in run.scores)
					if (s.name == n) found = s;
				row.push(found != null ? scoreChip(found) : null);
			}
			row.push(run.date);
			rows.push(row);
		}
		doc.add(Html.table(["Renderer", "Status"].concat(names).concat(["Run"]), rows, null,
			"Lower is better; 0 is a match with the reference. A score over the test's limit fails the run.", "summary"));
		doc.add(Html.legend([
			["match", "0", "no pixel off"],
			["minor", "under 1%", "edges, rounding"],
			["off", "1% or more", "a real difference, or over the limit"]
		]));
		if (baseline != null && baseline.length > 0)
		{
			var changes:Array<Array<Dynamic>> = [];
			for (run in runs)
			{
				var base = findRun(baseline, run.key);
				var row:Array<Dynamic> = [run.label];
				for (n in names)
					row.push(findScore(run, n) != null ? changeCell(findScore(run, n), findScore(base, n)) : null);
				changes.push(row);
			}
			doc.add(Html.table(["Renderer"].concat([for (n in names) "change in " + n]), changes, "Change against the baseline",
				"Green: lower than the baseline (better), red: higher; times within 5% are grey."));
			var baseRows:Array<Array<Dynamic>> = [];
			for (base in baseline)
			{
				var row:Array<Dynamic> = [base.label, statusChip(base.status)];
				for (n in names)
				{
					var found = findScore(base, n);
					row.push(found != null ? scoreChip(found) : null);
				}
				baseRows.push(row);
			}
			doc.add(Html.collapsed(Html.table(["Renderer", "Status"].concat(names), baseRows), "Show baseline results", "Hide baseline results",
				baselineNote(baseline)));
		}
		var notes:Array<String> = settings.notes;
		if (notes != null)
			for (n in notes)
				doc.add(Html.callout(Html.escape(n)));

		doc.heading(level, "Environment", id + "-environment");
		doc.add(environmentTable(runs));
		doc.add(Html.table(["Renderer", "Run", "OS", "Haxe", "HashLink"], [
			for (run in runs)
				[run.label, run.date, run.environment.os, run.environment.haxe, run.environment.hashlink]
		]));

		doc.heading(level, "Results", id + "-results");
		for (run in runs)
		{
			doc.heading(level + 1, run.label, anchor(id, run.key));
			var line:Array<Dynamic> = [statusChip(run.status)];
			for (s in run.scores) line.push(scoreChip(s));
			doc.add(Html.table(["Status"].concat([for (s in run.scores) s.name + (s.limit != null ? " (limit " + Html.fixed(s.limit, 2) + ")" : "")]), [line]));
			for (s in run.scores)
				if (s.note != null) doc.add('<p class="note">${Html.escape(s.name)}: ${Html.escape(s.note)}</p>');
			if (run.error != null) doc.add("<pre><code>" + Html.escape(run.error) + "</code></pre>");
			var cards:Array<Array<String>> = [];
			var order:Array<String> = [];
			var byCard = new Map<String, Array<String>>();
			for (image in run.images)
			{
				if (!byCard.exists(image.card))
				{
					byCard.set(image.card, []);
					order.push(image.card);
				}
				var src = prefix + run.key + "/" + image.file;
				byCard.get(image.card).push(Html.figure(src, image.width, image.height, image.caption, image.detail, id + "-" + run.key));
				if (image.note != null) byCard.get(image.card).push(Html.refNote(image.note));
			}
			for (c in order)
				cards.push(byCard.get(c));
			doc.add(Html.gallery(cards));
			for (n in run.notes)
				doc.add(Html.paragraph(n));
			for (t in run.tables)
				doc.add(Html.table(t.columns, t.rows, t.title, t.note));
		}
	}
}
