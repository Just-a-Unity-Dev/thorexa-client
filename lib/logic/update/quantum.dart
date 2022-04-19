part of logic;

void unstableMove(int x, int y, int dir) {
  var cx = x;
  var cy = y;

  final self = grid.at(x, y);
  self.updated = true;

  while (true) {
    cx = frontX(cx, dir);
    cy = frontY(cy, dir);
    if (!grid.inside(cx, cy)) return;

    final c = grid.at(cx, cy);

    if (c.id == "empty") {
      moveCell(x, y, cx, cy, dir);
      return;
    } else if (moveInsideOf(c, cx, cy, dir, MoveType.unkown_move)) {
      push(cx, cy, dir, 99999999999, replaceCell: self.copy);
    }
  }
}

void unstableGen(int x, int y, int dir, Cell self) {
  var cx = x;
  var cy = y;

  while (true) {
    cx = frontX(cx, dir);
    cy = frontY(cy, dir);
    if (!grid.inside(cx, cy)) return;

    final c = grid.at(cx, cy);

    if (c.id == "empty") {
      grid.set(cx, cy, self);
      return;
    } else if (moveInsideOf(c, cx, cy, dir, MoveType.unkown_move)) {
      push(cx, cy, dir, 99999999999, replaceCell: self.copy);
    }
  }
}

void doField(Cell cell, int x, int y) {
  //print("Help ${cell.lifespan}");
  //final iteration = cell.lifespan;
  final rng = Random();
  final nx = rng.nextInt(grid.width);
  final ny = rng.nextInt(grid.height);

  final randomStuff = rng.nextInt(cells.length * 200);
  final randomRot = rng.nextInt(4);

  grid.set(x, y, Cell(x, y));

  if (randomStuff >= cells.length) {
    if (randomStuff < cells.length * 2) {
      grid.set(x, y, Cell(x, y)..id = "field");
      grid.setChunk(x, y, "field");
    }
  } else {
    grid.set(
      x,
      y,
      Cell(x, y)
        ..id = cells[randomStuff]
        ..rot = randomRot
        ..lastvars.lastRot = randomRot,
    );
    grid.setChunk(x, y, cells[randomStuff]);
  }

  if (grid.at(nx, ny).id != "empty") {
    grid.addBroken(grid.at(nx, ny), nx, ny, "silent");
  }

  grid.set(nx, ny, cell.copy);
  grid.setChunk(nx, ny, cell.id);
}

class RaycastInfo {
  late Cell hitCell;
  bool successful;

  RaycastInfo.successful(Cell cell) : successful = true {
    hitCell = cell.copy;
  }

  RaycastInfo.broken() : successful = false;
}

RaycastInfo raycast(int cx, int cy, int dx, int dy) {
  var x = cx;
  var y = cy;

  while (true) {
    x += dx;
    y += dy;
    if (!grid.inside(x, y)) return RaycastInfo.broken();

    final cell = grid.at(x, y);

    if (cell.id != "empty") {
      return RaycastInfo.successful(cell);
    }
  }
}

int clamp(int n, int minn, int maxn) => max(minn, min(n, maxn));

void physicsCell(int x, int y, List<String> attracted, List<String> repelled) {
  // Forces
  var vx = 0;
  var vy = 0;

  // Compute forces
  final offs = [1, 0, -1, 0, 0, 1, 0, -1, 1, 1, 1, -1, -1, 1, -1, -1];

  for (var i = 0; i < offs.length; i += 2) {
    final ox = offs[i];
    final oy = offs[i + 1];

    final cell = raycast(x, y, ox, oy);

    if (cell.successful) {
      if (attracted.contains(cell.hitCell.id)) {
        vx += ox;
        vy += oy;
      }
      if (repelled.contains(cell.hitCell.id)) {
        vx -= ox;
        vy -= oy;
      }
    }
  }

  // Fix forces
  vx = clamp(vx, -1, 1);
  vy = clamp(vy, -1, 1);

  // Move
  if (vx != 0 || vy != 0) {
    if (grid.inside(x + vx, y + vy) == false) return;

    if (grid.at(x + vx, y + vy).id == "empty") {
      moveCell(x, y, x + vx, y + vy);
    }
  }
}

void quantums() {
  if (grid.movable) {
    for (var rot in rotOrder) {
      grid.loopChunks(
        "unstable_mover",
        fromRot(rot),
        (cell, x, y) {
          if (cell.rot == rot) unstableMove(x, y, cell.rot);
        },
        filter: (cell, x, y) =>
            cell.id == "unstable_mover" &&
            cell.rot == rot &&
            cell.updated == false,
      );
      grid.updateCell(
        (cell, x, y) {
          final bx = frontX(x, (rot + 2) % 4);
          final by = frontY(y, (rot + 2) % 4);

          if (grid.inside(bx, by)) {
            final b = grid.at(bx, by);
            unstableGen(x, y, rot, b.copy);
          }
        },
        rot,
        "unstable_gen",
      );
    }
  }

  grid.loopChunks("field", GridAlignment.TOPLEFT, doField);

  // My brain hurts
  grid.updateCell(
    (cell, x, y) {
      physicsCell(x, y, ["proton"], ["electron", "neutron"]);
    },
    null,
    "electron",
  );
  grid.updateCell(
    (cell, x, y) {
      physicsCell(x, y, ["neutron"], []);
    },
    null,
    "proton",
  );
  grid.updateCell(
    (cell, x, y) {
      physicsCell(x, y, ["proton"], []);
    },
    null,
    "neutron",
  );
}
