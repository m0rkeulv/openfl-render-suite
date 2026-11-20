package;

import haxe.io.Path;
import rendertest.Results;
import rendertest.SuiteReport;
import rendertest.TestReport;
import sys.FileSystem;
import sys.io.File;

/**
	Builds, runs and reports the render tests in tests/: every test on every renderer it lists
	(test.json "renderers") and in every variant (test.json "variants"). Works the same on
	Windows, Linux and macOS; it needs only Haxe, haxelib, lime and openfl.

	usage (from the suite folder):  haxe run.hxml [test ...] [options]

	  --renderers a,b     only these renderers (hl_opengl, hl_cairo, neko_cairo, cpp_opengl, ...)
	  --skip a,b          leave these tests out
	  --out DIR           where the results and reports go (default: results)
	  --openfl DIR        build against this openfl checkout instead of the current haxelib
	  --lime DIR          the same for lime
	  -D NAME[=VALUE]     an extra define for every build
	  --timeout SECONDS   a run that has not captured by then is stopped (default 60)
	  --visible           Cairo runs open a window (default: SDL's dummy video driver, no window)
	  --baseline DIR      another build's results folder: the reports show the change against it
	                      (e.g. a run with --openfl <develop checkout> --out results-develop)
	  --report-only       rebuild the reports from the results already in --out
	  --strict            exit with 1 when a run fails its limits (errors always exit with 2)
	  --summary FILE      also write the result table as Markdown (e.g. $GITHUB_STEP_SUMMARY);
	                      $RENDERTEST_SUMMARY_TITLE is its heading
	  --list              list the tests and their renderers

	Writes <out>/<test>/<renderer>/ (capture, images, results.json, logs), <out>/<test>/report.html
	and <out>/index.html.
**/
class Suite
{
	static var root:String;
	static var out:String;
	static var defines:Array<String> = [];
	static var timeout = 60;
	static var visible = false;
	static var baseline:String = null;
	static var summary:String = null;

	static function main()
	{
		var args = Sys.args();
		root = Path.normalize(Sys.getCwd());
		if (!FileSystem.exists(Path.join([root, "tests"])))
		{
			Sys.println("run from the suite folder: haxe run.hxml [test ...] [options]");
			Sys.exit(2);
		}
		var only:Array<String> = null;
		var reportOnly = false, strict = false, list = false;
		var tests:Array<String> = [];
		var skip:Array<String> = [];
		out = Path.join([root, "results"]);
		var i = 0;
		while (i < args.length)
		{
			var a = args[i];
			switch (a)
			{
				case "--skip":
					skip = args[++i].split(",");
				case "--renderers":
					only = args[++i].split(",");
				case "--out":
					out = absolute(args[++i]);
				case "--openfl":
					defines.push("-DRENDERTEST_OPENFL=" + absolute(args[++i]));
				case "--lime":
					defines.push("-DRENDERTEST_LIME=" + absolute(args[++i]));
				case "-D":
					defines.push("-D" + args[++i]);
				case "--timeout":
					timeout = Std.parseInt(args[++i]);
				case "--visible":
					visible = true;
				case "--summary":
					summary = args[++i];
				case "--baseline":
					baseline = absolute(args[++i]);
				case "--report-only":
					reportOnly = true;
				case "--strict":
					strict = true;
				case "--list":
					list = true;
				default:
					if (StringTools.startsWith(a, "-D") && a.length > 2) defines.push(a);
					else if (StringTools.startsWith(a, "-"))
					{
						Sys.println("unknown option " + a);
						Sys.exit(2);
					}
					else
						tests.push(a);
			}
			i++;
		}

		var all = discover();
		for (t in tests)
			if (![for (s in all) s.id].contains(t))
			{
				Sys.println("unknown test " + t + "; known: " + [for (s in all) s.id].join(", "));
				Sys.exit(2);
			}
		var chosen = [for (s in all) if ((tests.length == 0 || tests.contains(s.id)) && !skip.contains(s.id)) s];

		if (list)
		{
			for (s in chosen)
				Sys.println(StringTools.rpad(s.id, " ", 16) + plan(s, only).map(p -> p.key).join(", "));
			return;
		}

		mkdirs(out);
		var failed = 0, errors = 0;
		if (!reportOnly)
		{
			for (s in chosen)
			{
				var dir:String = Path.join([out, s.id]);
				mkdirs(dir);
				for (p in plan(s, only))
				{
					var status = runOne(s, p);
					if (status == Results.FAIL) failed++;
					if (status == Results.ERROR) errors++;
				}
				TestReport.write(dir, s, baselineFor(s.id));
			}
		}
		var index = writeReports(all);
		Sys.println("suite report: " + index);
		if (errors > 0) Sys.exit(2);
		if (strict && failed > 0) Sys.exit(1);
	}

	/** Every tests/<id>/test.json, with the folder it is in. **/
	static function discover():Array<Dynamic>
	{
		var list:Array<Dynamic> = [];
		var testsDir = Path.join([root, "tests"]);
		var names = FileSystem.readDirectory(testsDir);
		names.sort(Reflect.compare);
		for (name in names)
		{
			var file = Path.join([testsDir, name, "test.json"]);
			if (!FileSystem.exists(file)) continue;
			var settings:Dynamic = haxe.Json.parse(File.getContent(file));
			if (settings.id == null) settings.id = name;
			settings.folder = Path.join([testsDir, name]);
			list.push(settings);
		}
		return list;
	}

	/** The runs of a test: each renderer, in each variant (the plain build first). **/
	static function plan(settings:Dynamic, only:Array<String>):Array<{key:String, renderer:String, variant:Dynamic}>
	{
		var renderers:Array<String> = settings.renderers != null ? settings.renderers : ["hl_opengl", "hl_cairo"];
		var variants:Array<Dynamic> = settings.variants != null ? settings.variants : [];
		var runs = [];
		var all:Array<Dynamic> = settings.plainRun == false ? [] : [null];
		for (v in variants)
			all.push(v);
		for (v in all)
		{
			var list:Array<String> = (v != null && v.renderers != null) ? v.renderers : renderers;
			for (r in list)
			{
				if (only != null && !only.contains(r)) continue;
				runs.push({key: r + (v != null ? v.suffix : ""), renderer: r, variant: v});
			}
		}
		return runs;
	}

	static function runOne(settings:Dynamic, p:{key:String, renderer:String, variant:Dynamic}):String
	{
		var id:String = settings.id;
		var folder:String = settings.folder;
		var parts = p.renderer.split("_");
		var target = parts[0];
		var software = parts[1] == "cairo";
		var dir = Path.join([out, id]);
		var runDir = Path.join([dir, p.key]);
		mkdirs(runDir);
		var flags = [target].concat(defines);
		var testDefines:Array<String> = settings.defines != null ? settings.defines : [];
		for (d in testDefines)
			flags.push("-D" + d);
		if (software) flags.push("-Dsoftware");
		if (p.variant != null)
		{
			flags.push("-Drendertest_variant=" + (p.variant.suffix : String).substr(1));
			var extra:Array<String> = p.variant.defines != null ? p.variant.defines : [];
			for (d in extra)
				flags.push("-D" + d);
		}
		var started = Sys.time();
		Sys.println('[$id] ${p.key}: building');
		var buildLog = Path.join([runDir, "build.log"]);
		var code = Sys.command('haxelib run lime build ${quote(folder)} ${flags.join(" ")} > ${quote(buildLog)} 2>&1');
		if (code != 0) return error(settings, p.key, "the build failed (exit code " + code + ")", buildLog);

		var exe = findExecutable(Path.join([folder, "Export", target, "bin"]), appFile(folder));
		if (exe == null) return error(settings, p.key, "no executable in Export/" + target + "/bin after the build", buildLog);
		var resultsFile = Path.join([runDir, "results.json"]);
		if (FileSystem.exists(resultsFile)) FileSystem.deleteFile(resultsFile);
		Sys.putEnv("RENDERTEST_OUT", dir);
		var limit:Int = settings.timeout != null ? settings.timeout : timeout;
		Sys.putEnv("RENDERTEST_TIMEOUT", Std.string(limit));
		Sys.putEnv("SDL_VIDEODRIVER", software && !visible ? "dummy" : "");
		var runLog = Path.join([runDir, "run.log"]);
		Sys.println('[$id] ${p.key}: running');
		var cwd = Sys.getCwd();
		Sys.setCwd(Path.directory(exe));
		code = Sys.command((Sys.systemName() == "Windows" ? "call " : "") + '${quote(exe)} > ${quote(runLog)} 2>&1');
		Sys.setCwd(cwd);
		Sys.putEnv("SDL_VIDEODRIVER", "");
		if (!FileSystem.exists(resultsFile))
		{
			var why = code == 3 ? 'the run timed out after $limit s' : "the run ended with exit code " + code + " and wrote no results";
			return error(settings, p.key, why, runLog);
		}
		var results = Results.load(resultsFile);
		results.seconds = Math.round((Sys.time() - started) * 10) / 10;
		Results.save(resultsFile, results);
		Sys.println('[$id] ${p.key}: ${results.status} ' + [for (s in results.scores) s.name + " " + s.value + (s.unit == "%" || s.unit == "" ? s.unit : " " + s.unit)].join(", "));
		return results.status;
	}

	/** Records a run that produced no results, with the end of its log. **/
	static function error(settings:Dynamic, key:String, why:String, log:String):String
	{
		var tail = "";
		if (FileSystem.exists(log))
		{
			var lines = File.getContent(log).split("\n");
			tail = lines.slice(Std.int(Math.max(0, lines.length - 40))).join("\n");
		}
		var dir = Path.join([out, settings.id, key]);
		var variants:Array<Dynamic> = settings.variants;
		Results.save(Path.join([dir, "results.json"]), {
			test: settings.id,
			title: settings.title != null ? settings.title : settings.id,
			key: key,
			label: Results.label(key, variants),
			status: Results.ERROR,
			date: DateTools.format(Date.now(), "%Y-%m-%d %H:%M:%S"),
			environment: {haxe: "", os: Sys.systemName(), libraries: []},
			scores: [],
			tables: [],
			images: [],
			notes: [],
			error: why + " (" + Path.withoutDirectory(log) + "):\n" + tail
		});
		Sys.println('[${settings.id}] $key: error: $why, see $log');
		return Results.ERROR;
	}

	static function writeReports(all:Array<Dynamic>):String
	{
		var tests:Array<SuiteTest> = [];
		for (s in all)
		{
			var dir = Path.join([out, s.id]);
			if (!FileSystem.exists(dir)) continue;
			var base = baselineFor(s.id);
			TestReport.write(dir, s, base);
			tests.push({settings: s, dir: s.id, runs: Results.runs(dir), baseline: base != null ? Results.runs(base) : null});
		}
		var groupsFile = Path.join([root, "tests", "groups.json"]);
		var groups:Array<Dynamic> = FileSystem.exists(groupsFile) ? haxe.Json.parse(File.getContent(groupsFile)) : [];
		var index = Path.join([out, "index.html"]);
		File.saveContent(index, SuiteReport.build(tests, groups));
		if (summary != null)
		{
			var link = Sys.getEnv("RENDERTEST_REPORT_LINK");
			var title = Sys.getEnv("RENDERTEST_SUMMARY_TITLE");
			var text = SuiteReport.markdown(tests, groups, link != null && link != "" ? link : null,
				title != null && title != "" ? title : "OpenFL render tests");
			// GitHub appends to the job summary file; elsewhere the file is written anew
			var output = sys.io.File.append(summary, false);
			output.writeString(text);
			output.close();
		}
		return index;
	}

	/** The test's folder in the baseline results, if there is one. **/
	static function baselineFor(id:String):String
	{
		if (baseline == null) return null;
		var dir = Path.join([baseline, id]);
		return FileSystem.exists(dir) ? dir : null;
	}

	/** <app file="..."> of a project.xml. **/
	static function appFile(folder:String):String
	{
		var xml = File.getContent(Path.join([folder, "project.xml"]));
		var r = ~/<app[^>]*file="([^"]+)"/;
		return r.match(xml) ? r.matched(1) : "Main";
	}

	/** bin/<file>.exe (Windows), bin/<file> (Linux), or <file>.app/Contents/MacOS/<file> (macOS). **/
	static function findExecutable(bin:String, file:String):String
	{
		for (candidate in [file + ".exe", file, file + ".app/Contents/MacOS/" + file])
		{
			var path = Path.join([bin, candidate]);
			if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return path;
		}
		return null;
	}

	static function quote(path:String):String
	{
		return '"' + path + '"';
	}

	static function absolute(path:String):String
	{
		return Path.normalize(FileSystem.absolutePath(path));
	}

	static function mkdirs(dir:String):Void
	{
		if (!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
	}
}
