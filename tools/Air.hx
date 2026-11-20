package;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
	Captures a test's AIR references again (Windows, with an AIR SDK): builds the test for AIR,
	runs it under adl and files what it produced in the test's reference/ folder.

	usage (from the suite folder):  haxe air.hxml <test> [<test> ...] [--adl <adl.exe>]

	adl: --adl, else $ADL, else $AIR_SDK_HOME/bin/adl.exe.

	- A test that is compared with the AIR window (the default) is captured through PrintWindow
	  (tools/air/capture_air_window.ps1) as reference/air[_variant].png, after the app's own
	  BitmapData.draw() of the stage, reference/air[_variant]_draw.png. The window has no system
	  chrome, so the stage sits 1:1 in its top-left corner.
	- A test with "airWindow": false in test.json draws its references itself (bleed, quality,
	  filters): every <test>_air*.png it writes to the user folder is moved to reference/ without
	  the "<test>_" prefix. With "airReference": "draw" the draw() picture is also air.png.

	The plain build is captured, and each variant with "air": true in test.json (a variant whose
	scene differs, such as a transparent stage), with "airTransparent": true for a transparent window.
**/
class Air
{
	static function main()
	{
		var args = Sys.args();
		var adl:String = null;
		var tests:Array<String> = [];
		var i = 0;
		while (i < args.length)
		{
			if (args[i] == "--adl") adl = args[++i];
			else
				tests.push(args[i]);
			i++;
		}
		if (adl == null) adl = Sys.getEnv("ADL");
		if (adl == null && Sys.getEnv("AIR_SDK_HOME") != null) adl = Path.join([Sys.getEnv("AIR_SDK_HOME"), "bin", "adl.exe"]);
		if (Sys.systemName() != "Windows" || adl == null || !FileSystem.exists(adl) || tests.length == 0)
		{
			Sys.println("usage (Windows): haxe air.hxml <test> [...] --adl <adl.exe>   (or set ADL / AIR_SDK_HOME)");
			Sys.exit(2);
		}
		var root = Path.normalize(Sys.getCwd());
		var home = Sys.getEnv("USERPROFILE");
		for (id in tests)
		{
			var folder = Path.join([root, "tests", id]);
			var settings:Dynamic = haxe.Json.parse(File.getContent(Path.join([folder, "test.json"])));
			var runs:Array<Dynamic> = [{suffix: "", defines: []}];
			var variants:Array<Dynamic> = settings.variants != null ? settings.variants : [];
			for (v in variants)
				if (v.air == true) runs.push(v);
			for (run in runs)
			{
				var suffix:String = run.suffix;
				var flags = ["air"];
				var defines:Array<String> = (settings.defines != null ? (settings.defines : Array<String>) : []).concat(run.defines);
				for (d in defines)
					flags.push("-D" + d);
				if (suffix != "") flags.push("-Drendertest_variant=" + suffix.substr(1));
				Sys.println('[$id] AIR$suffix: building');
				if (Sys.command('haxelib run lime build "$folder" ${flags.join(" ")}') != 0)
				{
					Sys.println('[$id] the AIR build failed');
					Sys.exit(1);
				}
				var app = Path.join([folder, "Export", "air"]);
				var descriptor = Path.join([app, "application.xml"]);
				var xml = File.getContent(descriptor);
				xml = StringTools.replace(xml, "<systemChrome>standard</systemChrome>", "<systemChrome>none</systemChrome>");
				if (run.airTransparent == true) xml = StringTools.replace(xml, "<transparent>false</transparent>", "<transparent>true</transparent>");
				File.saveContent(descriptor, xml);
				for (old in FileSystem.readDirectory(home))
					if (StringTools.startsWith(old, id + "_air") && StringTools.endsWith(old, ".png")) FileSystem.deleteFile(Path.join([home, old]));
				var reference = Path.join([folder, "reference"]);
				if (!FileSystem.exists(reference)) FileSystem.createDirectory(reference);
				if (settings.airWindow == false)
				{
					Sys.println('[$id] AIR$suffix: running adl');
					var cwd = Sys.getCwd();
					Sys.setCwd(app);
					Sys.command('call "$adl" application.xml bin');
					Sys.setCwd(cwd);
				}
				else
				{
					Sys.println('[$id] AIR$suffix: running adl and capturing the window');
					var wait = settings.airWait != null ? settings.airWait : 4000;
					Sys.command('powershell -NoProfile -ExecutionPolicy Bypass -File "${Path.join([root, "tools", "air", "capture_air_window.ps1"])}" -Adl "$adl" -AppDir "$app" -Out "${Path.join([reference, "air" + suffix + ".png"])}" -Wait $wait');
				}
				for (made in FileSystem.readDirectory(home))
				{
					if (!StringTools.startsWith(made, id + "_air") || !StringTools.endsWith(made, ".png")) continue;
					var target = Path.join([reference, made.substr(id.length + 1)]);
					File.copy(Path.join([home, made]), target);
					FileSystem.deleteFile(Path.join([home, made]));
					Sys.println('[$id] wrote $target');
				}
				if (settings.airReference == "draw" && FileSystem.exists(Path.join([reference, "air" + suffix + "_draw.png"])))
					File.copy(Path.join([reference, "air" + suffix + "_draw.png"]), Path.join([reference, "air" + suffix + ".png"]));
			}
		}
	}
}
