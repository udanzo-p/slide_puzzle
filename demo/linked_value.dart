abstract class LinkedValue<T> {
  int get length;

  factory LinkedValue() => _EmptyLinkedThing();

  LinkedValue<T> followedBy(T value);

  List<T> toList();
}

class _EmptyLinkedThing<T> implements LinkedValue<T> {
  @override
  int get length => 0;

  @override
  LinkedValue<T> followedBy(T value) => _LinkedThing(null, value);

  @override
  List<T> toList() => List(0);
}

class _LinkedThing<T> implements LinkedValue<T> {
  final _LinkedThing<T> _previous;
  final T _value;

  @override
  final int length;

  _LinkedThing(this._previous, this._value)
      : length = 1 + (_previous?.length ?? 0);

  @override
  LinkedValue<T> followedBy(T value) => _LinkedThing(this, value);

  @override
  List<T> toList() {
    final list = <T>[];
    for (var previous = this; previous != null; previous = previous._previous) {
      list.add(previous._value);
    }

    return list.reversed.toList(growable: false);
  }

  @override
  String toString() => '${super.toString()} ($length)';
}
