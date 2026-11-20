package rendertest;

import openfl.display.BitmapData;
import openfl.display.Stage;
#if flash
import flash.desktop.NativeApplication;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
#end

/**
	The end of every test: call capture() once the scene is in the state to compare.

	- sys targets (HashLink, neko, C++): reads what the window shows on the next render, hands it
	  to `score`, writes <results>/<key>/ (capture.png, the scorer's images, results.json) and
	  the test's report.html, prints the scores and exits. <results> is $RENDERTEST_OUT, else the
	  test's own results/ folder.
	  With $RENDERTEST_CAPTURE set to a PNG it scores that file instead of the window, and
	  $RENDERTEST_KEY names the run (default: the target and renderer it was built for).
	- AIR: writes its BitmapData.draw() of the stage to the user directory as
	  <test>_air[_variant]_draw.png and stays up four seconds, for a capture of the window (the
	  reference; see tools/air/capture_air_window.ps1).
**/
/** A test's comparison; under AIR there is nothing to compare, only references to write. **/
typedef Scorer = #if sys TestRun->Void #else Dynamic #end;

class Harness
{
	static var info:Build.BuildInfo = Build.info();

	#if (sys && (hl || neko || cpp))
	/** Ends a test that never gets to its capture: after $RENDERTEST_TIMEOUT seconds (default 60) it exits with code 3. **/
	static var watchdog = {
		var limit = Std.parseFloat(Sys.getEnv("RENDERTEST_TIMEOUT"));
		if (Math.isNaN(limit)) limit = 60;
		sys.thread.Thread.create(function()
		{
			Sys.sleep(limit);
			Sys.println("timed out after " + limit + " s");
			Sys.exit(3);
		});
		true;
	};
	#end

	public static function capture(stage:Stage, score:Scorer, width:Int = 0, height:Int = 0):Void
	{
		#if flash
		var settings:Dynamic = haxe.Json.parse(info.testJson);
		var id:String = settings.id != null ? settings.id : "test";
		// as the window starts: the stage colour, or nothing for a transparent window
		var transparent = stage.nativeWindow != null && stage.nativeWindow.transparent;
		var bmd = new BitmapData(width > 0 ? width : stage.stageWidth, height > 0 ? height : stage.stageHeight, transparent,
			transparent ? 0 : 0xFF000000 | stage.color);
		bmd.draw(stage);
		var bytes = bmd.encode(bmd.rect, new flash.display.PNGEncoderOptions());
		var fs = new FileStream();
		fs.open(File.userDirectory.resolvePath(id + "_air" + Build.variantSuffix() + "_draw.png"), FileMode.WRITE);
		fs.writeBytes(bytes);
		fs.close();
		haxe.Timer.delay(function() NativeApplication.nativeApplication.exit(), 4000);
		#elseif sys
		// RENDERTEST_CAPTURE: score a saved capture instead of the window (to rescore, or to check a scorer)
		var saved = Sys.getEnv("RENDERTEST_CAPTURE");
		if (saved != null && saved != "")
		{
			Sys.exit(finish(Pixels.load(saved), score));
			return;
		}
		var done = false;
		stage.window.onRender.add(function(_)
		{
			if (done) return;
			done = true;
			var image = stage.window.readPixels();
			var pixels = Pixels.fromImage(image);
			if (width > 0 && height > 0 && (pixels.width > width || pixels.height > height)) pixels = pixels.crop(0, 0, width, height);
			Sys.exit(finish(pixels, score));
		});
		stage.invalidate();
		#end
	}

	#if sys
	/**
		For a test that renders offscreen (BitmapData.draw) instead of capturing the window: scores
		`pixels` as the capture and exits. The scorer can use any other renders the test kept.
	**/
	public static function scoreRender(pixels:Pixels, score:TestRun->Void):Void
	{
		var saved = Sys.getEnv("RENDERTEST_CAPTURE");
		Sys.exit(finish(saved != null && saved != "" ? Pixels.load(saved) : pixels, score));
	}

	/** Scores a capture and writes everything; returns the exit code (0 pass or info, 1 fail, 2 error). **/
	public static function finish(pixels:Pixels, score:TestRun->Void):Int
	{
		var run = new TestRun(info, pixels, Sys.systemName());
		mkdirs(run.runDir);
		for (old in sys.FileSystem.readDirectory(run.runDir))
			if (StringTools.endsWith(old, ".png") || old == "results.json") sys.FileSystem.deleteFile(haxe.io.Path.join([run.runDir, old]));
		// with alpha: a transparent window's capture keeps what it has
		pixels.save(haxe.io.Path.join([run.runDir, "capture.png"]), true);
		run.results.images.push({
			file: "capture.png",
			caption: run.label,
			width: pixels.width,
			height: pixels.height,
			card: "capture"
		});
		var error:String = null;
		try
		{
			score(run);
		}
		catch (e:Dynamic)
		{
			error = Std.string(e) + "\n" + haxe.CallStack.toString(haxe.CallStack.exceptionStack());
		}
		var results = run.finish(error);
		TestReport.write(run.resultsDir, run.settings);
		var line = [for (s in results.scores) s.name + " " + Html.scoreText(s.value, s.unit)].join(", ");
		Sys.println('${run.test} ${run.key}: ${results.status}${line != "" ? " (" + line + ")" : ""}${error != null ? "\n" + error : ""}');
		Sys.println("report: " + haxe.io.Path.join([run.resultsDir, "report.html"]));
		return switch (results.status)
		{
			case Results.FAIL: 1;
			case Results.ERROR: 2;
			default: 0;
		}
	}

	static function mkdirs(dir:String):Void
	{
		if (!sys.FileSystem.exists(dir)) sys.FileSystem.createDirectory(dir);
	}
	#end
}
