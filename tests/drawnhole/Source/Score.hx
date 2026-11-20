package;

import haxe.ds.Vector;
import openfl.display.BlendMode;
import rendertest.Compare;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	What the capture shows along the bar, span by span, for the rows with the bar over a shape;
	the percent of each cell's pixels off the AIR window by more than the tolerance; the same
	leaving out the pixels that are off in the row's NORMAL cell too (for the text rows and the
	disc, where AIR rasterises the glyphs and the rim differently, that is the part the blend is
	responsible for); the same again with one pixel of horizontal slack (native text sits about
	a pixel further along than AIR's); and the text rows against a prediction made from the
	capture's own bar-less cell.

	Scores: the cells whose spans read differently from the AIR window's, the worst shape-row cell
	beyond the NORMAL cell, and the worst text-row cell against its prediction.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL_W = Main.CELL_W;
	static inline var CELL_H = Main.CELL_H;
	static var ROWS = [
		"ring is the LAYER's graphics", "ring is a child", "ring child at alpha 0.5", "disc child", "bitmap child with hole",
		"text drawn first", "ring, text under the mode", "ring, text, then the bar"
	];
	/** The rows where the bar crosses a ring, disc or bitmap. **/
	static inline var SPAN_ROWS = 5;
	/** The rows with text under the bar, and the text's colour. **/
	static var TEXT_ROWS = [5 => 0x408CD9, 7 => 0x3CB043];
	/** The column without the bar (or, in row 6, without the text): the layer's content on its own. **/
	static inline var BARLESS = 5;
	static inline var GROUND = 0x808080;
	static inline var BAR = 0xF25A1A;
	/** The spans along the bar and the x in the cell where each is read. **/
	static var SPANS = [
		{name: "outside, left", x: 12},
		{name: "ring, left", x: 32},
		{name: "hole", x: 60},
		{name: "ring, right", x: 88},
		{name: "outside, right", x: 110}
	];
	/** The colours a span can be named by, checked in this order. **/
	static var NAMES = [
		{name: "as is", rgb: BAR},
		{name: "black", rgb: 0x000000},
		{name: "white", rgb: 0xFFFFFF},
		{name: "nothing", rgb: GROUND},
		{name: "ring", rgb: 0x408CD9},
		{name: "half ring", rgb: 0x6086AD}
	];
	/** The mask colour of a pixel that is off in the row's NORMAL cell too. **/
	static inline var MASK_RASTER = 0x6E2822;

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "The capture is compared with this picture of the AIR window.");
		var modes = [for (mode in Main.MODES) (mode : String).toUpperCase()];
		var width = capture.width, height = capture.height;

		// along the bar
		var spanRows:Array<Array<Dynamic>> = [];
		var differing = 0;
		for (row in 0...SPAN_ROWS)
			for (column in 0...modes.length)
			{
				var spans = readSpans(capture, column, row);
				var airSpans = readSpans(air, column, row);
				var cells:Array<Dynamic> = [ROWS[row], modes[column]];
				spanRows.push(cells.concat(spans));
				for (i in 0...spans.length)
					if (!sameReading(spans[i], airSpans[i]))
					{
						differing++;
						break;
					}
			}
		run.table("What the capture shows along the bar, span by span, for the rows with the bar over a shape",
			["row", "mode"].concat([for (s in SPANS) s.name]), spanRows,
			'"as is" is the orange bar, "nothing" the grey ground, "ring" the ring unchanged; otherwise the RGB values. In the hole, a SUBTRACT or INVERT bar "as is" means the hole counts as never drawn.');

		// against AIR
		var off = new Vector<Bool>(width * height);
		for (y in 0...height)
			for (x in 0...width)
				off[y * width + x] = capture.channelDiff(x, y, air, x, y) > TOLERANCE;
		run.table('Percent of each cell\'s pixels off the AIR window by more than $TOLERANCE', ["row"].concat(modes),
			cellTable(off, width, modes.length, false));

		var beyond = new Vector<Bool>(width * height);
		for (i in 0...beyond.length) beyond[i] = false;
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (row in 0...ROWS.length)
		{
			var values = [for (column in 0...modes.length) percentBeyondNormal(off, width, column, row, beyond)];
			if (!TEXT_ROWS.exists(row)) for (v in values) if (v > worst) worst = v;
			rows.push(([ROWS[row]] : Array<Dynamic>).concat([for (v in values) Html.percent(v)]));
		}
		run.table('Percent of each cell\'s pixels off the AIR window by more than $TOLERANCE, leaving out the pixels off in the row\'s NORMAL cell too (what the blend is responsible for)',
			["row"].concat(modes), rows);

		// with one pixel of slack: off only if AIR agrees with none of the pixel and its horizontal
		// neighbours (wrapping around the image's edges)
		var slack = new Vector<Bool>(width * height);
		for (y in 0...height)
			for (x in 0...width)
				slack[y * width + x] = off[y * width + x]
					&& capture.channelDiff((x + width - 1) % width, y, air, x, y) > TOLERANCE
					&& capture.channelDiff((x + 1) % width, y, air, x, y) > TOLERANCE;
		run.table('The same with one pixel of horizontal slack: percent of each cell\'s pixels off by more than $TOLERANCE where AIR agrees with none of the pixel and its horizontal neighbours, beyond the row\'s NORMAL cell',
			["row"].concat(modes), cellTable(slack, width, modes.length, true));

		// the text rows with the bar against their prediction from the capture's own bar-less cell
		var predictedWorst = 0.0;
		rows = [];
		for (row in [5, 7])
		{
			var values = [
				for (column in 0...modes.length)
					percentOffPrediction(capture, column, row, Main.MODES[column], TEXT_ROWS[row], row == 7)
			];
			for (v in values) if (v > predictedWorst) predictedWorst = v;
			rows.push(([ROWS[row]] : Array<Dynamic>).concat([for (v in values) Html.percent(v)]));
		}
		run.table('Text rows with the bar: percent of each cell\'s pixels off by more than $TOLERANCE from a prediction made from the capture\'s own bar-less cell',
			["row"].concat(modes), rows, "This check does not depend on how the glyphs are rasterized.");

		run.score("cells read differently", differing, "cells", "cells whose spans along the bar differ from the AIR window's");
		run.score("worst shape cell", worst, "%", "shape rows against AIR, beyond the row's NORMAL cell");
		run.score("worst text cell", predictedWorst, "%", "text rows against their prediction from the capture's own bar-less cell");

		// bright where the row's NORMAL cell agrees with AIR, dark where it is off there too
		var mask = Compare.mask(capture, air, TOLERANCE);
		for (y in 0...height)
			for (x in 0...width)
				if (off[y * width + x] && !beyond[y * width + x]) mask.set(x, y, MASK_RASTER);
		run.image("mask_air", mask, "Pixels off against AIR: bright where the row's NORMAL cell agrees with AIR, dark where it is off too", "capture");
	}

	/** The colour along the bar at each span (the median of 4 x 4 pixels), named. **/
	static function readSpans(image:Pixels, column:Int, row:Int):Array<String>
	{
		var spans = [];
		for (span in SPANS)
		{
			var reds = [], greens = [], blues = [];
			for (y in 48...52)
				for (x in span.x - 2...span.x + 2)
				{
					var px = column * CELL_W + x, py = row * CELL_H + y;
					reds.push(image.red(px, py));
					greens.push(image.green(px, py));
					blues.push(image.blue(px, py));
				}
			spans.push(name(median(reds), median(greens), median(blues)));
		}
		return spans;
	}

	/** The median of an even count of values, truncated to an integer. **/
	static function median(values:Array<Int>):Int
	{
		values.sort((a, b) -> a - b);
		var half = values.length >> 1;
		return Std.int((values[half - 1] + values[half]) / 2);
	}

	static function name(red:Int, green:Int, blue:Int):String
	{
		for (n in NAMES)
			if (Math.abs(red - ((n.rgb >> 16) & 0xFF)) <= TOLERANCE
				&& Math.abs(green - ((n.rgb >> 8) & 0xFF)) <= TOLERANCE
				&& Math.abs(blue - (n.rgb & 0xFF)) <= TOLERANCE) return n.name;
		return '$red,$green,$blue';
	}

	/** Whether two readings name the same thing: equal names, or RGB values within the tolerance of each other. **/
	static function sameReading(a:String, b:String):Bool
	{
		if (a == b) return true;
		var pa = a.split(","), pb = b.split(",");
		if (pa.length != 3 || pb.length != 3) return false;
		for (i in 0...3)
		{
			var u = Std.parseInt(pa[i]), v = Std.parseInt(pb[i]);
			if (u == null || v == null || Math.abs(u - v) > TOLERANCE) return false;
		}
		return true;
	}

	/** Percent of the cell's pixels that are set in `flags`, a whole-image map. **/
	static function cellPercent(flags:Vector<Bool>, width:Int, column:Int, row:Int, ?except:Int):Float
	{
		var count = 0;
		for (y in 0...CELL_H)
			for (x in 0...CELL_W)
			{
				var py = row * CELL_H + y;
				if (!flags[py * width + column * CELL_W + x]) continue;
				if (except != null && flags[py * width + except * CELL_W + x]) continue;
				count++;
			}
		return 100.0 * count / (CELL_W * CELL_H);
	}

	/** A row per scene row, a percent per mode; with `beyondNormal`, leaving out what the row's NORMAL cell has set too. **/
	static function cellTable(flags:Vector<Bool>, width:Int, columns:Int, beyondNormal:Bool):Array<Array<Dynamic>>
	{
		return [
			for (row in 0...ROWS.length)
				([ROWS[row]] : Array<Dynamic>).concat([
					for (column in 0...columns)
						Html.percent(cellPercent(flags, width, column, row, beyondNormal ? 0 : null))
				])
		];
	}

	/** Percent of the cell's pixels off where the row's NORMAL cell is not; marks them in `beyond`. **/
	static function percentBeyondNormal(off:Vector<Bool>, width:Int, column:Int, row:Int, beyond:Vector<Bool>):Float
	{
		var count = 0;
		for (y in 0...CELL_H)
			for (x in 0...CELL_W)
			{
				var line = (row * CELL_H + y) * width;
				var here = off[line + column * CELL_W + x] && !off[line + x];
				beyond[line + column * CELL_W + x] = here;
				if (here) count++;
			}
		return 100.0 * count / (CELL_W * CELL_H);
	}

	/**
		Percent of a text-row cell's pixels off by more than the tolerance from what Flash would show,
		predicted from the row's bar-less cell: c is how much of a pixel the text (or ring) covers and
		d the covered part's colour; the opaque bar S over y 44..56 gives (1 - c) S + c formula(d) for
		NORMAL, SUBTRACT and INVERT, the grey ground for ERASE (it cuts everything under it) and the
		bar-less cell for ALPHA (it keeps everything).
	**/
	static function percentOffPrediction(capture:Pixels, column:Int, row:Int, mode:BlendMode, textColor:Int, hasRing:Bool):Float
	{
		var text = [(textColor >> 16) & 0xFF, (textColor >> 8) & 0xFF, textColor & 0xFF];
		var grey = (GROUND >> 16) & 0xFF;
		var bar = [(BAR >> 16) & 0xFF, (BAR >> 8) & 0xFF, BAR & 0xFF];
		var textLength = 0.0;
		for (t in text) textLength += (t - grey) * (t - grey);
		var count = 0;
		for (y in 0...CELL_H)
			for (x in 0...CELL_W)
			{
				var bx = BARLESS * CELL_W + x, py = row * CELL_H + y;
				var barless = [capture.red(bx, py), capture.green(bx, py), capture.blue(bx, py)];
				var predicted:Array<Float> = [for (v in barless) v];
				if (y >= 44 && y < 56 && x >= 4 && x < 116)
				{
					var projection = 0.0;
					for (i in 0...3) projection += (barless[i] - grey) * (text[i] - grey);
					var c = Math.min(Math.max(projection / textLength, 0), 1);
					var d:Array<Float> = [for (i in 0...3) c > 0 ? text[i] : grey];
					var inRing = x >= 20 && x < 100 && y >= 20 && y < 80 && !(x >= 45 && x < 75 && y >= 35 && y < 65);
					if (hasRing && inRing)
					{
						c = 1.0;
						d = [for (v in barless) v];
					}
					for (i in 0...3)
					{
						var s = bar[i] / 255.0;
						predicted[i] = switch (mode)
						{
							case ERASE: grey;
							case ALPHA: barless[i];
							case SUBTRACT: ((1 - c) * s + c * Math.max(0, d[i] / 255.0 - s)) * 255;
							case INVERT: ((1 - c) * s + c * (1 - d[i] / 255.0)) * 255;
							default: ((1 - c) * s + c * s) * 255;
						}
					}
				}
				var px = column * CELL_W + x;
				var actual = [capture.red(px, py), capture.green(px, py), capture.blue(px, py)];
				for (i in 0...3)
					if (Math.abs(actual[i] - predicted[i]) > TOLERANCE)
					{
						count++;
						break;
					}
			}
		return 100.0 * count / (CELL_W * CELL_H);
	}
}
