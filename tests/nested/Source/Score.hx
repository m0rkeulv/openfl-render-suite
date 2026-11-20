package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Every cell of the capture against the same cell of the AIR window: the percent of its pixels
	whose largest channel difference is over the tolerance, and that largest difference. The
	score is the worst cell.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static inline var COLUMNS = 4;
	static var NAMES = [
		"mask last", "ALPHA then red", "ALPHA over a cut", "ALPHA over nothing", "ERASE, ADD over it", "ALPHA, SUBTRACT over it",
		"ALPHA, INVERT over it", "INVERT half over nothing", "nested layer, mask", "nested layer, order", "ADD container", "ALPHA container",
		"ALPHA shape over a cut", "mask at alpha .5", "layer at alpha .5", "ERASE in an empty layer",
		"inner layer, ERASE shape", "inner layer, bitmap, ALPHA shape", "inner layer, shape, ALPHA bitmap", "bitmap mask two layers down",
		"17 without outer backdrop", "17 with a sprite between", "17 with a shape before", "24: 23 without outer backdrop"
	];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air");
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (i in 0...NAMES.length)
		{
			var d = Compare.same(capture, air, (i % COLUMNS) * CELL, Std.int(i / COLUMNS) * CELL, CELL, CELL, TOLERANCE);
			var off = d.off;
			if (off > worst) worst = off;
			rows.push([i + 1, NAMES[i], Html.percent(off, d.max)]);
		}
		run.table('Percent of each cell\'s pixels off the AIR window by more than $TOLERANCE, with the largest channel difference',
			["cell", "case", run.label], rows);
		run.score("worst cell", worst, "%", "the cell furthest from the AIR window");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
	}
}
