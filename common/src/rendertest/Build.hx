package rendertest;

#if macro
import haxe.io.Path;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#end

/** What a library was when the test was compiled: its folder, haxelib version, and git state if it is a checkout. **/
typedef Library =
{
	name:String,
	path:String,
	version:String,
	?branch:String,
	?commit:String,
	?commitDate:String,
	?subject:String,
	?describe:String,
	?changedFiles:Int
}

typedef BuildInfo =
{
	projectDir:String,
	testJson:String,
	haxe:String,
	?hashlink:String,
	libraries:Array<Library>
}

/**
	Facts gathered when a test is compiled: the test's folder and test.json, and which openfl
	and lime it was compiled against, so every result says what produced it.
**/
class Build
{
	/** "_t" for a build with -Drendertest_variant=t, "" otherwise. **/
	public static function variantSuffix():String
	{
		#if rendertest_variant
		var v = haxe.macro.Compiler.getDefine("rendertest_variant");
		return (v != null && v != "" && v != "1") ? "_" + v : "";
		#else
		return "";
		#end
	}

	public static macro function info():ExprOf<BuildInfo>
	{
		var main = FileSystem.fullPath(Context.resolvePath("Main.hx"));
		// Source/Main.hx: the project is the folder above
		var projectDir = Path.normalize(Path.join([Path.directory(main), ".."]));
		var testFile = Path.join([projectDir, "test.json"]);
		var testJson = FileSystem.exists(testFile) ? File.getContent(testFile) : "{}";
		if (FileSystem.exists(testFile)) Context.registerModuleDependency(Context.getLocalModule(), testFile);
		var info:BuildInfo = {
			projectDir: projectDir,
			testJson: testJson,
			haxe: haxeVersion(),
			hashlink: Context.definedValue("hl_ver"),
			libraries: [library("openfl", "openfl/display/Sprite.hx"), library("lime", "lime/app/Application.hx")]
		};
		return macro $v{info};
	}

	#if macro
	static function haxeVersion():String
	{
		var v = Context.definedValue("haxe");
		return v != null ? v : Context.definedValue("haxe_ver");
	}

	/** The library that holds `file`: its root (the folder with haxelib.json), version and git state. **/
	static function library(name:String, file:String):Library
	{
		var path:String = null;
		try
		{
			path = Path.directory(FileSystem.fullPath(Context.resolvePath(file)));
		}
		catch (e:Dynamic)
		{
			return {name: name, path: "", version: "not found"};
		}
		var root = path;
		while (root != null && root != "" && !FileSystem.exists(Path.join([root, "haxelib.json"])))
		{
			var up = Path.directory(root);
			if (up == root) root = null;
			else
				root = up;
		}
		if (root == null) root = path;
		var version = "unknown";
		try
		{
			version = haxe.Json.parse(File.getContent(Path.join([root, "haxelib.json"]))).version;
		}
		catch (e:Dynamic) {}
		var lib:Library = {name: name, path: Path.normalize(root), version: version};
		var inside = git(root, ["rev-parse", "--is-inside-work-tree"]);
		if (inside == "true")
		{
			lib.branch = git(root, ["rev-parse", "--abbrev-ref", "HEAD"]);
			lib.commit = git(root, ["rev-parse", "--short=9", "HEAD"]);
			lib.commitDate = git(root, ["log", "-1", "--format=%cs"]);
			lib.subject = git(root, ["log", "-1", "--format=%s"]);
			lib.describe = git(root, ["describe", "--tags", "--always"]);
			var status = git(root, ["status", "--porcelain", "--untracked-files=no"]);
			lib.changedFiles = (status == null || status == "") ? 0 : status.split("\n").length;
			if (lib.branch == "HEAD") lib.branch = "(detached)";
		}
		return lib;
	}

	static function git(dir:String, args:Array<String>):String
	{
		try
		{
			var p = new Process("git", ["-C", dir].concat(args));
			var out = StringTools.trim(p.stdout.readAll().toString());
			var code = p.exitCode();
			p.close();
			return code == 0 ? out : null;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
	#end
}
