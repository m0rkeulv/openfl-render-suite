package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Every cell against the same cell of the AIR window: percent of its pixels off by more than the
	tolerance, per case (kind and mode) and object size. The score is the worst cell.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL = Main.CELL;
	static var KINDS = ["bitmap", "shape", "container"];
	static var MODES = ["ALPHA", "ERASE", "SUBTRACT", "INVERT", "DIFFERENCE", "DIFFERENCE on the stage"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Every cell of the capture is compared with the same cell of this picture of the AIR window.");
		var worst = 0.0, worstCell:String = null;
		var rows:Array<Array<Dynamic>> = [];
		for (c in 0...18)
		{
			var kind = Std.int(c / 6), mode = c % 6;
			var row = c >> 1, group = c & 1;
			var cells:Array<Dynamic> = [KINDS[kind], MODES[mode]];
			for (i in 0...Main.SIZES.length)
			{
				var d = Compare.same(capture, air, (group * 8 + i) * CELL, row * CELL, CELL, CELL, TOLERANCE);
				cells.push(Html.percent(d.off));
				if (d.off > worst)
				{
					worst = d.off;
					worstCell = '${KINDS[kind]} ${MODES[mode]} at ${Main.SIZES[i]} px';
				}
			}
			rows.push(cells);
		}
		run.table('Percent of each cell\'s pixels off the AIR window by more than $TOLERANCE, per object size',
			["kind", "mode"].concat([for (s in Main.SIZES) '$s px']), rows);
		run.score("worst cell", worst, "%", worstCell);
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR", "capture");
	}
}
