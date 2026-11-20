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
	Fill-seam bleed: BleedTestArt (vector elements built from abutting fills on a magenta ground)
	drawn with BitmapData.draw at every stage quality, at scale 1 and 3. A renderer that
	anti-aliases each fill on its own lets the ground show through the shared edges; AIR and
	OpenFL's supersampled Cairo path do not. The variant "nosupersample" is the same build with
	-D openfl_cairo_no_supersample.

	sys targets: renders the eight pictures, scores them (Score.hx) and exits; the HIGH render at
	scale 1 is the run's capture. AIR: writes bleed_air_<quality>_x<scale>.png
	(BitmapData.drawWithQuality) to the user directory, the references, and exits.
**/
class Main extends Sprite
{
	public static var SCALES:Array<Int> = [1, 3];
	public static var QUALITIES:Array<StageQuality> = [StageQuality.LOW, StageQuality.MEDIUM, StageQuality.HIGH, StageQuality.BEST];

	/** The renders of this run by name, e.g. "high_x1". **/
	public static var renders:Map<String, Pixels> = new Map();

	public static function renderName(quality:StageQuality, scale:Int):String
	{
		return Std.string(quality).toLowerCase() + "_x" + scale;
	}

	public function new()
	{
		super();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function onFrame(_):Void
	{
		removeEventListener(Event.ENTER_FRAME, onFrame);
		for (scale in SCALES)
			for (quality in QUALITIES)
			{
				// a fresh scene per render: a shape's Cairo render is kept after its first draw, and the
				// stage quality is read when it renders
				var scene = BleedTestArt.build();
				addChild(scene);
				var bmd = new BitmapData(BleedTestArt.WIDTH * scale, BleedTestArt.HEIGHT * scale, false, BleedTestArt.BACKGROUND);
				var matrix = new Matrix();
				matrix.scale(scale, scale);
				#if flash
				bmd.drawWithQuality(scene, matrix, null, null, null, false, quality);
				var bytes = bmd.encode(bmd.rect, new flash.display.PNGEncoderOptions());
				var fs = new FileStream();
				fs.open(File.userDirectory.resolvePath("bleed_air_" + renderName(quality, scale) + ".png"), FileMode.WRITE);
				fs.writeBytes(bytes);
				fs.close();
				#else
				stage.quality = quality;
				bmd.draw(scene, matrix);
				renders.set(renderName(quality, scale), Pixels.fromImage(bmd.image));
				#end
				removeChild(scene);
			}
		#if flash
		flash.desktop.NativeApplication.nativeApplication.exit();
		#elseif sys
		rendertest.Harness.scoreRender(renders.get("high_x1"), Score.score);
		#end
	}
}
