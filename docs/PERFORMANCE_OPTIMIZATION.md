# Performance Optimization Guide

## 1. Profile dengan Flutter DevTools

### Setup DevTools
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

### Profile aplikasi
```bash
flutter run --profile
# Buka DevTools di browser: http://localhost:9100
```

### Metrics to Monitor
- Frame rate (target: 60 FPS)
- Memory usage
- CPU usage
- GPU rendering time

---

## 2. Rendering Performance Optimization

### Gunakan const widgets
```dart
// ❌ AVOID
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('Hello'); // Rebuild setiap kali
  }
}

// ✅ GOOD
class MyWidget extends StatelessWidget {
  const MyWidget(); // Const constructor

  @override
  Widget build(BuildContext context) {
    return const Text('Hello'); // Const widget
  }
}
```

### Optimize List Building
```dart
// ❌ AVOID - Rebuilds all items
ListView(
  children: [
    for (var item in items)
      ExpensiveWidget(item),
  ],
)

// ✅ GOOD - Only visible items rendered
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ExpensiveWidget(items[index]),
)
```

### Use RepaintBoundary for Complex Widgets
```dart
RepaintBoundary(
  child: ComplexAnimatedWidget(),
)
```

### Implement shouldRebuild Efficiently
```dart
class MyProvider extends ChangeNotifier {
  int _counter = 0;

  int get counter => _counter;

  void increment() {
    _counter++;
    notifyListeners(); // Only notify when necessary
  }
}
```

---

## 3. Image Optimization

### Use cached_network_image
```dart
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  cacheManager: CacheManager(
    Config(
      'customCacheKey',
      stalePeriod: Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  ),
)
```

### Optimize Image Dimensions
```dart
// ❌ AVOID - Full resolution
Image.network('https://example.com/large-image.jpg')

// ✅ GOOD - Request specific size
Image.network(
  'https://example.com/image.jpg?w=300&h=300',
  width: 300,
  height: 300,
)
```

### Use Image Compression
```dart
Future<File> compressImage(File imageFile) async {
  final result = await FlutterImageCompress.compressAndGetFile(
    imageFile.absolute.path,
    imageFile.absolute.path.replaceFirst('.jpg', '_compressed.jpg'),
    quality: 70,
  );
  return result!;
}
```

---

## 4. Network Optimization

### Implement Request Caching
```dart
class CachedApiClient {
  final Map<String, CachedResponse> _cache = {};

  Future<T> get<T>(String url) async {
    // Check cache
    if (_cache.containsKey(url)) {
      final cached = _cache[url]!;
      if (!cached.isExpired) {
        return cached.data;
      }
    }

    // Fetch from API
    final response = await apiClient.get<T>(url);

    // Cache response
    _cache[url] = CachedResponse(
      data: response.data,
      timestamp: DateTime.now(),
      duration: Duration(minutes: 5),
    );

    return response.data;
  }
}

class CachedResponse {
  final dynamic data;
  final DateTime timestamp;
  final Duration duration;

  CachedResponse({
    required this.data,
    required this.timestamp,
    required this.duration,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > duration;
}
```

### Connection Pooling
```dart
final httpClient = http.Client();

// Reuse same client instead of creating new ones
Future<Response> makeRequest(String url) {
  return httpClient.get(Uri.parse(url));
}
```

---

## 5. Memory Optimization

### Dispose Resources Properly
```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  late AnimationController _controller;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _subscription = eventStream.listen((_) {});
  }

  @override
  void dispose() {
    _controller.dispose(); // ✅ Dispose animation controller
    _subscription.cancel(); // ✅ Cancel stream subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
```

### Avoid Memory Leaks
```dart
// ❌ AVOID - Memory leak
class Provider extends ChangeNotifier {
  final controller = TextEditingController();

  @override
  void dispose() {
    // Forgot to dispose controller
    super.dispose();
  }
}

// ✅ GOOD
class Provider extends ChangeNotifier {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose(); // Dispose controller
    super.dispose();
  }
}
```

---

## 6. Build Size Optimization

### Enable Shrinking (Android)
```gradle
// android/app/build.gradle
android {
  buildTypes {
    release {
      shrinkResources true
      minifyEnabled true
      proguardFiles getDefaultProguardFile('proguard-android-optimize.txt')
    }
  }
}
```

### Remove Unused Dependencies
```bash
flutter pub deps --dev
flutter pub pub get
```

### Check APK/IPA Size
```bash
flutter build apk --analyze-size
flutter build ios --analyze-size
```

---

## 7. Database Optimization

### Use Indexes
```dart
// Add indexes to frequently queried columns
await db.execute('''
  CREATE INDEX idx_user_email ON users(email);
  CREATE INDEX idx_transaction_date ON transactions(created_at);
''');
```

### Batch Operations
```dart
// ❌ AVOID - Multiple queries
for (var item in items) {
  await db.insert('items', item.toMap());
}

// ✅ GOOD - Single batch
await db.transaction((txn) async {
  for (var item in items) {
    await txn.insert('items', item.toMap());
  }
});
```

---

## 8. Animation Performance

### Use Performance-Optimized Animations
```dart
// ✅ GOOD - Efficient animation
class PerformantAnimation extends StatefulWidget {
  @override
  State<PerformantAnimation> createState() => _PerformantAnimationState();
}

class _PerformantAnimationState extends State<PerformantAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _controller.value,
          child: child,
        );
      },
      child: const Icon(Icons.favorite), // Pass child to avoid rebuilding
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
```

---

## 9. Lazy Loading Implementation

### Implement Pagination
```dart
class PaginatedList extends StatefulWidget {
  @override
  State<PaginatedList> createState() => _PaginatedListState();
}

class _PaginatedListState extends State<PaginatedList> {
  final List<Item> _items = [];
  int _page = 1;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final newItems = await apiClient.getItems(page: _page);
      setState(() {
        _items.addAll(newItems);
        _page++;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: _items.length + 1,
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return _isLoading
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _loadMore,
                  child: Text('Load More'),
                );
        }
        return ListTile(title: Text(_items[index].title));
      },
    );
  }
}
```

---

## 10. Monitoring & Benchmarking

### Performance Benchmarks
```dart
void main() {
  final stopwatch = Stopwatch()..start();

  // Code to benchmark
  expensiveOperation();

  stopwatch.stop();
  print('Execution time: ${stopwatch.elapsedMilliseconds}ms');
}
```

### Memory Profiling
```bash
flutter run --profile
# Buka Memory tab di DevTools
```

### Frame Rate Monitoring
```dart
PerformanceOverlay(
  // Shows frame rate overlay
)
```

---

## Performance Checklist

- [ ] Use const widgets where possible
- [ ] Implement ListView.builder for long lists
- [ ] Cache network responses
- [ ] Dispose resources properly
- [ ] Optimize images (compression, sizing)
- [ ] Use RepaintBoundary for complex widgets
- [ ] Implement pagination for large datasets
- [ ] Profile with DevTools regularly
- [ ] Monitor memory usage
- [ ] Keep frame rate at 60 FPS
- [ ] Remove unused dependencies
- [ ] Minimize build size
- [ ] Use lazy loading
- [ ] Optimize animations
- [ ] Implement database indexing

---

## Tools & References

- [Flutter DevTools](https://flutter.dev/docs/development/tools/devtools)
- [Performance Profiling](https://flutter.dev/docs/perf/rendering)
- [Memory Profiling](https://flutter.dev/docs/perf/memory)
- [Build Size Analysis](https://flutter.dev/docs/perf/app-size)
