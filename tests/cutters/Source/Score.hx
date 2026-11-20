package;

import rendertest.Compare;
import rendertest.Html;
import rendertest.Pixels;
import rendertest.TestRun;

/**
	What the ERASE / ALPHA bar did in every cell, read from a few pixels, against what it did in AIR's
	window; and every cell against the AIR window pixel by pixel. The score is the number of cells
	whose reading differs from the AIR window's.

	A cell's bar over the ring reads "cut" (the stage shows through an ERASE bar, the ring is dimmed
	under an ALPHA bar), "not drawn" (the ring as it is), "as is" (the bar's orange) or the RGB
	values; the ring beside the bar is read too, so a container that dims or tints its content still
	reads. The last row reads the SUBTRACT bar in the hole under the ERASE bar ("black": the ERASE bar
	counted as touching, "as is": it did not) and beyond the ring.
**/
class Score
{
	static inline var TOLERANCE = 8;
	static inline var CELL_W = Main.CELL_W;
	static inline var CELL_H = Main.CELL_H;
	static var COLUMNS = [
		"plain", "alpha .5", "MULTIPLY", "ADD", "cacheAsBitmap", "filter", "scrollRect", "mask",
		"LAYER > plain", "bar cached", "bar filtered", "alpha .5 cached"
	];
	static var ROWS = [
		"ERASE bar", "ALPHA bar at .5", "ERASE, ring under the container", "in a LAYER: ERASE bar", "in a LAYER: ALPHA bar at .5",
		"in a LAYER: ERASE down, SUBTRACT bar"
	];
	static var GREY = [128.0, 128, 128];
	static var ORANGE = [242.0, 90, 26];
	static var BLACK = [0.0, 0, 0];

	public static function score(run:TestRun):Void
	{
		var capture = run.capture;
		var air = run.reference("air", "AIR window (reference)", "Every cell's reading and pixels are compared with this picture of the AIR window.");
		var airDraw = run.reference("air_draw", "AIR draw()",
			"AIR's BitmapData.draw of the same stage, for comparison: it applies ERASE and ALPHA where the window does not draw them.");

		var readings = readAll(capture);
		var airReadings = readAll(air);
		var drawReadings = readAll(airDraw);
		run.table("What the bar did over the ring, per container kind (columns) and capture", ["row"].concat(COLUMNS),
			[for (row in 0...ROWS.length) [ROWS[row]].concat(readings[row])],
			'"cut": the stage shows through an ERASE bar, the ring is dimmed under an ALPHA bar; "not drawn": the ring as it is; "as is": the bar\'s orange; otherwise the RGB values. The last row reads the SUBTRACT bar in the hole / beyond the ring.');
		var referenceRows:Array<Array<Dynamic>> = [];
		for (reference in [{name: "AIR window", readings: airReadings}, {name: "AIR draw()", readings: drawReadings}])
			for (row in 0...ROWS.length)
				referenceRows.push([reference.name, ROWS[row]].concat(reference.readings[row]));
		run.table("What the bar did over the ring in AIR's window and AIR's draw()", ["capture", "row"].concat(COLUMNS), referenceRows,
			"The score counts the cells whose reading differs from the AIR window's.");

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

		var differing = 0;
		for (row in 0...ROWS.length)
			for (column in 0...COLUMNS.length)
				if (!sameReading(readings[row][column], airReadings[row][column])) differing++;
		run.score("cells read differently", differing, "cells",
			'cells whose reading differs from the AIR window\'s; worst cell ${Html.fixed(worst, 1)}% of its pixels off');
		run.image("mask_air", Compare.mask(capture, air, TOLERANCE), "Pixels off against AIR's window", "capture");
	}

	/** The readings of every cell, by row and column. **/
	static function readAll(image:Pixels):Array<Array<String>>
	{
		return [for (row in 0...ROWS.length) [for (column in 0...COLUMNS.length) reading(image, column, row)]];
	}

	/**
		What the bar did over the ring at (30, 51) of the cell, given the ring beside it at (30, 30); in
		row 5, what the orange SUBTRACT bar shows in the hole under the green ERASE bar at (60, 51), and
		beyond the ring at (10, 51).
	**/
	static function reading(image:Pixels, column:Int, row:Int):String
	{
		var left = column * CELL_W, top = row * CELL_H;
		var ring = rgb(image, left + 30, top + 30), bar = rgb(image, left + 30, top + 51);
		if (row == 5)
		{
			var hole = rgb(image, left + 60, top + 51), beyond = rgb(image, left + 10, top + 51);
			return (near(hole, BLACK) ? "black" : near(hole, ORANGE) ? "as is" : text(hole)) + " / " + (near(beyond, ORANGE) ? "as is" : text(beyond));
		}
		var alphaRow = row == 1 || row == 4;
		if (near(bar, ring)) return "not drawn";
		if (near(bar, ORANGE) || (alphaRow && near(bar, middle(ORANGE, ring)))) return "as is";
		if (!alphaRow && near(bar, GREY)) return "cut";
		if (alphaRow && near(bar, middle(ring, GREY))) return "cut";
		return text(bar);
	}

	/** Whether two readings name the same thing: equal names, or RGB values within the tolerance of each other. **/
	static function sameReading(a:String, b:String):Bool
	{
		var partsA = a.split(" / "), partsB = b.split(" / ");
		if (partsA.length != partsB.length) return false;
		for (i in 0...partsA.length)
		{
			if (partsA[i] == partsB[i]) continue;
			var valuesA = values(partsA[i]), valuesB = values(partsB[i]);
			if (valuesA == null || valuesB == null) return false;
			for (k in 0...3)
				if (Math.abs(valuesA[k] - valuesB[k]) > TOLERANCE) return false;
		}
		return true;
	}

	/** The three numbers of an "r,g,b" reading, or null for a name. **/
	static function values(reading:String):Array<Int>
	{
		var parts = reading.split(",");
		if (parts.length != 3) return null;
		var numbers:Array<Int> = [];
		for (part in parts)
		{
			var number = Std.parseInt(part);
			if (number == null) return null;
			numbers.push(number);
		}
		return numbers;
	}

	static function rgb(image:Pixels, x:Int, y:Int):Array<Float>
	{
		return [image.red(x, y), image.green(x, y), image.blue(x, y)];
	}

	static function near(a:Array<Float>, b:Array<Float>):Bool
	{
		for (k in 0...3)
			if (Math.abs(a[k] - b[k]) > TOLERANCE) return false;
		return true;
	}

	static function middle(a:Array<Float>, b:Array<Float>):Array<Float>
	{
		return [for (k in 0...3) (a[k] + b[k]) / 2];
	}

	static function text(color:Array<Float>):String
	{
		return [for (c in color) Std.int(c)].join(",");
	}
}
