package rendertest;

import haxe.io.Path;
import rendertest.Results;

/**
	One run of a test on one renderer, as its scorer sees it: the capture, the references, and
	the calls that record tables, scores and images. The harness saves everything to
	<results>/<key>/ when the scorer returns.

		function score(run:TestRun):Void
		{
			var air = run.reference("air");
			var d = Compare.whole(run.capture, air, 8);
			run.score("pixels off", d.off);
			run.image("mask", Compare.mask(run.capture, air, 8), "Pixels off against AIR", "capture");
		}
**/
class TestRun
{
	/** The test's id (test.json, else the project folder's name). **/
	public var test(default, null):String;
	/** hl_opengl, hl_cairo, neko_cairo, ... with "_<variant>" for a variant build. **/
	public var key(default, null):String;
	/** The reader's name of the key, e.g. "HashLink Cairo". **/
	public var label(default, null):String;
	/** "_t" for variant t, "" otherwise. **/
	public var variant(default, null):String;
	/** What the window showed. **/
	public var capture(default, null):Pixels;
	/** test.json, parsed. **/
	public var settings(default, null):Dynamic;

	public var results(default, null):RunResults;

	public var resultsDir(default, null):String;
	public var runDir(default, null):String;
	public var referenceDir(default, null):String;

	public function new(info:Build.BuildInfo, capture:Pixels, os:String)
	{
		settings = haxe.Json.parse(info.testJson);
		test = settings.id != null ? settings.id : Path.withoutDirectory(info.projectDir);
		variant = TestRun.variantSuffix();
		var named = env("RENDERTEST_KEY");
		key = (named != null && named != "") ? named : target() + variant;
		var variants:Array<Dynamic> = settings.variants;
		label = Results.label(key, variants);
		this.capture = capture;
		var out = env("RENDERTEST_OUT");
		resultsDir = (out != null && out != "") ? out : Path.join([info.projectDir, "results"]);
		runDir = Path.join([resultsDir, key]);
		var refs = env("RENDERTEST_REFERENCE");
		referenceDir = (refs != null && refs != "") ? refs : Path.join([info.projectDir, "reference"]);
		results = {
			test: test,
			title: settings.title != null ? settings.title : test,
			key: key,
			label: label,
			status: Results.INFO,
			date: DateTools.format(Date.now(), "%Y-%m-%d %H:%M:%S"),
			environment: {
				haxe: info.haxe,
				hashlink: info.hashlink,
				os: os,
				libraries: info.libraries
			},
			scores: [],
			tables: [],
			images: [],
			notes: []
		};
	}

	/** An environment variable; there are none under AIR, where a test only writes its references. **/
	static function env(name:String):String
	{
		return #if sys Sys.getEnv(name) #else null #end;
	}

	/** hl_opengl, hl_cairo, neko_cairo, cpp_opengl, ...: the target and renderer this was compiled for. **/
	public static function target():String
	{
		var renderer = #if software "cairo" #else "opengl" #end;
		#if hl
		return "hl_" + renderer;
		#elseif neko
		return "neko_" + renderer;
		#elseif cpp
		return "cpp_" + renderer;
		#else
		return "other_" + renderer;
		#end
	}

	public static inline function variantSuffix():String
	{
		return Build.variantSuffix();
	}

	/**
		A reference image from the test's reference folder: `name` with the variant's suffix if that
		file exists (air_t.png for variant t; air_t_draw.png for air_draw), else `name` itself. It is copied into the run's folder
		and shown in the report as the first card.
	**/
	public function reference(name:String = "air", ?caption:String, ?note:String):Pixels
	{
		#if sys
		// air_draw for variant t: air_draw_t.png, air_t_draw.png (AIR's own naming), then air_draw.png
		var candidates = [name + variant];
		if (variant != "" && StringTools.startsWith(name, "air_")) candidates.push("air" + variant + name.substr(3));
		candidates.push(name);
		var file:String = null;
		for (c in candidates)
			if (file == null && sys.FileSystem.exists(Path.join([referenceDir, c + ".png"]))) file = Path.join([referenceDir, c + ".png"]);
		if (file == null) throw 'no reference image $name in $referenceDir';
		var pixels = Pixels.load(file);
		var saved = "reference_" + Path.withoutDirectory(file);
		sys.io.File.copy(file, Path.join([runDir, saved]));
		var known = false;
		for (i in results.images)
			if (i.file == saved) known = true;
		if (!known)
			results.images.unshift({
				file: saved,
				caption: caption != null ? caption : (name == "air" ? "AIR (reference)" : name),
				width: pixels.width,
				height: pixels.height,
				card: "reference " + name,
				note: note
			});
		return pixels;
		#else
		throw "references are read on sys targets only";
		#end
	}

	/** Saves `pixels` as <name>.png in the run's folder; images with the same `card` are shown together. **/
	public function image(name:String, pixels:Pixels, caption:String, ?card:String, ?detail:String):Void
	{
		var file = name + ".png";
		#if sys
		pixels.save(Path.join([runDir, file]));
		#end
		results.images.push({
			file: file,
			caption: caption,
			width: pixels.width,
			height: pixels.height,
			card: card != null ? card : name,
			detail: detail
		});
	}

	/** A table for the report; cells as in Html (String, number, null, or Html.value / Html.percent). **/
	public function table(title:String, columns:Array<String>, rows:Array<Array<Dynamic>>, ?note:String):Void
	{
		results.tables.push({title: title, columns: columns, rows: rows, note: note});
	}

	/** A summary number of this run: lower is better, 0 is a match. test.json may set a limit for it. **/
	public function score(name:String, value:Float, unit:String = "%", ?note:String):Void
	{
		results.scores.push({
			name: name,
			value: Html.round(value, 3),
			unit: unit,
			note: note,
			limit: limitFor(name)
		});
	}

	public function note(text:String):Void
	{
		results.notes.push(text);
	}

	/** test.json "limits": {"<score>": max} for every renderer, or {"<key>": {"<score>": max}} for one. **/
	function limitFor(name:String):Null<Float>
	{
		var limits:Dynamic = settings.limits;
		if (limits == null) return null;
		var own:Dynamic = Reflect.field(limits, key);
		if (own != null && Reflect.hasField(own, name)) return Reflect.field(own, name);
		var plain = target();
		own = Reflect.field(limits, plain);
		if (own != null && Reflect.hasField(own, name)) return Reflect.field(own, name);
		if (Reflect.hasField(limits, name))
		{
			var v:Dynamic = Reflect.field(limits, name);
			if (Std.isOfType(v, Float) || Std.isOfType(v, Int)) return v;
		}
		return null;
	}

	/** pass when every score with a limit is within it, fail when one is over, info when no score has a limit. **/
	public function finish(?error:String):RunResults
	{
		if (error != null)
		{
			results.status = Results.ERROR;
			results.error = error;
		}
		else
		{
			var limited = false, over = false;
			for (s in results.scores)
			{
				if (s.limit == null) continue;
				limited = true;
				if (s.value > s.limit) over = true;
			}
			results.status = over ? Results.FAIL : (limited ? Results.PASS : Results.INFO);
		}
		#if sys
		Results.save(Path.join([runDir, "results.json"]), results);
		#end
		return results;
	}
}
