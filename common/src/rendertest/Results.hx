package rendertest;

/** One number of a run: lower is better, 0 is a match with the reference. **/
typedef Score =
{
	name:String,
	value:Float,
	unit:String,
	?note:String,
	?limit:Float
}

typedef Table =
{
	title:String,
	columns:Array<String>,
	rows:Array<Array<Dynamic>>,
	?note:String
}

/** An image of a run, in the run's folder; images with the same card are shown side by side. **/
typedef ImageEntry =
{
	file:String,
	caption:String,
	width:Int,
	height:Int,
	card:String,
	?detail:String,
	?note:String
}

typedef Environment =
{
	haxe:String,
	?hashlink:String,
	os:String,
	libraries:Array<Build.Library>
}

/**
	What one run of a test wrote to <results>/<key>/results.json: one test, one renderer (the key,
	e.g. hl_cairo or hl_opengl_t for a variant). The test report and the suite report are built
	from these files alone.
**/
typedef RunResults =
{
	test:String,
	title:String,
	key:String,
	label:String,
	status:String,
	date:String,
	environment:Environment,
	scores:Array<Score>,
	tables:Array<Table>,
	images:Array<ImageEntry>,
	notes:Array<String>,
	?error:String,
	?seconds:Float
}

class Results
{
	public static inline var PASS = "pass";
	public static inline var FAIL = "fail";
	/** Scored, but the test sets no limit for the score. **/
	public static inline var INFO = "info";
	public static inline var ERROR = "error";

	static var RENDERERS = [
		"hl_opengl" => "HashLink OpenGL",
		"hl_cairo" => "HashLink Cairo",
		"neko_cairo" => "neko Cairo",
		"neko_opengl" => "neko OpenGL",
		"cpp_opengl" => "C++ OpenGL",
		"cpp_cairo" => "C++ Cairo",
		"html5_webgl" => "WebGL",
		"html5_canvas" => "Canvas 2D",
		"air" => "AIR"
	];

	/** The reader's name of a run key: hl_cairo_t is "HashLink Cairo, t" unless the test names its variants. **/
	public static function label(key:String, ?variants:Array<Dynamic>):String
	{
		for (renderer in RENDERERS.keys())
		{
			if (key == renderer) return RENDERERS.get(renderer);
			if (StringTools.startsWith(key, renderer + "_"))
			{
				var suffix = key.substr(renderer.length);
				var name = suffix.substr(1);
				if (variants != null)
					for (v in variants)
						if (v.suffix == suffix && v.label != null) name = v.label;
				return RENDERERS.get(renderer) + ", " + name;
			}
		}
		return key;
	}

	/** The renderer of a run key without its variant: hl_cairo for hl_cairo_t. **/
	public static function renderer(key:String):String
	{
		var parts = key.split("_");
		return parts.length >= 2 ? parts[0] + "_" + parts[1] : key;
	}

	/** error over fail over info over pass: the status of several runs together. **/
	public static function worst(statuses:Array<String>):String
	{
		var rank = [PASS => 0, INFO => 1, FAIL => 2, ERROR => 3];
		var result = PASS;
		for (s in statuses)
			if (rank.get(s) > rank.get(result)) result = s;
		return result;
	}

	/** The order renderers are listed in: OpenGL, Cairo, neko, others; variants after their renderer. **/
	public static function order(key:String):Int
	{
		var i = 0;
		for (renderer in ["hl_opengl", "hl_cairo", "neko_cairo", "neko_opengl", "cpp_opengl", "cpp_cairo", "html5_webgl", "html5_canvas"])
		{
			if (key == renderer) return i * 100;
			if (StringTools.startsWith(key, renderer + "_")) return i * 100 + 1 + key.length;
			i++;
		}
		return 10000;
	}

	/** "openfl castlewars/prod 882531d1b (9.5.2, 2 changed files)": a library in one line. **/
	public static function describe(lib:Build.Library):String
	{
		if (lib.commit == null) return '${lib.version} (haxelib release)';
		var changed = lib.changedFiles != null && lib.changedFiles > 0 ? ', ${lib.changedFiles} changed file${lib.changedFiles == 1 ? "" : "s"}' : "";
		return '${lib.branch} ${lib.commit} (${lib.version}$changed)';
	}

	#if sys
	public static function load(path:String):RunResults
	{
		return haxe.Json.parse(sys.io.File.getContent(path));
	}

	public static function save(path:String, results:RunResults):Void
	{
		sys.io.File.saveContent(path, haxe.Json.stringify(results, null, " "));
	}

	/** Every run under a test's results folder, in renderer order. **/
	public static function runs(dir:String):Array<RunResults>
	{
		var list = [];
		if (!sys.FileSystem.exists(dir)) return list;
		for (name in sys.FileSystem.readDirectory(dir))
		{
			var file = haxe.io.Path.join([dir, name, "results.json"]);
			if (sys.FileSystem.exists(file))
			{
				try
				{
					list.push(load(file));
				}
				catch (e:Dynamic) {}
			}
		}
		list.sort(function(a, b) return order(a.key) - order(b.key));
		return list;
	}
	#end
}
