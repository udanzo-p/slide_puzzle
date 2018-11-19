// ignore_for_file: argument_type_not_assignable, annotate_overrides, omit_local_variable_types, prefer_final_locals

import 'dart:collection' show SetBase, MapBase;

int _defaultHashCode(a) => a.hashCode;

bool _defaultEquals(a, b) => a == b;

typedef bool _Equality<K>(K a, K b);
typedef int _Hasher<K>(K object);
typedef bool _Predicate<T>(T value);

class _TypeTest<T> {
  bool test(v) => v is T;
}

abstract class HashMap<K, V> implements Map<K, V> {
  factory HashMap(
      {bool equals(K key1, K key2),
      int hashCode(K key),
      bool isValidKey(potentialKey)}) {
    if (isValidKey == null) {
      if (hashCode == null) {
        if (equals == null) {
          return _HashMap<K, V>();
        }
        hashCode = _defaultHashCode;
      } else {
        if (identical(identityHashCode, hashCode) &&
            identical(identical, equals)) {
          return _IdentityHashMap<K, V>();
        }
        equals ??= _defaultEquals;
      }
    } else {
      hashCode ??= _defaultHashCode;
      equals ??= _defaultEquals;
    }
    return _CustomHashMap<K, V>(equals, hashCode, isValidKey);
  }

  factory HashMap.identity() => _IdentityHashMap<K, V>();

  Set<K> _newKeySet();
}

const int _modificationCountMask = 0x3fffffff;

class _HashMap<K, V> extends MapBase<K, V> implements HashMap<K, V> {
  static const int _initialCapacity = 8;

  int _elementCount = 0;
  List<_HashMapEntry<K, V>> _buckets =
      List<_HashMapEntry<K, V>>(_initialCapacity);
  int _modificationCount = 0;

  int get length => _elementCount;

  bool get isEmpty => _elementCount == 0;

  bool get isNotEmpty => _elementCount != 0;

  Iterable<K> get keys => _HashMapKeyIterable<K, V>(this);

  Iterable<V> get values => _HashMapValueIterable<K, V>(this);

  bool containsKey(Object key) {
    final hashCode = key.hashCode;
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) return true;
      entry = entry.next;
    }
    return false;
  }

  bool containsValue(Object value) {
    final buckets = _buckets;
    final length = buckets.length;
    for (int i = 0; i < length; i++) {
      var entry = buckets[i];
      while (entry != null) {
        if (entry.value == value) return true;
        entry = entry.next;
      }
    }
    return false;
  }

  V operator [](Object key) {
    final hashCode = key.hashCode;
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) {
        return entry.value;
      }
      entry = entry.next;
    }
    return null;
  }

  void operator []=(K key, V value) {
    final hashCode = key.hashCode;
    final buckets = _buckets;
    final length = buckets.length;
    final index = hashCode & (length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) {
        entry.value = value;
        return;
      }
      entry = entry.next;
    }
    _addEntry(buckets, index, length, key, value, hashCode);
  }

  V putIfAbsent(K key, V ifAbsent()) {
    final hashCode = key.hashCode;
    final buckets = _buckets;
    final length = buckets.length;
    final index = hashCode & (length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && entry.key == key) {
        return entry.value;
      }
      entry = entry.next;
    }
    final stamp = _modificationCount;
    final V value = ifAbsent();
    if (stamp == _modificationCount) {
      _addEntry(buckets, index, length, key, value, hashCode);
    } else {
      this[key] = value;
    }
    return value;
  }

  void addAll(Map<K, V> other) {
    other.forEach((K key, V value) {
      this[key] = value;
    });
  }

  void forEach(void action(K key, V value)) {
    final stamp = _modificationCount;
    final buckets = _buckets;
    final length = buckets.length;
    for (int i = 0; i < length; i++) {
      var entry = buckets[i];
      while (entry != null) {
        action(entry.key, entry.value);
        if (stamp != _modificationCount) {
          throw ConcurrentModificationError(this);
        }
        entry = entry.next;
      }
    }
  }

  V remove(Object key) {
    final hashCode = key.hashCode;
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    _HashMapEntry<K, V> previous;
    while (entry != null) {
      final next = entry.next;
      if (hashCode == entry.hashCode && entry.key == key) {
        _removeEntry(entry, previous, index);
        _elementCount--;
        _modificationCount = (_modificationCount + 1) & _modificationCountMask;
        return entry.value;
      }
      previous = entry;
      entry = next;
    }
    return null;
  }

  void clear() {
    _buckets = List(_initialCapacity);
    if (_elementCount > 0) {
      _elementCount = 0;
      _modificationCount = (_modificationCount + 1) & _modificationCountMask;
    }
  }

  void _removeEntry(_HashMapEntry<K, V> entry,
      _HashMapEntry<K, V> previousInBucket, int bucketIndex) {
    if (previousInBucket == null) {
      _buckets[bucketIndex] = entry.next;
    } else {
      previousInBucket.next = entry.next;
    }
  }

  void _addEntry(List<_HashMapEntry<K, V>> buckets, int index, int length,
      K key, V value, int hashCode) {
    final entry = _HashMapEntry<K, V>(key, value, hashCode, buckets[index]);
    buckets[index] = entry;
    final newElements = _elementCount + 1;
    _elementCount = newElements;
    // If we end up with more than 75% non-empty entries, we
    // resize the backing store.
    if ((newElements << 2) > ((length << 1) + length)) _resize();
    _modificationCount = (_modificationCount + 1) & _modificationCountMask;
  }

  void _resize() {
    final oldBuckets = _buckets;
    final oldLength = oldBuckets.length;
    final newLength = oldLength << 1;
    print(
        '$length - from ${oldLength.toStringAsExponential(2)} to ${newLength.toStringAsExponential(2)}');
    final newBuckets = List<_HashMapEntry<K, V>>(newLength);
    for (int i = 0; i < oldLength; i++) {
      var entry = oldBuckets[i];
      while (entry != null) {
        final next = entry.next;
        final hashCode = entry.hashCode;
        final index = hashCode & (newLength - 1);
        entry.next = newBuckets[index];
        newBuckets[index] = entry;
        entry = next;
      }
    }
    _buckets = newBuckets;
  }

  Set<K> _newKeySet() => _HashSet<K>();
}

class _CustomHashMap<K, V> extends _HashMap<K, V> {
  final _Equality<K> _equals;
  final _Hasher<K> _hashCode;
  final _Predicate _validKey;

  _CustomHashMap(this._equals, this._hashCode, bool Function(dynamic) validKey)
      : _validKey = (validKey != null) ? validKey : _TypeTest<K>().test;

  bool containsKey(Object key) {
    if (!_validKey(key)) return false;
    final hashCode = _hashCode(key);
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) return true;
      entry = entry.next;
    }
    return false;
  }

  V operator [](Object key) {
    if (!_validKey(key)) return null;
    final hashCode = _hashCode(key);
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    return null;
  }

  void operator []=(K key, V value) {
    final hashCode = _hashCode(key);
    final buckets = _buckets;
    final length = buckets.length;
    final index = hashCode & (length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        entry.value = value;
        return;
      }
      entry = entry.next;
    }
    _addEntry(buckets, index, length, key, value, hashCode);
  }

  V putIfAbsent(K key, V ifAbsent()) {
    final hashCode = _hashCode(key);
    final buckets = _buckets;
    final length = buckets.length;
    final index = hashCode & (length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    int stamp = _modificationCount;
    V value = ifAbsent();
    if (stamp == _modificationCount) {
      _addEntry(buckets, index, length, key, value, hashCode);
    } else {
      this[key] = value;
    }
    return value;
  }

  V remove(Object key) {
    if (!_validKey(key)) return null;
    final hashCode = _hashCode(key);
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    _HashMapEntry<K, V> previous;
    while (entry != null) {
      final next = entry.next;
      if (hashCode == entry.hashCode && _equals(entry.key, key)) {
        _removeEntry(entry, previous, index);
        _elementCount--;
        _modificationCount = (_modificationCount + 1) & _modificationCountMask;
        return entry.value;
      }
      previous = entry;
      entry = next;
    }
    return null;
  }

  Set<K> _newKeySet() => _CustomHashSet<K>(_equals, _hashCode, _validKey);
}

class _IdentityHashMap<K, V> extends _HashMap<K, V> {
  bool containsKey(Object key) {
    final hashCode = identityHashCode(key);
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) return true;
      entry = entry.next;
    }
    return false;
  }

  V operator [](Object key) {
    final hashCode = identityHashCode(key);
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    return null;
  }

  void operator []=(K key, V value) {
    final hashCode = identityHashCode(key);
    final buckets = _buckets;
    final length = buckets.length;
    final index = hashCode & (length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        entry.value = value;
        return;
      }
      entry = entry.next;
    }
    _addEntry(buckets, index, length, key, value, hashCode);
  }

  V putIfAbsent(K key, V ifAbsent()) {
    final hashCode = identityHashCode(key);
    final buckets = _buckets;
    final length = buckets.length;
    final index = hashCode & (length - 1);
    var entry = buckets[index];
    while (entry != null) {
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        return entry.value;
      }
      entry = entry.next;
    }
    final stamp = _modificationCount;
    V value = ifAbsent();
    if (stamp == _modificationCount) {
      _addEntry(buckets, index, length, key, value, hashCode);
    } else {
      this[key] = value;
    }
    return value;
  }

  V remove(Object key) {
    final hashCode = identityHashCode(key);
    final buckets = _buckets;
    final index = hashCode & (buckets.length - 1);
    var entry = buckets[index];
    _HashMapEntry<K, V> previous;
    while (entry != null) {
      final next = entry.next;
      if (hashCode == entry.hashCode && identical(entry.key, key)) {
        _removeEntry(entry, previous, index);
        _elementCount--;
        _modificationCount = (_modificationCount + 1) & _modificationCountMask;
        return entry.value;
      }
      previous = entry;
      entry = next;
    }
    return null;
  }

  Set<K> _newKeySet() => _IdentityHashSet<K>();
}

class _HashMapEntry<K, V> {
  final K key;
  V value;
  final int hashCode;
  _HashMapEntry<K, V> next;

  _HashMapEntry(this.key, this.value, this.hashCode, this.next);
}

abstract class EfficientLengthIterable<T> extends Iterable<T> {
  const EfficientLengthIterable();

  /// Returns the number of elements in the iterable.
  ///
  /// This is an efficient operation that doesn't require iterating through
  /// the elements.
  int get length;
}

abstract class _HashMapIterable<K, V, E> extends EfficientLengthIterable<E> {
  final _HashMap<K, V> _map;

  _HashMapIterable(this._map);

  int get length => _map.length;

  bool get isEmpty => _map.isEmpty;

  bool get isNotEmpty => _map.isNotEmpty;
}

class _HashMapKeyIterable<K, V> extends _HashMapIterable<K, V, K> {
  _HashMapKeyIterable(_HashMap<K, V> map) : super(map);

  Iterator<K> get iterator => _HashMapKeyIterator<K, V>(_map);

  bool contains(Object key) => _map.containsKey(key);

  void forEach(void action(K key)) {
    _map.forEach((K key, _) {
      action(key);
    });
  }

  Set<K> toSet() => _map._newKeySet()..addAll(this);
}

class _HashMapValueIterable<K, V> extends _HashMapIterable<K, V, V> {
  _HashMapValueIterable(_HashMap<K, V> map) : super(map);

  Iterator<V> get iterator => _HashMapValueIterator<K, V>(_map);

  bool contains(Object value) => _map.containsValue(value);

  void forEach(void action(V value)) {
    _map.forEach((_, V value) {
      action(value);
    });
  }
}

abstract class _HashMapIterator<K, V, E> implements Iterator<E> {
  final _HashMap<K, V> _map;
  final int _stamp;

  int _index = 0;
  _HashMapEntry<K, V> _entry;

  _HashMapIterator(this._map) : _stamp = _map._modificationCount;

  bool moveNext() {
    if (_stamp != _map._modificationCount) {
      throw ConcurrentModificationError(_map);
    }
    var entry = _entry;
    if (entry != null) {
      final next = entry.next;
      if (next != null) {
        _entry = next;
        return true;
      }
      _entry = null;
    }
    final buckets = _map._buckets;
    final length = buckets.length;
    for (int i = _index; i < length; i++) {
      entry = buckets[i];
      if (entry != null) {
        _index = i + 1;
        _entry = entry;
        return true;
      }
    }
    _index = length;
    return false;
  }
}

class _HashMapKeyIterator<K, V> extends _HashMapIterator<K, V, K> {
  _HashMapKeyIterator(_HashMap<K, V> map) : super(map);

  K get current => _entry?.key;
}

class _HashMapValueIterator<K, V> extends _HashMapIterator<K, V, V> {
  _HashMapValueIterator(_HashMap<K, V> map) : super(map);

  V get current => _entry?.value;
}

abstract class HashSet<E> implements Set<E> {
  factory HashSet(
      {bool equals(E e1, E e2),
      int hashCode(E e),
      bool isValidKey(potentialKey)}) {
    if (isValidKey == null) {
      if (hashCode == null) {
        if (equals == null) {
          return _HashSet<E>();
        }
        hashCode = _defaultHashCode;
      } else {
        if (identical(identityHashCode, hashCode) &&
            identical(identical, equals)) {
          return _IdentityHashSet<E>();
        }
        equals ??= _defaultEquals;
      }
    } else {
      hashCode ??= _defaultHashCode;
      equals ??= _defaultEquals;
    }
    return _CustomHashSet<E>(equals, hashCode, isValidKey);
  }

  factory HashSet.identity() => _IdentityHashSet<E>();

  double fillRate();
}

abstract class IterableElementError {
  /// Error thrown thrown by, e.g., [Iterable.first] when there is no result.
  static StateError noElement() => StateError('No element');

  /// Error thrown by, e.g., [Iterable.single] if there are too many results.
  static StateError tooMany() => StateError('Too many elements');

  /// Error thrown by, e.g., [List.setRange] if there are too few elements.
  static StateError tooFew() => StateError('Too few elements');
}

class _HashSet<E> extends _HashSetBase<E> implements HashSet<E> {
  static const int _initialCapacity = 8;

  List<_HashSetEntry<E>> _buckets = List<_HashSetEntry<E>>(_initialCapacity);
  int _elementCount = 0;
  int _modificationCount = 0;

  bool _equals(e1, e2) => e1 == e2;

  int _hashCode(e) => e.hashCode;

  // Iterable.

  Iterator<E> get iterator => _HashSetIterator<E>(this);

  int get length => _elementCount;

  bool get isEmpty => _elementCount == 0;

  bool get isNotEmpty => _elementCount != 0;

  bool contains(Object object) {
    int index = _hashCode(object) & (_buckets.length - 1);
    _HashSetEntry<E> entry = _buckets[index];
    while (entry != null) {
      if (_equals(entry.key, object)) return true;
      entry = entry.next;
    }
    return false;
  }

  E lookup(Object object) {
    int index = _hashCode(object) & (_buckets.length - 1);
    _HashSetEntry<E> entry = _buckets[index];
    while (entry != null) {
      var key = entry.key;
      if (_equals(key, object)) return key;
      entry = entry.next;
    }
    return null;
  }

  E get first {
    for (int i = 0; i < _buckets.length; i++) {
      var entry = _buckets[i];
      if (entry != null) {
        return entry.key;
      }
    }
    throw IterableElementError.noElement();
  }

  E get last {
    for (int i = _buckets.length - 1; i >= 0; i--) {
      var entry = _buckets[i];
      if (entry != null) {
        while (entry.next != null) {
          entry = entry.next;
        }
        return entry.key;
      }
    }
    throw IterableElementError.noElement();
  }

  // Set.

  bool add(E element) {
    final hashCode = _hashCode(element);
    final index = hashCode & (_buckets.length - 1);
    _HashSetEntry<E> entry = _buckets[index];
    while (entry != null) {
      if (_equals(entry.key, element)) return false;
      entry = entry.next;
    }
    _addEntry(element, hashCode, index);
    return true;
  }

  void addAll(Iterable<E> objects) {
    for (E object in objects) {
      add(object);
    }
  }

  bool _remove(Object object, int hashCode) {
    final index = hashCode & (_buckets.length - 1);
    _HashSetEntry<E> entry = _buckets[index];
    _HashSetEntry<E> previous;
    while (entry != null) {
      if (_equals(entry.key, object)) {
        _HashSetEntry<E> next = entry.remove();
        if (previous == null) {
          _buckets[index] = next;
        } else {
          previous.next = next;
        }
        _elementCount--;
        _modificationCount = (_modificationCount + 1) & _modificationCountMask;
        return true;
      }
      previous = entry;
      entry = entry.next;
    }
    return false;
  }

  bool remove(Object object) => _remove(object, _hashCode(object));

  void removeAll(Iterable<Object> objectsToRemove) {
    for (Object object in objectsToRemove) {
      _remove(object, _hashCode(object));
    }
  }

  void _filterWhere(bool test(E element), bool removeMatching) {
    int length = _buckets.length;
    for (int index = 0; index < length; index++) {
      _HashSetEntry<E> entry = _buckets[index];
      _HashSetEntry<E> previous;
      while (entry != null) {
        int modificationCount = _modificationCount;
        bool testResult = test(entry.key);
        if (modificationCount != _modificationCount) {
          throw ConcurrentModificationError(this);
        }
        if (testResult == removeMatching) {
          _HashSetEntry<E> next = entry.remove();
          if (previous == null) {
            _buckets[index] = next;
          } else {
            previous.next = next;
          }
          _elementCount--;
          _modificationCount =
              (_modificationCount + 1) & _modificationCountMask;
          entry = next;
        } else {
          previous = entry;
          entry = entry.next;
        }
      }
    }
  }

  void removeWhere(bool test(E element)) {
    _filterWhere(test, true);
  }

  void retainWhere(bool test(E element)) {
    _filterWhere(test, false);
  }

  void clear() {
    _buckets = List(_initialCapacity);
    if (_elementCount > 0) {
      _elementCount = 0;
      _modificationCount = (_modificationCount + 1) & _modificationCountMask;
    }
  }

  void _addEntry(E key, int hashCode, int index) {
    _buckets[index] = _HashSetEntry<E>(key, hashCode, _buckets[index]);
    int newElements = _elementCount + 1;
    _elementCount = newElements;
    int length = _buckets.length;
    // If we end up with more than 75% non-empty entries, we
    // resize the backing store.
    if ((newElements << 2) > ((length << 1) + length)) _resize();
    _modificationCount = (_modificationCount + 1) & _modificationCountMask;
  }

  void _resize() {
    int oldLength = _buckets.length;
    int newLength = oldLength << 1;
    print('$length - fill rate ${fillRate()} from $oldLength to $newLength');
    List oldBuckets = _buckets;
    var newBuckets = List<_HashSetEntry<E>>(newLength);
    for (int i = 0; i < oldLength; i++) {
      _HashSetEntry<E> entry = oldBuckets[i];
      while (entry != null) {
        _HashSetEntry<E> next = entry.next;
        int newIndex = entry.hashCode & (newLength - 1);
        entry.next = newBuckets[newIndex];
        newBuckets[newIndex] = entry;
        entry = next;
      }
    }
    _buckets = newBuckets;
  }

  Set<E> _newSet() => _HashSet<E>();

  Set<R> _newSimilarSet<R>() => _HashSet<R>();

  double fillRate() {
    var count = 0;
    for (var i = 0; i < _buckets.length; i++) {
      if (_buckets[i] == null) {
        count++;
      }
    }

    return count / _buckets.length;
  }
}

class _IdentityHashSet<E> extends _HashSet<E> {
  int _hashCode(e) => identityHashCode(e);

  bool _equals(e1, e2) => identical(e1, e2);

  Set<E> _newSet() => _IdentityHashSet<E>();

  Set<R> _newSimilarSet<R>() => _IdentityHashSet<R>();
}

class _CustomHashSet<E> extends _HashSet<E> {
  final _Equality<E> _equality;
  final _Hasher<E> _hasher;
  final _Predicate _validKey;

  _CustomHashSet(this._equality, this._hasher, bool validKey(Object o))
      : _validKey = (validKey != null) ? validKey : _TypeTest<E>().test;

  bool remove(Object element) {
    if (!_validKey(element)) return false;
    return super.remove(element);
  }

  bool contains(Object element) {
    if (!_validKey(element)) return false;
    return super.contains(element);
  }

  E lookup(Object element) {
    if (!_validKey(element)) return null;
    return super.lookup(element);
  }

  bool containsAll(Iterable<Object> elements) {
    for (Object element in elements) {
      if (!_validKey(element) || !contains(element)) return false;
    }
    return true;
  }

  void removeAll(Iterable<Object> elements) {
    for (var element in elements) {
      if (_validKey(element)) {
        super._remove(element, _hasher(element));
      }
    }
  }

  bool _equals(e1, e2) => _equality(e1, e2);

  int _hashCode(e) => _hasher(e);

  Set<E> _newSet() => _CustomHashSet<E>(_equality, _hasher, _validKey);

  Set<R> _newSimilarSet<R>() => _HashSet<R>();
}

class _HashSetEntry<E> {
  final E key;
  final int hashCode;
  _HashSetEntry<E> next;

  _HashSetEntry(this.key, this.hashCode, this.next);

  _HashSetEntry<E> remove() {
    final result = next;
    next = null;
    return result;
  }
}

class _HashSetIterator<E> implements Iterator<E> {
  final _HashSet<E> _set;
  final int _modificationCount;
  int _index = 0;
  _HashSetEntry<E> _next;
  E _current;

  _HashSetIterator(this._set) : _modificationCount = _set._modificationCount;

  bool moveNext() {
    if (_modificationCount != _set._modificationCount) {
      throw ConcurrentModificationError(_set);
    }
    if (_next != null) {
      _current = _next.key;
      _next = _next.next;
      return true;
    }
    List<_HashSetEntry<E>> buckets = _set._buckets;
    while (_index < buckets.length) {
      _next = buckets[_index];
      _index = _index + 1;
      if (_next != null) {
        _current = _next.key;
        _next = _next.next;
        return true;
      }
    }
    _current = null;
    return false;
  }

  E get current => _current;
}

abstract class _HashSetBase<E> extends SetBase<E> {
  // The following two methods override the ones in SetBase.
  // It's possible to be more efficient if we have a way to create an empty
  // set of the correct type.

  Set<E> _newSet();

  Set<R> _newSimilarSet<R>();

  Set<R> cast<R>() => Set.castFrom<E, R>(this, newSet: _newSimilarSet);

  Set<E> difference(Set<Object> other) {
    Set<E> result = _newSet();
    for (var element in this) {
      if (!other.contains(element)) result.add(element);
    }
    return result;
  }

  Set<E> intersection(Set<Object> other) {
    Set<E> result = _newSet();
    for (var element in this) {
      if (other.contains(element)) result.add(element);
    }
    return result;
  }

  // Subclasses can optimize this further.
  Set<E> toSet() => _newSet()..addAll(this);
}
