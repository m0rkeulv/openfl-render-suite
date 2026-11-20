package;

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.filters.BevelFilter;
import openfl.filters.BitmapFilter;
import openfl.filters.BitmapFilterType;
import openfl.filters.BlurFilter;
import openfl.filters.DropShadowFilter;
import openfl.filters.GlowFilter;
import openfl.geom.Point;
import openfl.text.TextField;
import rendertest.Optional;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import rendertest.Harness;

typedef SweepCase =
{
	family:String,
	label:String,
	/** The filter, or null where this openfl lacks its class (rendertest.Optional). **/
	make:Void->BitmapFilter,
	?circle:Bool
}

/**
	Filter parameter sweep: every filter at several quality, distance, strength, angle and alpha
	settings, plus two circle subjects with anti-aliased edges. Each case renders twice: a live
	vector Shape carrying the filter (the renderer's filter path, the GPU one on OpenGL), and
	BitmapData.applyFilter on a bitmap drawn from the same shape (the software path), 40 px to
	its right. On AIR both are the reference.

	The full stage is 1290 x 3340, too tall for a window, so a build with -Drendertest_variant=pN
	(the variants p0 to p3) shows cases 12N to 12N + 11, laid out like the first four rows of the
	full stage, in a 1290 x 930 window. A build without it lays out every case (the AIR reference).
	Captured on frame 10 and scored by Score.hx.
**/
class Main extends Sprite
{
	public static inline var W = 1290;
	public static inline var H = 3340;
	public static inline var PAGE_H = 930;
	public static inline var PER_PAGE = 12;
	public static inline var CELL = 160;
	static inline var BG = 0xB0B0B0;
	static inline var COLOUR = 0x2040E0;
	static inline var BOX = 60;

	static var GRADIENT_COLOURS = [0xFF00FF, 0xFFFF00, 0x00FFFF];
	static var GRADIENT_ALPHAS = [1.0, 1.0, 1.0];
	static var GRADIENT_RATIOS = [0, 128, 255];

	public static var CASES:Array<SweepCase> = [
		{family: "blur", label: "blur 4 q1", make: () -> new BlurFilter(4, 4, 1)},
		{family: "blur", label: "blur 16 q1", make: () -> new BlurFilter(16, 16, 1)},
		{family: "blur", label: "blur 16 q3", make: () -> new BlurFilter(16, 16, 3)},
		{family: "blur", label: "blur 40 q2", make: () -> new BlurFilter(40, 40, 2)},
		{family: "blur", label: "blur x24 y0 q1", make: () -> new BlurFilter(24, 0, 1)},
		{family: "glow", label: "glow q1 s1", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 1, 1, false, false)},
		{family: "glow", label: "glow q3 s1", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 1, 3, false, false)},
		{family: "glow", label: "glow q1 s4", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 4, 1, false, false)},
		{family: "glow", label: "glow q3 s4", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 4, 3, false, false)},
		{family: "glow", label: "glow inner q3 s2", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 2, 3, true, false)},
		{family: "glow", label: "glow knockout q3 s4", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 4, 3, false, true)},
		{family: "glow", label: "glow orange a=0.5 q2 s2", make: () -> new GlowFilter(0xFF8000, 0.5, 12, 12, 2, 2, false, false)},
		{family: "shadow", label: "shadow d4 q1 s1", make: () -> new DropShadowFilter(4, 45, 0x000000, 1, 8, 8, 1, 1)},
		{family: "shadow", label: "shadow d12 q1 s1", make: () -> new DropShadowFilter(12, 45, 0x000000, 1, 8, 8, 1, 1)},
		{family: "shadow", label: "shadow d4 q3 s1", make: () -> new DropShadowFilter(4, 45, 0x000000, 1, 8, 8, 1, 3)},
		{family: "shadow", label: "shadow d12 q3 s3", make: () -> new DropShadowFilter(12, 45, 0x000000, 1, 8, 8, 3, 3)},
		{family: "shadow", label: "shadow inner d6 q3 s1", make: () -> new DropShadowFilter(6, 45, 0x000000, 1, 8, 8, 1, 3, true)},
		{family: "shadow", label: "shadow green a=0.5 d6 q2", make: () -> new DropShadowFilter(6, 45, 0x40C040, 0.5, 8, 8, 1, 2)},
		{family: "shadow", label: "shadow angle 200 d10 q2", make: () -> new DropShadowFilter(10, 200, 0x000000, 1, 8, 8, 1, 2)},
		{family: "bevel", label: "bevel d2 q1 s1", make: () -> new BevelFilter(2, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 1, 1, BitmapFilterType.INNER)},
		{family: "bevel", label: "bevel d8 q1 s1", make: () -> new BevelFilter(8, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 1, 1, BitmapFilterType.INNER)},
		{family: "bevel", label: "bevel d8 q3 s1", make: () -> new BevelFilter(8, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 1, 3, BitmapFilterType.INNER)},
		{family: "bevel", label: "bevel d4 q3 s3", make: () -> new BevelFilter(4, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 3, 3, BitmapFilterType.INNER)},
		{family: "bevel", label: "bevel outer d4 q2 s1", make: () -> new BevelFilter(4, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 1, 2, BitmapFilterType.OUTER)},
		{family: "bevel", label: "bevel full d4 q2 s2", make: () -> new BevelFilter(4, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 2, 2, BitmapFilterType.FULL)},
		{family: "bevel", label: "bevel angle 135 d6 q2", make: () -> new BevelFilter(6, 135, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 1, 2, BitmapFilterType.INNER)},
		{family: "gradientGlow", label: "gGlow d0 q1 s1", make: () -> Optional.filter("openfl.filters.GradientGlowFilter", 0, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 16, 16, 1, 1, BitmapFilterType.OUTER, false)},
		{family: "gradientGlow", label: "gGlow d6 q3 s1", make: () -> Optional.filter("openfl.filters.GradientGlowFilter", 6, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 16, 16, 1, 3, BitmapFilterType.OUTER, false)},
		{family: "gradientGlow", label: "gGlow d6 q1 s2", make: () -> Optional.filter("openfl.filters.GradientGlowFilter", 6, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 16, 16, 2, 1, BitmapFilterType.OUTER, false)},
		{family: "gradientGlow", label: "gGlow inner d0 q3 s1", make: () -> Optional.filter("openfl.filters.GradientGlowFilter", 0, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 16, 16, 1, 3, BitmapFilterType.INNER, false)},
		{family: "gradientGlow", label: "gGlow full d6 q2 s1", make: () -> Optional.filter("openfl.filters.GradientGlowFilter", 6, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 16, 16, 1, 2, BitmapFilterType.FULL, false)},
		{family: "gradientBevel", label: "gBevel d2 q1 s1", make: () -> Optional.filter("openfl.filters.GradientBevelFilter", 2, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 8, 8, 1, 1, BitmapFilterType.FULL, false)},
		{family: "gradientBevel", label: "gBevel d8 q1 s1", make: () -> Optional.filter("openfl.filters.GradientBevelFilter", 8, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 8, 8, 1, 1, BitmapFilterType.FULL, false)},
		{family: "gradientBevel", label: "gBevel d8 q3 s1", make: () -> Optional.filter("openfl.filters.GradientBevelFilter", 8, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 8, 8, 1, 3, BitmapFilterType.FULL, false)},
		{family: "gradientBevel", label: "gBevel d4 q3 s2", make: () -> Optional.filter("openfl.filters.GradientBevelFilter", 4, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 8, 8, 2, 3, BitmapFilterType.FULL, false)},
		{family: "gradientBevel", label: "gBevel outer d4 q2 s1", make: () -> Optional.filter("openfl.filters.GradientBevelFilter", 4, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 8, 8, 1, 2, BitmapFilterType.OUTER, false)},
		{family: "gradientBevel", label: "gBevel inner d4 q2 s1", make: () -> Optional.filter("openfl.filters.GradientBevelFilter", 4, 45, GRADIENT_COLOURS, GRADIENT_ALPHAS, GRADIENT_RATIOS, 8, 8, 1, 2, BitmapFilterType.INNER, false)},
		{family: "circle", label: "circle glow q2 s2", make: () -> new GlowFilter(0xFF0000, 1, 12, 12, 2, 2, false, false), circle: true},
		{family: "circle", label: "circle bevel full d4 q2 s1", make: () -> new BevelFilter(4, 45, 0xFFFFFF, 1, 0x000000, 1, 8, 8, 1, 2, BitmapFilterType.FULL), circle: true},
		{family: "alpha", label: "glow orange a=0.5 q1 s2", make: () -> new GlowFilter(0xFF8000, 0.5, 12, 12, 2, 1, false, false)},
		{family: "alpha", label: "glow orange a=0.5 q3 s2", make: () -> new GlowFilter(0xFF8000, 0.5, 12, 12, 2, 3, false, false)},
		{family: "alpha", label: "shadow green a=0.5 d6 q1", make: () -> new DropShadowFilter(6, 45, 0x40C040, 0.5, 8, 8, 1, 1)},
		{family: "alpha", label: "bevel a=0.5 d4 q2 s1", make: () -> new BevelFilter(4, 45, 0xFFFFFF, 0.5, 0x000000, 0.5, 8, 8, 1, 2, BitmapFilterType.INNER)}
	];

	/** The page this build shows (-Drendertest_variant=pN), or -1 for the full stage. **/
	public static function page():Int
	{
		var variant = rendertest.Build.variantSuffix();
		return StringTools.startsWith(variant, "_p") ? Std.parseInt(variant.substr(2)) : -1;
	}

	/** Top-left of case `index` on the full stage (the live cell; the applyFilter cell is CELL + 40 to its right). **/
	public static function cellOrigin(index:Int):Point
	{
		return new Point(14 + (index % 3) * 420, 40 + Std.int(index / 3) * 220);
	}

	var frame = 0;

	public function new()
	{
		super();
		var shown = page();
		graphics.beginFill(BG);
		graphics.drawRect(0, 0, W, shown >= 0 ? PAGE_H : H);
		graphics.endFill();
		title("Filter parameter sweep: live vector shape vs BitmapData.applyFilter" + (shown >= 0 ? "  page " + shown : ""));
		for (i in 0...CASES.length)
		{
			if (shown >= 0 && (i < shown * PER_PAGE || i >= (shown + 1) * PER_PAGE)) continue;
			var origin = cellOrigin(shown >= 0 ? i - shown * PER_PAGE : i);
			cell(origin.x, origin.y, CASES[i]);
		}
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function cell(x:Float, y:Float, sweepCase:SweepCase):Void
	{
		if (sweepCase.make() == null)
		{
			// a filter this openfl does not have (rendertest.Optional): the label alone
			label(sweepCase.label + ": not in this openfl", x, y + CELL + 2, 11, false);
			return;
		}
		var circle = sweepCase.circle == true;
		var live = makeShape(circle);
		live.x = x;
		live.y = y;
		live.filters = [sweepCase.make()];
		addChild(live);

		var subject = new BitmapData(CELL, CELL, true, 0);
		subject.draw(makeShape(circle));
		var filtered = new BitmapData(CELL, CELL, true, 0);
		filtered.applyFilter(subject, subject.rect, new Point(0, 0), sweepCase.make());
		var software = new Bitmap(filtered);
		software.x = x + CELL + 40;
		software.y = y;
		addChild(software);
		label(sweepCase.label, x, y + CELL + 2, 11, false);
	}

	/** The subject, centred in a CELL x CELL area. **/
	function makeShape(circle:Bool):Shape
	{
		var s = new Shape();
		s.graphics.beginFill(COLOUR);
		if (circle) s.graphics.drawCircle(CELL / 2, CELL / 2, BOX / 2);
		else
			s.graphics.drawRect((CELL - BOX) / 2, (CELL - BOX) / 2, BOX, BOX);
		s.graphics.endFill();
		return s;
	}

	function title(text:String):Void
	{
		label(text, 12, 8, 14, true);
	}

	function label(text:String, x:Float, y:Float, size:Int, bold:Bool):Void
	{
		var tf = new TextField();
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.defaultTextFormat = new TextFormat("_sans", size, bold ? 0x300030 : 0x101010, bold);
		tf.selectable = false;
		tf.text = text;
		tf.x = x;
		tf.y = y;
		addChild(tf);
	}

	function onFrame(_):Void
	{
		frame++;
		if (frame < 10) return;
		removeEventListener(Event.ENTER_FRAME, onFrame);
		Harness.capture(stage, Score.score, W, page() >= 0 ? PAGE_H : H);
	}
}
