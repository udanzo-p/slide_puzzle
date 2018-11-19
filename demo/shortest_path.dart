// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart' show HeapPriorityQueue;

import 'hash_copy.dart' show HashMap;
import 'linked_value.dart';

Iterable<List<T>> shortestPaths<T>(
  T start,
  T target,
  Iterable<T> Function(T) edges, {
  bool equals(T key1, T key2),
  int hashCode(T key),
  int Function(T, T) compare,
}) sync* {
  assert(start != null, '`start` cannot be null');
  assert(edges != null, '`edges` cannot be null');

  final distances =
      HashMap<T, LinkedValue<T>>(equals: equals, hashCode: hashCode);

  equals ??= _defaultEquals;
  if (equals(start, target)) {
    yield List(0);
    return;
  }

  distances[start] = LinkedValue();

  final toVisit = HeapPriorityQueue(compare)..add(start);

  List<T> bestOption;
  Duration bestOptionTime;

  var loopCount = 0;

  final watch = Stopwatch()..start();
  final second2 = const Duration(seconds: 2);
  var lastLoopTime = second2;
  var maxDistancesLength = 0;
  var maxToVisitLength = 0;

  void loopy() {
    final map = <String, dynamic>{
      'loopCount': loopCount,
      'elapsed': watch.elapsed,
      'loops per ms': loopCount ~/ watch.elapsedMilliseconds,
      'graphSize': distances.length.toStringAsExponential(3),
      '% max g': _pct(distances.length, maxDistancesLength),
      'toVisit': toVisit.length.toStringAsExponential(3),
      '% max v': _pct(toVisit.length, maxToVisitLength)
    };

    if (distances.length > maxDistancesLength) {
      maxDistancesLength = distances.length;
    }

    if (toVisit.length > maxToVisitLength) {
      maxToVisitLength = toVisit.length;
    }

    if (bestOption != null) {
      map['bestOption'] = bestOption.length;
      map['timeToBest'] = bestOptionTime;
    }

    print(map);
  }

  int lastDistancesCleanupLength;

  void doCleanup() {
    if (lastDistancesCleanupLength == null ||
        lastDistancesCleanupLength <= distances.length) {
      lastDistancesCleanupLength = distances.length;
      distances.removeWhere((k, v) {
        return v.length >= bestOption.length;
      });
    }
  }

  while (toVisit.isNotEmpty) {
    loopCount++;

    if (watch.elapsed > lastLoopTime) {
      lastLoopTime = watch.elapsed + second2;
      loopy();
    }

    final current = toVisit.removeFirst();
    final currentPath = distances[current];

    if (currentPath == null) {
      continue;
    }
    final currentPathLength = currentPath.length;

    if (bestOption != null && (currentPathLength + 1) >= bestOption.length) {
      // Skip any existing `toVisit` items that have no chance of being
      // better than bestOption (if it exists)
      continue;
    }

    for (var edge in edges(current)) {
      assert(edge != null, '`edges` cannot return null values.');

      var pathToEdge = distances[edge];

      if (pathToEdge == null || pathToEdge.length > (currentPathLength + 1)) {
        pathToEdge = currentPath.followedBy(edge);

        if (equals(edge, target)) {
          assert(bestOption == null || bestOption.length > pathToEdge.length);
          bestOption = pathToEdge.toList();
          bestOptionTime = watch.elapsed;

          yield bestOption;

          doCleanup();
        }

        distances[edge] = pathToEdge;
        if (bestOption == null || bestOption.length > pathToEdge.length) {
          // Only add a node to visit if it might be a better path to the
          // target node
          toVisit.add(edge);
        }
      }
    }
  }

  loopy();
}

String _pct(int a, int b) => (100 * a / b).toStringAsFixed(1);

bool _defaultEquals(a, b) => a == b;
