part of layout;

final puzzles = [
  "easy/level1.txt",
  "easy/level2.txt",
  "easy/level3.txt",
  "easy/level4.txt",
  "easy/level5.txt",
  "medium/level1.txt",
  "medium/level2.txt",
  "medium/level3.txt",
  "medium/level4.txt",
  "medium/level5.txt",
  "medium/level6.txt",
  "hard/level1.txt",
  "hard/level2.txt",
  "hard/level3.txt",
];

int? puzzleIndex;

Future<String> loadJsonData(String path) async {
  var jsonText = await rootBundle.loadString(path);
  return jsonText;
}

class Puzzles extends StatefulWidget {
  const Puzzles({Key? key}) : super(key: key);

  @override
  _PuzzlesState createState() => _PuzzlesState();
}

Future<void> loadPuzzle(int index) async {
  grid = P1.decode(await loadJsonData('assets/puzzles/${puzzles[index]}'));
  discord.updatePresence(
    DiscordPresence(
      details: 'Playing a ${puzzles[index].split('/').first} puzzle',
      largeImageKey: 'tpc_logo',
      smallImageKey: 'tpc_logo',
      startTimeStamp: DateTime.now().millisecondsSinceEpoch,
    ),
  );
  puzzleIndex = index;
}

class _PuzzlesState extends State<Puzzles> {
  Icon tierToIcon(String tier, [double? size]) {
    if (tier == "hard") {
      return Icon(
        Icons.cancel_outlined,
        color: Colors.red,
        size: size,
      );
    }
    if (tier == "medium") {
      return Icon(
        Icons.hourglass_bottom,
        color: Colors.orange[400],
        size: size,
      );
    }
    return Icon(
      Icons.help_outline,
      color: Colors.blue,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Puzzles", style: fontSize(10.sp)),
      ),
      body: ListView.builder(
        itemCount: puzzles.length,
        itemBuilder: (ctx, i) {
          return FutureBuilder<String>(
            future: loadJsonData('assets/puzzles/${puzzles[i]}'),
            builder: (ctx, snap) {
              if (snap.hasData) {
                final title = snap.data!.split(';')[5];
                final desc = snap.data!.split(';')[6];
                return ListTile(
                  title: Text(title),
                  subtitle: Text(desc),
                  leading: tierToIcon(puzzles[i].split('/').first),
                  onTap: () {
                    loadPuzzle(i).then(
                      (_) => Navigator.of(context).pushNamed('/game-loaded'),
                    );
                  },
                );
              } else {
                return SizedBox(
                  width: 5.w,
                  height: 5.w,
                  child: CircularProgressIndicator.adaptive(),
                );
              }
            },
          );
        },
      ),
    );
  }
}
