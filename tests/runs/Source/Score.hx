package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Every cell of the capture against the same cell of the AIR window: the percent of its pixels
	whose largest channel difference is over the tolerance. The score is the worst cell.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL_W = Main.CELL_W;
	static inline var CELL_H = Main.CELL_H;
	static var COLUMNS = ["S S S", "S, normal, S", "S I S", "S, erase, S, alpha", "S, nested layer, S", "S.5 I.5 S"];
	static var ROWS = [
		"ring first", "bar first, then the ring", "layer at alpha .6, bars overlapping",
		"over nothing: erase/normal.5, invert/normal.5, subtract/invert, alpha/invert, erase/invert, invert/alpha",
		"ring at alpha .5", "ring at alpha .25"
	];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air");
		var worst = 0.0;
		var rows:Array<Array<Dynamic>> = [];
		for (row in 0...ROWS.length)
		{
			var cells:Array<Dynamic> = [ROWS[row]];
			for (column in 0...COLUMNS.length)
			{
				var d = Compare.same(capture, air, column * CELL_W, row * CELL_H, CELL_W, CELL_H, TOLERANCE);
				var off = d.off;
				if (off > worst) worst = off;
				cells.push(Html.percent(off));
			}
			rows.push(cells);
		}
		run.table('Percent of each cell\'s pixels off the AIR window by more than $TOLERANCE', ["row"].concat(COLUMNS), rows);
		run.score("worst cell", worst, "%", "the cell furthest from the AIR window");
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
	}
}
