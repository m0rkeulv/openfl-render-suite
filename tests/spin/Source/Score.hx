package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.TestRun;

/**
	Every rotated cell against the same cell of the AIR window, with the edges apart: a rotated
	edge is anti-aliased differently by every rasteriser, so the pixels within BAND of an edge of
	the object's fill or core rectangle, and within 1.7 times that of a bitmap's footprint edge
	(a sampled edge, two pixels of ramp on AIR and Cairo), rotated as Main rotates them on the
	capture frame, are counted apart. Percent of each cell's interior off by more than the
	tolerance and the count of off edge pixels, per case and starting angle; the score is the
	worst interior.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var BAND = 1.5;
	static inline var CELL = Main.CELL;
	static inline var SIZE = Main.SIZE;
	/** Mask colour of an off pixel on an edge. **/
	static inline var EDGE_MARK = 0xD99A2B;
	static var KINDS = ["bitmap", "shape", "container"];
	static var MODES = ["ALPHA", "ERASE", "SUBTRACT", "INVERT", "DIFFERENCE", "DIFFERENCE on the stage"];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Every cell of the capture is compared with the same cell of this picture of the AIR window.");
		var mask = Compare.mask(capture, air, TOLERANCE);
		var worst = 0.0, worstCell:String = null;
		var rows:Array<Array<Dynamic>> = [], edgeRows:Array<Array<Dynamic>> = [];
		for (c in 0...18)
		{
			var kind = Std.int(c / 6), mode = c % 6;
			var row = c >> 1, group = c & 1;
			var interior:Array<Dynamic> = [KINDS[kind], MODES[mode]];
			var edges:Array<Dynamic> = [KINDS[kind], MODES[mode]];
			for (i in 0...Main.ANGLES.length)
			{
				var band = edgeBand(kind, Main.ANGLES[i] + Main.CAPTURE_FRAME * Main.SPEED);
				var x0 = (group * 8 + i) * CELL, y0 = row * CELL;
				var inside = 0, off = 0, edgeOff = 0;
				for (y in 0...CELL)
					for (x in 0...CELL)
					{
						var d = capture.channelDiff(x0 + x, y0 + y, air, x0 + x, y0 + y);
						if (band[y * CELL + x])
						{
							if (d > TOLERANCE)
							{
								edgeOff++;
								mask.set(x0 + x, y0 + y, EDGE_MARK);
							}
						}
						else
						{
							inside++;
							if (d > TOLERANCE) off++;
						}
					}
				var percent = 100.0 * (off / inside);
				interior.push(Html.percent(percent));
				edges.push(edgeOff);
				if (percent > worst)
				{
					worst = percent;
					worstCell = '${KINDS[kind]} ${MODES[mode]} from ${Main.ANGLES[i]} deg';
				}
			}
			rows.push(interior);
			edgeRows.push(edges);
		}
		var columns = ["kind", "mode"].concat([for (a in Main.ANGLES) 'from $a deg']);
		run.table('Percent of each rotated cell\'s interior off the AIR window by more than $TOLERANCE, per starting angle (edge pixels left out)', columns, rows);
		run.table('Pixels on the anti-aliased edges of each rotated cell off the AIR window by more than $TOLERANCE, per starting angle', columns, edgeRows,
			"Every rasterizer anti-aliases a rotated edge differently, so these are counted apart from the interior percent.");
		run.score("worst interior", worst, "%", worstCell != null ? "worst interior: " + worstCell : null);
		run.image("mask_air", mask, "Pixels off against AIR: red inside, amber on an edge", "capture");
	}

	/**
		Per pixel of a cell: true within BAND of an edge of the object's rectangles (object space,
		with their band scale) turned by `angle` degrees about the cell's centre. The rectangles are
		the fill and the core (bitmap and shape) or the inner square (container), and a Bitmap's
		whole footprint, since under ALPHA the cut of the backdrop ends at the bitmap's edge; a
		shape's margin has no fill, so no edge there.
	**/
	static function edgeBand(kind:Int, angle:Float):Array<Bool>
	{
		var m = SIZE >> 2, c = (SIZE - 2 * m) >> 2, half = SIZE >> 1;
		var fill = [[m, m, SIZE - m, SIZE - m, 1.0], [half - c, half - c, half + c, half + c, 1.0]];
		var footprint = [0, 0, SIZE, SIZE, 1.7];
		var rects:Array<Array<Float>> = switch (kind)
		{
			case 0: [footprint].concat(fill);
			case 1: fill;
			default: [footprint, [m, m, SIZE - m, SIZE - m, 1.0], [SIZE >> 2, SIZE >> 2, (SIZE >> 2) + half, (SIZE >> 2) + half, 1.0]];
		}
		var radians = angle * (Math.PI / 180);
		var cos = Math.cos(radians), sin = Math.sin(radians);
		var band = [];
		for (y in 0...CELL)
			for (x in 0...CELL)
			{
				var px = x + 0.5 - CELL / 2, py = y + 0.5 - CELL / 2;
				// back to object space, centred: rotated by -angle
				var ox = cos * px + sin * py + SIZE / 2;
				var oy = -sin * px + cos * py + SIZE / 2;
				var on = false;
				for (r in rects)
				{
					var b = BAND * r[4];
					var insideX = ox >= r[0] - b && ox <= r[2] + b, insideY = oy >= r[1] - b && oy <= r[3] + b;
					var dx = Math.min(Math.abs(ox - r[0]), Math.abs(ox - r[2])), dy = Math.min(Math.abs(oy - r[1]), Math.abs(oy - r[3]));
					if ((insideY && dx < b) || (insideX && dy < b)) on = true;
				}
				band.push(on);
			}
		return band;
	}
}
