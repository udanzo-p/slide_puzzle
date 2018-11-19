import 'package:slide_puzzle/src/core/puzzle.dart';

import 'hash_copy.dart';

void main() {
  final mySet = HashSet<Puzzle>();

  print(mySet.runtimeType);

  var count = 0;
  void log() {
    print([count, mySet.length, mySet.fillRate()]);
  }

  final watch = Stopwatch()..start();
  final candidates = List<Puzzle>.generate(1024 * 1024, (i) => Puzzle(4, 4));

  print('candidates done! - ${watch.elapsed}');

  watch.reset();
  count = 0;

  for (;;) {
    for (var p in candidates) {
      count++;
      mySet.add(p);
    }
    print('adds per ms: ${count / watch.elapsedMilliseconds}');
    log();
  }

  // ~2400 adds per ms
  // ~2500 adds per ms w/ abstraction – cool?
  // ~2250 as is...and tweaked :-/
  // ~3150 adds per ps @ 32bits – sweet!
}
