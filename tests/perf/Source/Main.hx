package;

import haxe.Timer;
import haxe.crypto.Crc32;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.GradientType;
import openfl.display.Graphics;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.display.StageQuality;
import openfl.events.Event;
import openfl.filters.BevelFilter;
import openfl.filters.BitmapFilter;
import openfl.filters.BitmapFilterType;
import openfl.filters.BlurFilter;
import openfl.filters.ColorMatrixFilter;
import openfl.filters.ConvolutionFilter;
import openfl.filters.DisplacementMapFilter;
import openfl.filters.DropShadowFilter;
import openfl.filters.GlowFilter;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import rendertest.Optional;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

typedef Source =
{
	field:TextField,
	source:String,
	html:Bool
}

typedef Case =
{
	set:String,
	name:String,
	width:Int,
	height:Int,
	run:Void->BitmapData
}

/**
	Software rendering benchmark: filters, vector drawing and text. Every case is one call that is timed after a warm-up call, with what
	HashLink allocated during it (bytes and allocation count, from hl.Gc.stats) and a CRC of the result,
	so two openfl trees can be compared for speed and checked for drawing the same pixels.

	Sets (PERF_SET picks some, comma separated):
	  effects   every filter on a 940 x 640 picture covered with shapes, through BitmapData.applyFilter
	            (the __applyFilter the cache-bitmap render calls)
	  displacement  DisplacementMapFilter with the map at 0,0 and off it, other channels, a translucent
	            and a smaller map, a map that moves nothing, a sparse picture, and smoothing off
	  modes     the compositing variants: inner, knockout, hideObject, the bevel types
	  sparse    the filters on a picture that is mostly empty, as a cache bitmap that outgrew its object
	  strength  Glow at blur 4 to 32 and quality 1 to 3
	  blur      Glow and Drop Shadow at blur sizes that round differently: odd, fractional, one axis
	            only, none and very large, each outer and inner
	  size      three filters from 256 x 256 to 1920 x 1080
	  display   a filtered display object drawn with BitmapData.draw after its filters were set again:
	            the whole pipeline of a frame in which a filter changed (render, filters, composite),
	            with one filter, stacks of two and three, and filtered objects nested three deep
	  vector    shapes drawn with BitmapData.draw after every Graphics was marked changed, so each is
	            rasterised again: what a clip whose scale or rotation changes costs per frame. Long
	            outlines, many fills in one Graphics, many small shapes, a clip of nested shapes; the
	            "tiny" ones are the same commands drawn a few pixels large, where rasterising costs
	            next to nothing and what is left is the handling of the commands
	  vectorcached  the same shapes drawn again unchanged (their bitmaps are kept)
	  vectorbuild   the same shapes with their drawing commands issued again before the draw
	  vectorquality two of them on the stage at each Stage.quality (off the stage a shape draws as HIGH)
	  hittest   400 points asked whether they hit the shape itself (hitTestPoint with shapeFlag)
	  text      text fields drawn with BitmapData.draw after their text was set again, so each is laid
	            out and rasterised again: many short labels, wrapped paragraphs, lines without
	            wrapping, html with many format runs, a large heading, aligned and auto-sized text
	  textcached    the same fields drawn again unchanged
	  textlayout    the same fields with their text set again and their size asked for, not drawn:
	            the layout alone
	  textbuild     the same fields made anew before the draw: what a list, a tooltip or a floating
	            number costs when its text fields are created as they are shown
	  textupdate    one field whose text changes 100 times with a draw after each: a counter, a line
	            that is typed, and a log that gets a line appended; "new" ones show text that was
	            never laid out before, so nothing from earlier layouts can be reused

	The variants run groups of sets: filters (effects to display), vector (vector to hittest) and
	text (text to textupdate). Environment: PERF_SET (sets to run instead, comma separated),
	PERF_ITERATIONS (default 5), PERF_REPEAT (default 1: how many times a case runs inside one
	timed call; the numbers are then those of that many runs), PERF_SIZE (the picture, default
	940x640; the display object is half of it each way, and the `size` set keeps its own sizes).
	There is no reference: Score.hx reports the timings, and the suite runner's --baseline compares
	them with another build's.

	Times come from `now()`, not from the stamp of lime's haxe.Timer, which counts whole milliseconds.
**/
class Main extends Sprite
{
	static var WIDTH = 940;
	static var HEIGHT = 640;

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, function(_) Timer.delay(run, 0));
	}

	/** The sets each variant runs (-Drendertest_variant=filters, vector or text). **/
	static var SETS = [
		"filters" => ["effects", "displacement", "modes", "sparse", "strength", "blur", "size", "display"],
		"vector" => ["vector", "vectorcached", "vectorbuild", "vectorquality", "hittest"],
		"text" => ["text", "textcached", "textlayout", "textbuild", "textupdate"]
	];

	/** One line per case, for Score.hx. **/
	public static var results:Array<{set:String, name:String, median:Float, min:Float, mbPerCall:Float, allocsPerCall:Float, crc:String}> = [];

	public static var iterations(default, null) = 5;

	function run():Void
	{
		iterations = Std.parseInt(env("PERF_ITERATIONS", "5"));
		var repeat = Std.parseInt(env("PERF_REPEAT", "1"));
		var size = env("PERF_SIZE", '${WIDTH}x$HEIGHT').split("x");
		WIDTH = Std.parseInt(size[0]);
		HEIGHT = Std.parseInt(size[1]);
		var variant = rendertest.Build.variantSuffix().substr(1);
		var sets = env("PERF_SET", null);
		var names = sets != null ? sets.split(",") : (SETS.exists(variant) ? SETS.get(variant) : null);

		// cases with a filter this openfl does not have are null (rendertest.Optional)
		var cases = build().filter(function(c) return c != null);
		if (names != null) cases = cases.filter(function(c) return names.indexOf(c.set) > -1);

		Sys.println('benchmark: ${cases.length} cases on $WIDTH x $HEIGHT, $iterations iterations each after one warm-up'
			+ (repeat > 1 ? ', each of them $repeat runs of the case' : ""));
		var last:BitmapData = null;
		for (c in cases)
		{
			c.run(); // warm-up
			var times = [];
			var bytes = 0.0, count = 0.0;
			var result:BitmapData = null;
			for (i in 0...iterations)
			{
				#if hl
				var before = hl.Gc.stats();
				#end
				var start = now();
				for (r in 0...repeat)
					result = c.run();
				times.push((now() - start) * 1000);
				#if hl
				var after = hl.Gc.stats();
				bytes += after.totalAllocated - before.totalAllocated;
				count += after.allocationCount - before.allocationCount;
				#end
			}
			times.sort(Reflect.compare);
			results.push({
				set: c.set,
				name: c.name,
				median: times[Std.int(times.length / 2)],
				min: times[0],
				mbPerCall: bytes / iterations / (1024 * 1024),
				allocsPerCall: count / iterations,
				crc: StringTools.hex(Crc32.make(result.image.getPixels(result.image.rect, ARGB32)), 8)
			});
			last = result;
		}
		rendertest.Harness.scoreRender(rendertest.Pixels.fromImage(last.image), Score.score);
	}

	// ------------------------------------------------------------------------------------ the cases

	static function build():Array<Case>
	{
		var cases:Array<Case> = [];
		var dense = picture(WIDTH, HEIGHT, false);
		var sparse = picture(WIDTH, HEIGHT, true);

		var adjust = function():BitmapFilter return new ColorMatrixFilter([
			1.2, 0.1, 0.0, 0, 10,
			0.0, 1.1, 0.1, 0, 0,
			0.1, 0.0, 0.9, 0, -5,
			0.0, 0.0, 0.0, 1, 0
		]);
		var gradientGlow = function():BitmapFilter return Optional.filter("openfl.filters.GradientGlowFilter", 4, 45, [0x0000FF, 0xFF00FF, 0xFFFF00], [0, 1, 1], [0, 128, 255], 8, 8, 1, 1,
			BitmapFilterType.OUTER);
		var effects:Array<{name:String, make:Void->BitmapFilter}> = [
			{name: "Drop Shadow", make: function() return new DropShadowFilter()},
			{name: "Glow", make: function() return new GlowFilter()},
			{name: "Bevel", make: function() return new BevelFilter()},
			{name: "Gradient Glow", make: gradientGlow},
			{name: "Gradient Bevel", make: function() return Optional.filter("openfl.filters.GradientBevelFilter")},
			{name: "Adjust Color", make: adjust},
			{name: "Blur", make: function() return new BlurFilter()}
		];

		// effects: every filter, dense picture
		for (e in effects)
			cases.push(applied("effects", e.name, dense, e.make()));
		cases.push(applied("effects", "Convolution", dense, new ConvolutionFilter(3, 3, [0, -1, 0, -1, 5, -1, 0, -1, 0], 1)));
		cases.push(applied("effects", "Displacement Map", dense, new DisplacementMapFilter(displacementMap(), new Point(), 1, 2, 12, 12)));

		// displacement: the paths through lime's displaceMap
		cases.push(applied("displacement", "map at 0,0", dense, new DisplacementMapFilter(displacementMap(), new Point(), 1, 2, 12, 12)));
		cases.push(applied("displacement", "map at 10,20", dense, new DisplacementMapFilter(displacementMap(), new Point(10, 20), 1, 2, 12, 12)));
		cases.push(applied("displacement", "blue and alpha, scale 30", dense, new DisplacementMapFilter(displacementMap(), new Point(), 4, 8, 30, -30)));
		cases.push(applied("displacement", "translucent map", dense, new DisplacementMapFilter(translucentMap(WIDTH, HEIGHT), new Point(), 1, 2, 12, 12)));
		cases.push(applied("displacement", "small map at 100,80", dense, new DisplacementMapFilter(translucentMap(256, 256), new Point(100, 80), 1, 2, 20, 20)));
		cases.push(applied("displacement", "grey map, nothing moves", dense, new DisplacementMapFilter(new BitmapData(WIDTH, HEIGHT, false, 0x808080), new Point(), 1, 2,
			12, 12)));
		cases.push(applied("displacement", "sparse picture", sparse, new DisplacementMapFilter(displacementMap(), new Point(), 1, 2, 12, 12)));
		var unsmoothed = new DisplacementMapFilter(displacementMap(), new Point(), 1, 2, 12, 12);
		@:privateAccess unsmoothed.__smooth = false;
		cases.push(applied("displacement", "not smoothed", dense, unsmoothed));

		// modes: the compositing variants
		cases.push(applied("modes", "Glow inner", dense, new GlowFilter(0x2060FF, 0.8, 8, 8, 2, 1, true)));
		cases.push(applied("modes", "Glow knockout", dense, new GlowFilter(0x2060FF, 0.8, 8, 8, 2, 1, false, true)));
		cases.push(applied("modes", "Glow inner knockout", dense, new GlowFilter(0x2060FF, 0.8, 8, 8, 2, 1, true, true)));
		cases.push(applied("modes", "Shadow inner", dense, new DropShadowFilter(4, 45, 0, 0.7, 6, 6, 1, 1, true)));
		cases.push(applied("modes", "Shadow hideObject", dense, new DropShadowFilter(4, 45, 0, 0.7, 6, 6, 1, 1, false, false, true)));
		cases.push(applied("modes", "Bevel full", dense, new BevelFilter(4, 45, 0xFFFFFF, 1, 0, 1, 4, 4, 1, 1, BitmapFilterType.FULL)));
		cases.push(applied("modes", "Bevel outer knockout", dense, new BevelFilter(4, 45, 0xFFFFFF, 1, 0, 1, 4, 4, 1, 1, BitmapFilterType.OUTER, true)));
		cases.push(applied("modes", "Gradient Glow full", dense, Optional.filter("openfl.filters.GradientGlowFilter", 4, 45, [0x0000FF, 0xFF00FF, 0xFFFF00], [0, 1, 1], [0, 128, 255], 8, 8, 1, 1,
			BitmapFilterType.FULL)));
		cases.push(applied("modes", "Adjust Color alpha", dense, new ColorMatrixFilter([0.5, 0.5, 0, 0, 0, 0, 1, 0, 0, 20, 0, 0, 1.4, 0, 0, 0, 0, 0, 0.6, 30])));

		// sparse: the filters on a mostly empty picture
		for (e in effects)
			cases.push(applied("sparse", e.name, sparse, e.make()));

		// strength: Glow by blur and quality
		for (quality in 1...4)
			for (blur in [4, 8, 16, 32])
				cases.push(applied("strength", 'Glow blur $blur quality $quality', dense, new GlowFilter(0x2060FF, 1, blur, blur, 2, quality)));

		// blur: the blur sizes that round differently (odd, fractional, one axis only, none), outer and inner
		for (inner in [false, true])
		{
			for (size in [[5.0, 5.0], [7.0, 3.0], [4.5, 6.25], [1.0, 8.0], [9.0, 1.0], [0.0, 0.0], [64.0, 64.0]])
				cases.push(applied("blur", 'Glow ${size[0]} x ${size[1]}' + (inner ? " inner" : ""), dense, new GlowFilter(0x2060FF, 0.8, size[0], size[1], 2, 2,
					inner)));
			cases.push(applied("blur", 'Shadow 5 x 5 quality 3' + (inner ? " inner" : ""), dense, new DropShadowFilter(4, 45, 0, 0.7, 5, 5, 1, 3, inner)));
		}

		// size: three filters by bitmap size
		for (size in [[256, 256], [512, 512], [1024, 1024], [1920, 1080]])
		{
			var source = picture(size[0], size[1], false);
			cases.push(applied("size", 'Drop Shadow ${size[0]}x${size[1]}', source, new DropShadowFilter()));
			cases.push(applied("size", 'Bevel ${size[0]}x${size[1]}', source, new BevelFilter()));
			cases.push(applied("size", 'Adjust Color ${size[0]}x${size[1]}', source, adjust()));
		}

		// display: a filtered display object drawn again after its filters were set
		cases.push(drawn("display", "no filter", subject(), []));
		for (e in effects)
			cases.push(drawn("display", e.name, subject(), [e.make()]));
		cases.push(drawn("display", "Glow + Drop Shadow", subject(), [new GlowFilter(0x2060FF, 0.9, 10, 10, 2, 2), new DropShadowFilter(8, 45, 0, 0.7, 8, 8, 1, 2)]));
		cases.push(drawn("display", "Bevel + Glow + Shadow", subject(),
			[new BevelFilter(), new GlowFilter(0x2060FF, 0.9, 10, 10, 2, 2), new DropShadowFilter(8, 45, 0, 0.7, 8, 8, 1, 2)]));
		var innermost = subject();
		innermost.filters = [new BevelFilter()];
		var middle = new Sprite();
		middle.addChild(innermost);
		middle.filters = [new GlowFilter(0x2060FF, 0.9, 10, 10, 2, 2)];
		var outer = new Sprite();
		outer.addChild(middle);
		cases.push(drawn("display", "nested three deep", outer, [new DropShadowFilter(8, 45, 0, 0.7, 8, 8, 1, 2)]));
		vector(cases);
		text(cases);
		return cases;
	}

	// --------------------------------------------------------------------------------- vector cases

	static function vector(cases:Array<Case>):Void
	{
		var radius = HEIGHT * 0.45;
		var contents:Array<{name:String, scale:Float, build:Sprite->Void}> = [
			{name: "outline of 4000 lines", scale: 1, build: function(s) outline(s.graphics, 4000, false, false, radius, 0x2060FF)},
			{name: "outline of 4000 lines, tiny", scale: 0.04, build: function(s) outline(s.graphics, 4000, false, false, radius, 0x2060FF)},
			{name: "outline of 2000 curves", scale: 1, build: function(s) outline(s.graphics, 2000, true, false, radius, 0xFF8040)},
			{name: "outline of 2000 curves, stroked", scale: 1, build: function(s) outline(s.graphics, 2000, true, true, radius, 0xFF8040)},
			{name: "600 rectangles", scale: 1, build: function(s) grid(s, 30, 20, function(g, size, k, x, y)
			{
				g.beginFill(colour(k));
				g.drawRect(x - size * 0.4, y - size * 0.4, size * 0.8, size * 0.8);
				g.endFill();
			}, false)},
			{name: "600 circles, stroked", scale: 1, build: function(s) grid(s, 30, 20, function(g, size, k, x, y)
			{
				g.lineStyle(2, 0x202020);
				g.beginFill(colour(k));
				g.drawCircle(x, y, size * 0.4);
				g.endFill();
			}, false)},
			{name: "200 gradient fills", scale: 1, build: function(s) grid(s, 20, 10, function(g, size, k, x, y)
			{
				var box = new Matrix();
				box.createGradientBox(size * 0.8, size * 0.8, 0.6, x - size * 0.4, y - size * 0.4);
				g.beginGradientFill(GradientType.LINEAR, [colour(k), colour(k + 1)], [1, 1], [0, 255], box);
				g.drawRoundRect(x - size * 0.4, y - size * 0.4, size * 0.8, size * 0.8, size * 0.2, size * 0.2);
				g.endFill();
			}, false)},
			{name: "600 small shapes", scale: 1, build: function(s) grid(s, 30, 20, function(g, size, k, x, y) outline(g, 12, true, false, size * 0.45, colour(k)), true)},
			{name: "600 small shapes, tiny", scale: 0.15, build: function(s) grid(s, 30, 20, function(g, size, k, x, y) outline(g, 12, true, false, size * 0.45,
				colour(k)), true)},
			{name: "clip of 150 shapes", scale: 1, build: clip}
		];

		for (content in contents)
		{
			cases.push(vectorCase("vector", content.name, content.scale, content.build, true, false, null));
			cases.push(vectorCase("vectorcached", content.name, content.scale, content.build, false, false, null));
			cases.push(vectorCase("vectorbuild", content.name, content.scale, content.build, false, true, null));
		}
		for (index in [0, 7, 9])
		{
			for (quality in [StageQuality.LOW, StageQuality.MEDIUM, StageQuality.HIGH, StageQuality.BEST])
				cases.push(vectorCase("vectorquality", contents[index].name + ", " + quality, 1, contents[index].build, true, false, quality));
		}
		for (index in [0, 7, 9])
		{
			var object = new Sprite();
			contents[index].build(object);
			object.x = WIDTH / 2;
			object.y = HEIGHT / 2;
			var hits = new BitmapData(25, 16, true, 0);
			cases.push({
				set: "hittest",
				name: contents[index].name,
				width: WIDTH,
				height: HEIGHT,
				run: function()
				{
					// off the stage hitTestPoint answers false without looking
					var stage = openfl.Lib.current.stage;
					stage.addChild(object);
					for (row in 0...16)
					{
						for (column in 0...25)
						{
							var hit = object.hitTestPoint((column + 0.5) * WIDTH / 25, (row + 0.5) * HEIGHT / 16, true);
							hits.setPixel32(column, row, hit ? 0xFFFFFFFF : 0xFF000000);
						}
					}
					stage.removeChild(object);
					return hits;
				}
			});
		}
	}

	/**
		One BitmapData.draw of what `build` draws into a Sprite. `changed` marks every Graphics changed
		first, `rebuild` issues the commands again first, and `quality` puts the sprite on the stage at
		that Stage.quality for the draw.
	**/
	static function vectorCase(set:String, name:String, scale:Float, build:Sprite->Void, changed:Bool, rebuild:Bool, quality:StageQuality):Case
	{
		var object = new Sprite();
		build(object);
		var canvas = new BitmapData(WIDTH, HEIGHT, true, 0);
		var matrix = new Matrix(scale, 0, 0, scale, WIDTH / 2, HEIGHT / 2);
		return {
			set: set,
			name: name,
			width: WIDTH,
			height: HEIGHT,
			run: function()
			{
				if (rebuild)
				{
					object.removeChildren();
					object.graphics.clear();
					build(object);
				}
				if (changed) markChanged(object);
				var stage = openfl.Lib.current.stage;
				if (quality != null)
				{
					stage.quality = quality;
					stage.addChild(object);
				}
				canvas.fillRect(canvas.rect, 0);
				canvas.draw(object, matrix);
				if (quality != null) stage.removeChild(object);
				return canvas;
			}
		};
	}

	// ----------------------------------------------------------------------------------- text cases

	static var WORDS = ["the", "quick", "render", "of", "text", "fields", "measures", "every", "word", "and", "places", "glyphs", "on", "lines", "that",
		"wrap", "at", "the", "width", "a", "paragraph", "is", "given", "while", "formats", "change", "colour", "size", "or", "weight", "between", "runs"];

	/** `count` characters of words, the same for the same `seed`. **/
	static function words(count:Int, seed:Int):String
	{
		var buffer = new StringBuf();
		var length = 0;
		var k = seed;
		while (length < count)
		{
			var word = WORDS[(k * 7 + (k >> 2)) % WORDS.length];
			buffer.add(word);
			buffer.add(((k % 23) == 22) ? ". " : " ");
			length += word.length + 1;
			k++;
		}
		return buffer.toString().substr(0, count);
	}

	static function field(sprite:Sprite, sources:Array<Source>, x:Float, y:Float, width:Float, height:Float, format:TextFormat, source:String,
			html:Bool = false):TextField
	{
		var field = new TextField();
		field.defaultTextFormat = format;
		field.x = x;
		field.y = y;
		field.width = width;
		field.height = height;
		if (html) field.htmlText = source;
		else
			field.text = source;
		sprite.addChild(field);
		sources.push({field: field, source: source, html: html});
		return field;
	}

	static function text(cases:Array<Case>):Void
	{
		var plain = new TextFormat("_sans", 14, 0x202020);
		var small = new TextFormat("_sans", 11, 0x202020);
		var labels = function(sprite:Sprite, sources:Array<Source>, change:TextField->Void, format:TextFormat = null):Void
		{
			for (k in 0...200)
			{
				var label = field(sprite, sources, 8 + (k % 8) * (WIDTH / 8), 6 + Std.int(k / 8) * (HEIGHT / 25), WIDTH / 8 - 8, 22, format != null ? format : small,
					"Player " + (k * 37 % 1000) + ": " + (k * 7919 % 100000));
				if (change != null) change(label);
			}
		};
		var paragraph = function(count:Int, format:TextFormat, change:TextField->Void)
		{
			return function(sprite:Sprite, sources:Array<Source>):Void
			{
				var block = field(sprite, sources, 10, 10, WIDTH - 20, HEIGHT - 20, format, words(count, 3));
				block.multiline = true;
				block.wordWrap = true;
				if (change != null) change(block);
			};
		};
		var contents:Array<{name:String, build:Sprite->Array<Source>->Void}> = [
			{name: "200 short labels", build: function(sprite, sources) labels(sprite, sources, null)},
			{name: "200 labels, auto size", build: function(sprite, sources) labels(sprite, sources, function(label) label.autoSize = TextFieldAutoSize.LEFT)},
			{name: "200 labels, border", build: function(sprite, sources) labels(sprite, sources, function(label)
			{
				label.border = true;
				label.background = true;
				label.backgroundColor = 0xFFF0C0;
			})},
			{name: "200 labels, bold", build: function(sprite, sources) labels(sprite, sources, null, new TextFormat("_sans", 11, 0x202020, true))},
			{name: "200 labels, font by name", build: function(sprite, sources) labels(sprite, sources, null, new TextFormat("Verdana", 11, 0x202020))},
			{name: "paragraph of 2000", build: paragraph(2000, plain, null)},
			{name: "paragraph of 10000", build: paragraph(10000, small, null)},
			{name: "paragraph of 2000, centred", build: paragraph(2000, new TextFormat("_sans", 14, 0x202020, null, null, null, null, null, TextFormatAlign.CENTER), null)},
			{name: "paragraph of 2000, justified", build: paragraph(2000, new TextFormat("_sans", 14, 0x202020, null, null, null, null, null, TextFormatAlign.JUSTIFY), null)},
			{name: "one line of 4000, no wrap", build: function(sprite, sources) field(sprite, sources, 10, 10, WIDTH - 20, 24, small, words(4000, 9))},
			{name: "40 lines, no wrap", build: function(sprite, sources)
			{
				var lines = [for (k in 0...40) words(90, k * 11)];
				var block = field(sprite, sources, 10, 10, WIDTH - 20, HEIGHT - 20, small, lines.join("\n"));
				block.multiline = true;
			}},
			{name: "html, 150 format runs", build: function(sprite, sources)
			{
				var buffer = new StringBuf();
				for (k in 0...150)
				{
					var run = words(14, k * 5);
					buffer.add(switch (k % 5)
					{
						case 0: '<b>$run</b> ';
						case 1: '<font color="#C03020">$run</font> ';
						case 2: '<i>$run</i> ';
						case 3: '<font size="18">$run</font> ';
						default: '<u>$run</u> ';
					});
				}
				var block = field(sprite, sources, 10, 10, WIDTH - 20, HEIGHT - 20, plain, buffer.toString(), true);
				block.multiline = true;
				block.wordWrap = true;
			}},
			{name: "heading at 96 px", build: function(sprite, sources) field(sprite, sources, 10, 10, WIDTH - 20, 130, new TextFormat("_sans", 96, 0x2060FF, true),
				"Level Complete")}
		];

		for (content in contents)
		{
			cases.push(textCase("text", content.name, content.build, true, true));
			cases.push(textCase("textcached", content.name, content.build, false, true));
			cases.push(textCase("textlayout", content.name, content.build, true, false));
			cases.push(textCase("textbuild", content.name, content.build, false, true, true));
		}

		var log = [for (k in 0...130) words(60, k * 13)];
		var updates:Array<{name:String, wrap:Bool, height:Float, value:Int->String}> = [
			{name: "counter", wrap: false, height: 24, value: function(k) return "Score: " + (120000 + k * 37)},
			{name: "typed line", wrap: false, height: 24, value: function(k) return words(20 + k, 5)},
			{name: "typed paragraph", wrap: true, height: HEIGHT - 20, value: function(k) return words(1000 + k * 3, 5)},
			{name: "log of 30 lines", wrap: false, height: HEIGHT - 20, value: function(k) return log.slice(k, k + 30).join("\n")}
		];
		var fresh = 0;
		var syllables = ["ka", "to", "mi", "ren", "su", "lo", "va", "di", "pe", "nu", "sha", "bo"];
		var freshWord = function():String
		{
			var n = fresh++;
			var word = "";
			while (true)
			{
				word += syllables[n % syllables.length];
				n = Std.int(n / syllables.length);
				if (n == 0) break;
			}
			return word;
		};
		updates.push({name: "counter, new values", wrap: false, height: 24, value: function(k) return "Score: " + (fresh++)});
		var long = words(20000, 17);
		var scrolled = new Sprite();
		var scrolledSources:Array<Source> = [];
		var scrolling = field(scrolled, scrolledSources, 10, 10, WIDTH - 20, HEIGHT - 20, small, long);
		scrolling.multiline = true;
		scrolling.wordWrap = true;
		var scrollCanvas = new BitmapData(WIDTH, HEIGHT, true, 0);
		cases.push({
			set: "textupdate",
			name: "text of 20000 scrolled",
			width: WIDTH,
			height: HEIGHT,
			run: function()
			{
				for (k in 0...100)
				{
					scrolling.scrollV = 1 + k;
					scrollCanvas.fillRect(scrollCanvas.rect, 0);
					scrollCanvas.draw(scrolled);
				}
				return scrollCanvas;
			}
		});
		updates.push({name: "new line of 12 words", wrap: false, height: 24, value: function(k) return [for (i in 0...12) freshWord()].join(" ")});
		updates.push({name: "new paragraph, 200 words", wrap: true, height: HEIGHT - 20, value: function(k) return [for (i in 0...200) freshWord()].join(" ")});
		for (update in updates)
		{
			var sprite = new Sprite();
			var sources:Array<Source> = [];
			var changing = field(sprite, sources, 10, 10, WIDTH - 20, update.height, plain, update.value(0));
			changing.multiline = true;
			changing.wordWrap = update.wrap;
			var canvas = new BitmapData(WIDTH, HEIGHT, true, 0);
			cases.push({
				set: "textupdate",
				name: update.name,
				width: WIDTH,
				height: HEIGHT,
				run: function()
				{
					for (k in 0...100)
					{
						changing.text = update.value(k);
						canvas.fillRect(canvas.rect, 0);
						canvas.draw(sprite);
					}
					return canvas;
				}
			});
		}
	}

	/**
		What `build` puts into a Sprite, as text fields. `changed` sets the text of every field again
		first, so each is laid out again; `draw` draws the sprite, otherwise the size of every field's
		text is asked for, which lays it out without drawing.
	**/
	static function textCase(set:String, name:String, build:Sprite->Array<Source>->Void, changed:Bool, draw:Bool, rebuild:Bool = false):Case
	{
		var sprite = new Sprite();
		var sources:Array<Source> = [];
		build(sprite, sources);
		var canvas = new BitmapData(WIDTH, HEIGHT, true, 0);
		canvas.draw(sprite);
		return {
			set: set,
			name: name,
			width: WIDTH,
			height: HEIGHT,
			run: function()
			{
				if (rebuild)
				{
					sprite.removeChildren();
					sources.resize(0);
					build(sprite, sources);
				}
				if (changed)
				{
					for (entry in sources)
					{
						// another text and back: the field is marked changed and ends up as it was
						if (entry.html)
						{
							entry.field.htmlText = "";
							entry.field.htmlText = entry.source;
						}
						else
						{
							entry.field.text = "";
							entry.field.text = entry.source;
						}
					}
				}
				if (draw)
				{
					canvas.fillRect(canvas.rect, 0);
					canvas.draw(sprite);
				}
				else
				{
					var total = 0.0;
					for (entry in sources)
						total += entry.field.textWidth + entry.field.textHeight;
				}
				return canvas;
			}
		};
	}

	/** Marks the Graphics of `object` and of everything inside it changed, so the next draw rasterises them again. **/
	static function markChanged(object:DisplayObject):Void
	{
		var graphics = @:privateAccess object.__graphics;
		if (graphics != null) @:privateAccess graphics.__dirty = true;
		if (Std.isOfType(object, DisplayObjectContainer))
		{
			var container:DisplayObjectContainer = cast object;
			for (i in 0...container.numChildren)
				markChanged(container.getChildAt(i));
		}
	}

	/** A closed outline around the origin whose distance from it jumps from point to point: `count` lines or curves, filled. **/
	static function outline(g:Graphics, count:Int, curves:Bool, stroked:Bool, radius:Float, fill:Int):Void
	{
		if (stroked) g.lineStyle(2, 0x202020);
		g.beginFill(fill);
		for (k in 0...count + 1)
		{
			var point = k % count;
			var angle = point / count * Math.PI * 2;
			var distance = radius * (0.55 + 0.45 * ((point * 37) % 101) / 100);
			var x = Math.cos(angle) * distance, y = Math.sin(angle) * distance;
			if (k == 0) g.moveTo(x, y);
			else if (curves)
			{
				var between = (k - 0.5) / count * Math.PI * 2;
				g.curveTo(Math.cos(between) * distance * 1.05, Math.sin(between) * distance * 1.05, x, y);
			}
			else g.lineTo(x, y);
		}
		g.endFill();
	}

	/**
		`columns` x `rows` cells over the picture, each drawn by `draw(graphics, cell size, cell number,
		x, y)`: as children of `sprite`, one Shape per cell placed at the cell and drawn around 0, 0, or
		all into the sprite's own Graphics, drawn around the cell's x, y.
	**/
	static function grid(sprite:Sprite, columns:Int, rows:Int, draw:Graphics->Float->Int->Float->Float->Void, children:Bool):Void
	{
		var size = Math.min(WIDTH * 0.95 / columns, HEIGHT * 0.95 / rows);
		for (row in 0...rows)
		{
			for (column in 0...columns)
			{
				var x = (column - (columns - 1) / 2) * size, y = (row - (rows - 1) / 2) * size;
				if (children)
				{
					var shape = new Shape();
					shape.x = x;
					shape.y = y;
					draw(shape.graphics, size, row * columns + column, 0, 0);
					sprite.addChild(shape);
				}
				else draw(sprite.graphics, size, row * columns + column, x, y);
			}
		}
	}

	static function colour(k:Int):Int
	{
		return [0xFF8040, 0x2060FF, 0x40C080, 0xE0C040, 0xC040C0][k % 5];
	}

	/** Six groups of 25 shapes of 60 curves each, every third stroked, the groups turned and two of them translucent: a clip as an animation tool exports it. **/
	static function clip(sprite:Sprite):Void
	{
		var size = HEIGHT * 0.3;
		for (group in 0...6)
		{
			var part = new Sprite();
			part.x = ((group % 3) - 1) * size * 1.05;
			part.y = (Std.int(group / 3) - 0.5) * size * 1.05;
			part.rotation = group * 7;
			if (group % 3 == 2) part.alpha = 0.8;
			for (k in 0...25)
			{
				var shape = new Shape();
				shape.x = ((k % 5) - 2) * size * 0.19;
				shape.y = (Std.int(k / 5) - 2) * size * 0.19;
				outline(shape.graphics, 60, true, k % 3 == 0, size * 0.12, colour(k + group));
				part.addChild(shape);
			}
			sprite.addChild(part);
		}
	}

	/** One BitmapData.applyFilter of `filter` over the whole of `source`. **/
	/** null (left out) when this openfl lacks the filter's class. **/
	static function applied(set:String, name:String, source:BitmapData, filter:BitmapFilter):Case
	{
		if (filter == null) return null;
		var dest = new BitmapData(source.width, source.height, true, 0);
		var point = new Point();
		return {
			set: set,
			name: name,
			width: source.width,
			height: source.height,
			run: function()
			{
				dest.fillRect(dest.rect, 0);
				dest.applyFilter(source, source.rect, point, filter);
				return dest;
			}
		};
	}

	/** One BitmapData.draw of `object` right after its filters were set, which makes it render and filter again. **/
	/** null (left out) when this openfl lacks one of the filters' classes. **/
	static function drawn(set:String, name:String, object:DisplayObject, filters:Array<BitmapFilter>):Case
	{
		if (filters.contains(null)) return null;
		var canvas = new BitmapData(WIDTH, HEIGHT, true, 0);
		var matrix = new Matrix(1, 0, 0, 1, WIDTH / 2, HEIGHT / 2);
		return {
			set: set,
			name: name,
			width: Std.int(WIDTH / 2),
			height: Std.int(HEIGHT / 2),
			run: function()
			{
				object.filters = filters;
				canvas.fillRect(canvas.rect, 0);
				canvas.draw(object, matrix);
				return canvas;
			}
		};
	}

	/**
		A group of shapes around its origin, half the picture each way (480 x 320 at the default size):
		what a filtered display object of a scene looks like.
	**/
	static function subject():Sprite
	{
		var scale = WIDTH / 940;
		var sprite = new Sprite();
		var g = sprite.graphics;
		g.beginFill(0x2060FF);
		g.drawRoundRect(-240 * scale, -160 * scale, 480 * scale, 320 * scale, 60 * scale, 60 * scale);
		g.endFill();
		g.beginFill(0xFF8040);
		g.drawCircle(-90 * scale, -20 * scale, 90 * scale);
		g.endFill();
		g.beginFill(0x40C080, 0.7);
		g.drawEllipse(-20 * scale, -60 * scale, 220 * scale, 170 * scale);
		g.endFill();
		g.lineStyle(6 * scale, 0xFFFFFF);
		g.moveTo(-200 * scale, 110 * scale);
		g.curveTo(0, 40 * scale, 200 * scale, 110 * scale);
		return sprite;
	}

	/**
		Shapes, opaque and translucent, so every filter has edges and alpha to work on: over the whole
		area, or with `sparse` two in the middle of an otherwise empty bitmap.
	**/
	static function picture(width:Int, height:Int, sparse:Bool):BitmapData
	{
		var shape = new Shape();
		var g = shape.graphics;
		var columns = Math.ceil(width / 115), rows = Math.ceil(height / 125);
		for (row in 0...rows)
		{
			for (column in 0...columns)
			{
				if (sparse && (row != Std.int(rows / 2) || (column != Std.int(columns / 2) && column != Std.int(columns / 2) - 1))) continue;
				var x = 60 + column * 115, y = 60 + row * 125;
				g.beginFill([0xFF8040, 0x2060FF, 0x40C080, 0xE0C040][(row + column) % 4], (row + column) % 3 == 0 ? 0.6 : 1);
				if ((row + column) % 2 == 0) g.drawCircle(x, y, 38);
				else g.drawRoundRect(x - 40, y - 30, 80, 60, 18, 18);
				g.endFill();
			}
		}
		if (!sparse)
		{
			g.beginFill(0xFFFFFF, 0.4);
			g.drawEllipse(width * 0.2, height * 0.28, width * 0.57, height * 0.44);
			g.endFill();
		}
		var bitmapData = new BitmapData(width, height, true, 0);
		bitmapData.draw(shape, new Matrix());
		return bitmapData;
	}

	/** Red and green ramps in bands, for DisplacementMapFilter. **/
	static function displacementMap():BitmapData
	{
		var map = new BitmapData(WIDTH, HEIGHT, false, 0x808080);
		for (i in 0...Math.ceil(WIDTH / 20))
			map.fillRect(new Rectangle(i * 20, 0, 20, HEIGHT), 0xFF000000 | (((i * 37) & 0xFF) << 16) | 0x8000);
		for (i in 0...Math.ceil(HEIGHT / 20))
			map.fillRect(new Rectangle(0, i * 20, WIDTH, 10), 0xFF000000 | 0x800000 | (((i * 53) & 0xFF) << 8));
		return map;
	}

	/** A map with alpha: red and green ramps in bands whose alpha rises from left to right, clear in one corner. **/
	static function translucentMap(width:Int, height:Int):BitmapData
	{
		var map = new BitmapData(width, height, true, 0);
		var bands = Math.ceil(width / 16);
		for (i in 0...bands)
			map.fillRect(new Rectangle(i * 16, 0, 16, height), (Std.int(255 * (i + 1) / bands) << 24) | (((i * 29) & 0xFF) << 16) | (((i * 71) & 0xFF) << 8) | 0x40);
		map.fillRect(new Rectangle(0, 0, width / 4, height / 4), 0);
		return map;
	}

	// ------------------------------------------------------------------------------------ helpers

	/** Seconds, finer than a millisecond: hxcpp's Sys.time() counts whole milliseconds on Windows. **/
	static inline function now():Float
	{
		#if cpp
		return untyped __global__.__time_stamp();
		#else
		return Sys.time();
		#end
	}

	static function env(name:String, fallback:String):String
	{
		var value = Sys.getEnv(name);
		return value != null && value != "" ? value : fallback;
	}
}
