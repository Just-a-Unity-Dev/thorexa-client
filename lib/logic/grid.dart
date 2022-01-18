part of logic;

var inBruteForce = false;

class LastVars {
  Offset lastPos;
  int lastRot;

  LastVars(this.lastRot, int x, int y)
      : lastPos = Offset(
          x.toDouble(),
          y.toDouble(),
        );

  LastVars get copy =>
      LastVars(lastRot, lastPos.dx.toInt(), lastPos.dy.toInt());
}

// For cells destroyed by entering destruction cells
class BrokenCell {
  String id;
  int rot;
  int x;
  int y;
  LastVars lv;

  BrokenCell(this.id, this.rot, this.x, this.y, this.lv);

  void render(Canvas canvas, double t) {
    final screenRot = lerpRotation(lv.lastRot, rot, t) * halfPi;
    final sx = lerp(lv.lastPos.dx, x, t);
    final sy = lerp(lv.lastPos.dy, y, t);

    final screenSize = Vector2(cellSize, cellSize);

    var screenPos = Vector2(sx, sy) * cellSize + screenSize / 2;

    screenPos = rotateOff(screenPos.toOffset(), -screenRot).toVector2();

    screenPos -= screenSize / 2;

    canvas.save();

    canvas.rotate(screenRot);

    Sprite(Flame.images.fromCache('$id.png'))
        .render(canvas, position: screenPos, size: screenSize);

    canvas.restore();
  }
}

class Cell {
  String id = "empty";
  int rot = 0;
  LastVars lastvars;
  bool updated = false;
  Map<String, dynamic> data = {};
  List<String> tags = [];

  Cell(int x, int y) : lastvars = LastVars(0, x, y);

  Cell get copy {
    final c = Cell(lastvars.lastPos.dx.toInt(), lastvars.lastPos.dy.toInt());

    c.id = id;
    c.rot = rot;
    c.updated = updated;
    c.lastvars.lastRot = lastvars.lastRot;

    data.forEach((key, value) => c.data[key] = value);
    for (var tag in tags) {
      c.tags.add(tag);
    }

    return c;
  }
}

Grid grid = Grid(100, 100);

class GridUpdateConstraints {
  int sx;
  int sy;
  int ex;
  int ey;

  GridUpdateConstraints(this.sx, this.sy, this.ex, this.ey);
}

class Grid {
  late List<List<Cell>> grid;
  late List<List<bool>> place;
  late List<List<Set<String>>> chunks;

  List<BrokenCell> brokenCells = [];

  void addBroken(Cell cell, int dx, int dy, [int? rlvx, int? rlvy]) {
    final b = BrokenCell(cell.id, cell.rot, dx, dy, cell.lastvars);

    if (rlvx != null) b.lv.lastPos = Offset(rlvx.toDouble(), b.lv.lastPos.dy);
    if (rlvy != null) b.lv.lastPos = Offset(b.lv.lastPos.dx, rlvy.toDouble());

    brokenCells.add(b);
  }

  var chunkSize = 25;

  void reloadChunks() {
    chunks = [];
    final chunkWidth = ceil(width / chunkSize);
    final chunkHeight = ceil(height / chunkSize);

    for (var x = 0; x < chunkWidth; x++) {
      chunks.add([]);
      for (var y = 0; y < chunkHeight; y++) {
        chunks.last.add(<String>{});
      }
    }
  }

  int width;
  int height;

  int tickCount = 0;

  bool wrap = false;

  Set<String> cells = {};

  GridUpdateConstraints? updateConstraints;

  void remake() {
    grid = [];
    place = [];
    reloadChunks();
    for (var x = 0; x < width; x++) {
      grid.add([]);
      place.add([]);
      for (var y = 0; y < height; y++) {
        grid.last.add(Cell(x, y));
        place.last.add(false);
      }
    }
  }

  void setConstraints(int sx, int sy, int ex, int ey) {
    updateConstraints = GridUpdateConstraints(sx, sy, ex, ey);
  }

  // Only call this for manually changing id, grid.set() already does it for you
  void setChunk(int x, int y, String id) {
    if (wrap) {
      chunks[floor(((x + width) % width) / chunkSize)]
              [floor(((y + height) % height) / chunkSize)]
          .add(id);
    }
    chunks[x ~/ chunkSize][y ~/ chunkSize].add(id);
  }

  void forEach(void Function(Cell cell, int x, int y) callback,
      [int? wantedDirection, String? id]) {
    if (id != null) {
      var sx = 0;
      var sy = 0;
      var ex = ceil(width / chunkSize);
      var ey = ceil(height / chunkSize);

      if (updateConstraints != null) {
        sx = ceil(updateConstraints!.sx / chunkSize);
        sy = ceil(updateConstraints!.sy / chunkSize);
        ex = ceil(updateConstraints!.ex / chunkSize);
        ey = ceil(updateConstraints!.ey / chunkSize);
      }

      for (var cx = sx; cx < ex; cx++) {
        for (var cy = sy; cy < ey; cy++) {
          if (chunks[cx][cy].contains(id)) {
            final startx = cx * chunkSize;
            final starty = cy * chunkSize;
            final endx = startx + chunkSize;
            final endy = starty + chunkSize;
            for (var x = startx; x < endx; x++) {
              for (var y = starty; y < endy; y++) {
                if ((x >= 0 && x < width && y >= 0 && y < height)) {
                  final cell = at(x, y);
                  if (cell.updated == false) {
                    if (cell.id == id &&
                        cell.rot == (wantedDirection ?? cell.rot)) {
                      cell.updated = true;
                      callback(cell, x, y);
                    }
                  }
                }
              }
            }
          }
        }
      }
      return;
    }
    var sx = 0;
    var sy = 0;
    var ex = width;
    var ey = height;

    if (updateConstraints != null) {
      sx = updateConstraints!.sx;
      sy = updateConstraints!.sy;
      ex = updateConstraints!.ex;
      ey = updateConstraints!.ey;
    }

    for (var x = sx; x < ex; x++) {
      for (var y = sy; y < ey; y++) {
        if (inside(x, y)) {
          final cell = at(x, y);
          if (cell.rot == (wantedDirection ?? cell.rot)) {
            callback(cell, x, y);
          }
        }
      }
    }
  }

  Grid(this.width, this.height) {
    remake();
  }

  inside(int x, int y) {
    if (wrap) return true;
    return (x >= 0 && x < width && y >= 0 && y < height);
  }

  Cell at(int x, int y) {
    if (wrap) {
      return grid[(x + width) % width][(y + height) % height];
    }
    return grid[x][y];
  }

  void set(int x, int y, Cell cell) {
    if (wrap) {
      if (cell.id == "place") {
        place[(x + width) % width][(y + height) % height] =
            !place[(x + width) % width][(y + height) % height];
        return;
      }
      grid[(x + width) % width][(y + height) % height] = cell;
      chunks[floor(((x + width) % width) / chunkSize)]
              [floor(((y + height) % height) / chunkSize)]
          .add(cell.id);
      return;
    }
    if (!inside(x, y)) return;
    if (cell.id == "place") {
      place[x][y] = !place[x][y];
      return;
    }
    grid[x][y] = cell;
    chunks[floor(x / chunkSize)][floor(y / chunkSize)].add(cell.id);
  }

  bool placeable(int x, int y) {
    if (wrap) {
      return place[(x + width) % width][(y + height) % height];
    }
    if (!inside(x, y)) return false;
    return place[x][y];
  }

  Grid get copy {
    final grid = Grid(width, height);
    grid.wrap = wrap;
    forEach(
      (p0, p1, p2) {
        if (placeable(p1, p2)) grid.place[p1][p2] = true;
        grid.set(p1, p2, p0.copy);
      },
    );
    return grid;
  }

  bool get movable {
    for (var passThrough in justMoveInsideOf) {
      if (cells.contains(passThrough)) return true;
    }
    return false;
  }

  Set<String> getCells() {
    if (brokenCells.length > 0) {
      playSound(destroySound);
    }
    brokenCells = [];
    final cells = <String>{};
    forEach(
      (p0, p1, p2) {
        p0.updated = false;
        p0.lastvars = LastVars(p0.rot, p1, p2);
        p0.tags = [];
        cells.add(p0.id);
      },
    );

    return cells;
  }

  void rotate(int x, int y, int rot) {
    if (!inside(x, y)) return;
    final id = at(x, y).id;
    if (id == "empty" || id == "wall_puzzle" || id == "wall" || id == "ghost")
      return;
    at(x, y).rot += rot;
    at(x, y).rot %= 4;
    if (id == "sync") {
      doSync(x, y, -1, rot);
    }
  }

  double get emptyPercantage {
    var empty = 0;
    var count = 0;

    forEach(
      (element, x, y) {
        count++;
        if (element.id == "empty") {
          empty++;
        }
      },
    );

    return empty / count;
  }

  void refreshChunks() {}

  void update() {
    tickCount++;
    cells = getCells();
    if (tickCount % 10 == 0) {
      refreshChunks();
    }

    final subticks = [
      if (cells.contains("stopper")) stoppers,
      if (cells.containsAny(CellTypeManager.mechanical)) mechs,
      if (cells.contains("releaser")) releasers,
      if (cells.contains("mirror")) mirrors,
      if (cells.containsAny(CellTypeManager.generators)) gens,
      if (cells.contains("replicator")) reps,
      if (cells.contains("tunnel")) tunnels,
      if (cells.containsAny(CellTypeManager.rotators)) rots,
      if (cells.containsAny(CellTypeManager.gears)) gears,
      if (cells.containsAny(CellTypeManager.grabbers)) grabbers,
      if (cells.containsAny(CellTypeManager.movers)) movers,
      if (cells.containsAny(CellTypeManager.puller)) pullers,
      if (cells.contains("liner")) liners,
      if (cells.contains("bird")) birds,
      if (cells.containsAny(CellTypeManager.fans)) fans,
      //if (cells.contains("magnet")) magnets,
      //if (cells.contains("digger")) diggers,
      if (cells.contains("karl")) karls,
      if (cells.contains("darty")) dartys,
      if (cells.containsAny(CellTypeManager.puzzles)) puzzles,
      if (cells.contains("pmerge")) pmerges,
    ];

    final subticking = storage.getBool('subtick') ?? false;
    if (subticking) {
      var subtick = subticks[tickCount % subticks.length];
      if (subtick is void Function(Set<String>)) {
        subtick(cells);
      } else {
        subtick();
      }
    } else {
      for (var subtick in subticks) {
        if (subtick is void Function(Set<String>)) {
          subtick(cells);
        } else {
          subtick();
        }
      }
    }
  }
}

// Grid Clipboard
class GridClip {
  int width = 0;
  int height = 0;

  List<List<Cell>> cells = [];

  bool active = false;

  void activate(int width, int height, List<List<Cell>> cells) {
    this.width = width;
    this.height = height;
    this.cells = cells;
    this.active = true;
  }

  void place(int x, int y) {
    for (var cx = 0; cx < width; cx++) {
      for (var cy = 0; cy < height; cy++) {
        final sx = cx + x;
        final sy = cy + y;
        if (grid.inside(sx, sy) && cells[cx][cy].id != "empty") {
          cells[cx][cy].lastvars = LastVars(cells[cx][cy].rot, sx, sy);
          grid.set(sx, sy, cells[cx][cy].copy);
        }
      }
    }
  }

  void render(Canvas canvas, int x, int y) {
    for (var cx = 0; cx < width; cx++) {
      for (var cy = 0; cy < height; cy++) {
        if (cells[cx][cy].id != "empty") {
          canvas.save();
          final rot = cells[cx][cy].rot * halfPi;
          final sx = cx + x;
          final sy = cy + y;
          final off = rotateOff(
                Offset(
                    sx * cellSize + cellSize / 2, sy * cellSize + cellSize / 2),
                -rot,
              ) -
              Offset(
                    cellSize,
                    cellSize,
                  ) /
                  2;
          canvas.rotate(rot);
          (Sprite(Flame.images.fromCache('${cells[cx][cy].id}.png'))
                ..paint = (Paint()..color = Colors.white.withOpacity(0.2)))
              .render(
            canvas,
            position: Vector2(off.dx, off.dy),
            size: Vector2.all(
              cellSize.toDouble(),
            ),
          );

          canvas.restore();
        }
      }
    }
  }

  void rotate(RotationalType rt) {
    if (rt == RotationalType.counter_clockwise) {
      final copy = <List<Cell>>[];
      for (var i = 0; i < height; i++) {
        copy.add(<Cell>[]);
        for (var j = 0; j < width; j++) {
          copy.last.add(Cell(j, i));
        }
      }

      for (var x = 0; x < width; x++) {
        for (var y = 0; y < height; y++) {
          copy[y][x] = cells[height - x - 1][y];
          copy[y][x].rot += 3;
          copy[y][x].rot %= 4;
        }
      }

      cells = copy;
      game.selH = width;
      game.selW = height;
      final tmp = width;
      width = height;
      height = tmp;
    } else if (rt == RotationalType.clockwise) {
      final copy = <List<Cell>>[];
      for (var i = 0; i < height; i++) {
        copy.add(<Cell>[]);
        for (var j = 0; j < width; j++) {
          copy.last.add(Cell(j, i));
        }
      }

      for (var x = 0; x < width; x++) {
        for (var y = 0; y < height; y++) {
          copy[y][x] = cells[x][width - y - 1];
          copy[y][x].rot += 3;
          copy[y][x].rot %= 4;
        }
      }

      cells = copy;
      game.selH = width;
      game.selW = height;
      final tmp = width;
      width = height;
      height = tmp;
    }
  }
}
