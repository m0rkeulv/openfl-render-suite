package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	Every cell of the capture against the same cell of the AIR window: the percent of its pixels
	whose largest channel difference is over the tolerance. The score is the worst cell.

	The transparent variant (_t) is compared with AIR's transparent window, air_t.png: PrintWindow
	gives a transparent window's pixels over black, which is what a native window shows under a
	transparent stage too. The OpenFL window shows the colours of its buffer whatever their alpha, so
	the capture's colours are compared as they are and its alpha is left out. The window has no alpha
	to tell black from nothing, so a second table shows the capture's alpha at the telling pixels beside
	what AIR's draw() of the transparent stage holds there (air_t_draw.png, alpha kept).
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL_W = Main.CELL_W;
	static inline var CELL_H = Main.CELL_H;
	static var COLUMNS = ["ring, S", "ring, I", "ring, E", "ring, A", "ring, E across, S", "S over nothing"];
	static var ROWS = ["on the stage", "in a LAYER on the stage"];
	/** The pixels whose alpha tells what the transparent stage holds: name, column, row, x and y in the cell. **/
	static var TELLING:Array<{what:String, column:Int, row:Int, x:Int, y:Int}> = [
		{what: "S over nothing, on the stage", column: 5, row: 0, x: 60, y: 51},
		{what: "S over nothing, in a LAYER", column: 5, row: 1, x: 60, y: 51},
		{what: "S in the ring's hole, on the stage", column: 0, row: 0, x: 60, y: 51},
		{what: "S in the ring's hole, in a LAYER", column: 0, row: 1, x: 60, y: 51},
		{what: "I over nothing (beyond the ring), on the stage", column: 1, row: 0, x: 10, y: 51},
		{what: "E over the ring, on the stage", column: 2, row: 0, x: 30, y: 51},
		{what: "E over the ring, in a LAYER", column: 2, row: 1, x: 30, y: 51},
		{what: "S over the cut, on the stage", column: 4, row: 0, x: 60, y: 51}
	];

	public static function score(run:TestRun):Void
	{
		var transparent = run.variant == "_t";
		var air = run.reference("air", transparent ? "AIR window, transparent stage (reference)" : "AIR window (reference)",
			transparent ? "PrintWindow's picture of the transparent AIR window: its pixels over black." : null);
		var capture = run.capture;

		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (row in 0...ROWS.length)
		{
			var cells:Array<Dynamic> = [ROWS[row]];
			for (column in 0...COLUMNS.length)
			{
				var d = Compare.same(capture, air, column * CELL_W, row * CELL_H, CELL_W, CELL_H, TOLERANCE);
				var off = percentOff(d.count, CELL_W * CELL_H);
				if (off > worst) worst = off;
				cells.push(percent(off));
			}
			rows.push(cells);
		}
		run.table('${transparent ? "Transparent" : "Opaque"} stage: percent of each cell\'s pixels off the AIR window by more than $TOLERANCE',
			["row"].concat(COLUMNS), rows);
		run.score("worst cell", worst, "%", "the cell furthest from the AIR window");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");

		if (transparent)
		{
			var draw = run.reference("air_t_draw", "AIR draw(), transparent stage", "AIR's BitmapData.draw of the transparent stage, alpha kept.");
			run.table("Transparent stage: what the capture and AIR's draw() hold at the telling pixels (the window capture has no alpha to tell black from nothing)",
				["pixel", "AIR draw() (r, g, b, alpha)", '${run.label} (r, g, b, alpha)'],
				[for (t in TELLING) [t.what, rgba(draw, t.column * CELL_W + t.x, t.row * CELL_H + t.y), rgba(capture, t.column * CELL_W + t.x, t.row * CELL_H + t.y)]],
				"Where nothing is drawn, alpha 0 means the capture kept the window buffer's alpha; alpha 255 means the window holds the stage over black.");
		}
	}

	static function rgba(image:Pixels, x:Int, y:Int):String
	{
		return '(${image.red(x, y)}, ${image.green(x, y)}, ${image.blue(x, y)}, ${image.alpha(x, y)})';
	}

	/** `count` of `pixels` in percent, divided first as numpy's mean() * 100 is, so a value on a tie rounds as in the Python comparer. **/
	static function percentOff(count:Int, pixels:Int):Float
	{
		return count / pixels * 100.0;
	}

	/** A percent cell: the value to 3 decimals, shown with 1 decimal rounded as Python's "%.1f" (correctly, ties to even). **/
	static function percent(v:Float, ?maximum:Int):Dynamic
	{
		return Html.value(Math.round(v * 1000) / 1000, oneDecimal(v) + "%" + (maximum != null ? ' (max $maximum)' : ""));
	}

	/** `v` (not negative) with one decimal, rounded on the double's exact value. **/
	static function oneDecimal(v:Float):String
	{
		// v * 10 as the exact sum of v * 8 and v * 2 (both exact) and the rounding error of that sum
		var eight = v * 8, two = v * 2;
		var sum = eight + two;
		var back = sum - eight;
		var error = (eight - (sum - back)) + (two - back);
		var tenths = Math.ffloor(sum);
		var aboveHalf = (sum - (tenths + 0.5)) + error;
		var rounded = Std.int(tenths);
		if (aboveHalf > 0 || (aboveHalf == 0 && rounded % 2 == 1)) rounded++;
		return Std.int(rounded / 10) + "." + (rounded % 10);
	}
}
