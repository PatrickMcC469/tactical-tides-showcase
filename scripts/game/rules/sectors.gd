## The 5x5 zone system on top of the 20x20 board.
##
## The 20x20 grid divides into a 4x4 arrangement of 5x5 sectors, labelled like the notebook:
## row letter A-D (top to bottom) + column number 1-4 (left to right). So:
##   A1 A2 A3 A4
##   B1 B2 B3 B4
##   C1 C2 C3 C4
##   D1 D2 D3 D4
## Cells are Vector2i(x, y) with x = column 0..19, y = row 0..19.
## Sectors are Vector2i(sx, sy) with sx, sy = 0..3.
class_name Sectors
extends RefCounted

const BOARD_SIZE := 20
const SECTOR_SIZE := 5
const SECTORS_PER_AXIS := BOARD_SIZE / SECTOR_SIZE  # 4

static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE

## Which sector a cell belongs to.
static func sector_of(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x / SECTOR_SIZE, cell.y / SECTOR_SIZE)

## Sector label, e.g. Vector2i(0,0) -> "A1", Vector2i(3,3) -> "D4".
static func label(sector: Vector2i) -> String:
	var row_letter := char(65 + sector.y)  # 65 == 'A'
	return "%s%d" % [row_letter, sector.x + 1]

## Parse a label like "A1" back into sector coords. Returns Vector2i(-1,-1) if invalid.
static func from_label(text: String) -> Vector2i:
	if text.length() < 2:
		return Vector2i(-1, -1)
	var sy := text.to_upper().unicode_at(0) - 65
	var sx := text.substr(1).to_int() - 1
	var s := Vector2i(sx, sy)
	return s if is_valid_sector(s) else Vector2i(-1, -1)

static func is_valid_sector(sector: Vector2i) -> bool:
	return sector.x >= 0 and sector.x < SECTORS_PER_AXIS and sector.y >= 0 and sector.y < SECTORS_PER_AXIS

## All cells inside a sector (25 of them).
static func cells_in_sector(sector: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ox := sector.x * SECTOR_SIZE
	var oy := sector.y * SECTOR_SIZE
	for dy in SECTOR_SIZE:
		for dx in SECTOR_SIZE:
			cells.append(Vector2i(ox + dx, oy + dy))
	return cells

## Every sector on the board (16 of them), in reading order A1..D4.
static func all_sectors() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for sy in SECTORS_PER_AXIS:
		for sx in SECTORS_PER_AXIS:
			out.append(Vector2i(sx, sy))
	return out
