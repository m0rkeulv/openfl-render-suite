package;

import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.StageQuality;
import openfl.events.Event;
import openfl.geom.Matrix;
import rendertest.Pixels;
#if flash
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.filesystem.FileStream;
#end

/**
	Stage quality: the scene (Scene.hx) drawn with BitmapData.draw at LOW, MEDIUM, HIGH and BEST,
	each compared with AIR's drawWithQuality at the same quality. OpenFL's Cairo renderer
	supersamples vector art by the stage quality; AIR anti-aliases by it.

	sys targets: renders the four pictures, scores them (Score.hx) and exits; the HIGH render is
	the run's capture. AIR: writes quality_air_<quality>.png to the user directory, the
	references, and exits.
**/
class Main extends Sprite
{
	public static var QUALITIES:Array<StageQuality> = [StageQuality.LOW, StageQuality.MEDIUM, StageQuality.HIGH, StageQuality.BEST];

	/** The renders of this run by quality name ("low" ... "best"). **/
	public static var renders:Map<String, Pixels> = new Map();

	public function new()
	{
		super();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		removeEventListener(Event.ENTER_FRAME, onFrame);
		for (quality in QUALITIES)
		{
			// a fresh scene per render: a shape's Cairo render is kept after its first draw
			var scene = Scene.buildScene();
			addChild(scene);
			var bmd = new BitmapData(Scene.W, Scene.H, false, Scene.BG);
			var name = Std.string(quality).toLowerCase();
			#if flash
			bmd.drawWithQuality(scene, new Matrix(), null, null, null, false, quality);
			var bytes = bmd.encode(bmd.rect, new flash.display.PNGEncoderOptions());
			var fs = new FileStream();
			fs.open(File.userDirectory.resolvePath("quality_air_" + name + ".png"), FileMode.WRITE);
			fs.writeBytes(bytes);
			fs.close();
			#else
			stage.quality = quality;
			bmd.draw(scene, new Matrix());
			renders.set(name, Pixels.fromImage(bmd.image));
			#end
			removeChild(scene);
		}
		#if flash
		flash.desktop.NativeApplication.nativeApplication.exit();
		#elseif sys
		rendertest.Harness.scoreRender(renders.get("high"), Score.score);
		#end
	}
}
