import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/material.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';

Future<void>? _scriptLoadFuture;
String? _loadedClientId;
String? _loadedAuthParam;

Future<void> ensureNaverMapsScriptLoaded(String clientId) async {
  final trimmed = clientId.trim();
  if (trimmed.isEmpty) {
    throw StateError('NAVER_MAP_CLIENT_ID is empty');
  }
  if (_scriptLoadFuture != null &&
      _loadedClientId == trimmed &&
      _loadedAuthParam != null) {
    await _scriptLoadFuture!;
    return;
  }
  _loadedClientId = trimmed;
  _loadedAuthParam = null;
  _scriptLoadFuture = _loadScript(trimmed);
  try {
    await _scriptLoadFuture!.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception(
        'NAVER Maps 로드 시간 초과 — ./run_web.sh 또는 ./run_qc.sh 로 다시 실행',
      ),
    );
  } on Object {
    _scriptLoadFuture = null;
    _loadedClientId = null;
    _loadedAuthParam = null;
    rethrow;
  }
}

void _removeExistingNaverScripts() {
  for (final node in html.document.querySelectorAll(
    'script[data-iljari-naver-map], script[data-iljari-naver-bootstrap]',
  )) {
    node.remove();
  }
  js_util.setProperty(html.window, 'naver', null);
}

Future<void> _waitForNaverMapsReady({
  Duration timeout = const Duration(seconds: 20),
  bool throwOnTimeout = false,
}) async {
  if (_isNaverReady()) return;
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (_isNaverReady()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  if (throwOnTimeout && !_isNaverReady()) {
    throw Exception('NAVER Maps 준비 시간 초과 (${timeout.inSeconds}s)');
  }
}

Future<void> _loadScript(String clientId) async {
  // index.html bootstrap (run_web/qc.sh 가 web-define 으로 미리 주입)
  await _waitForNaverMapsReady(timeout: const Duration(seconds: 12));
  if (_isNaverReady()) {
    _loadedAuthParam = 'bootstrap';
    return;
  }

  Object? lastError;
  for (final param in ['ncpKeyId', 'ncpClientId']) {
    try {
      _removeExistingNaverScripts();
      await _loadScriptOnce(clientId, param);
      _loadedAuthParam = param;
      await _waitForNaverMapsReady(
        timeout: const Duration(seconds: 12),
        throwOnTimeout: true,
      );
      if (_isNaverReady()) return;
    } on Object catch (error) {
      lastError = error;
      _removeExistingNaverScripts();
    }
  }

  final origin = html.window.location.origin;
  throw Exception(
    'NAVER Maps 로드 실패 (origin=$origin). '
    'NCP Web URL에 $origin 등록, Dynamic Map 체크. 원인: $lastError',
  );
}

Future<void> _loadScriptOnce(String clientId, String authParam) {
  final completer = Completer<void>();
  final callbackName =
      'iljariNaverMapsReady_${DateTime.now().millisecondsSinceEpoch}';

  js_util.setProperty(
    html.window,
    'navermap_authFailure',
    js_util.allowInterop((Object? error) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('NAVER Maps auth failed ($authParam): $error'),
        );
      }
    }),
  );

  js_util.setProperty(
    html.window,
    callbackName,
    js_util.allowInterop((Object? _) {
      if (!completer.isCompleted) completer.complete();
    }),
  );

  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..src =
        'https://oapi.map.naver.com/openapi/v3/maps.js?$authParam=$clientId&submodules=geocoder&callback=$callbackName';
  script.dataset['iljari-naver-map'] = '1';
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('NAVER Maps JS load failed ($authParam)'));
    }
  });
  html.document.head!.append(script);
  return completer.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw Exception(
      'NAVER Maps callback timeout ($authParam) — '
      'NCP Web URL에 ${html.window.location.origin} 등록 확인',
    ),
  );
}

bool _isNaverReady() {
  final naver = js_util.getProperty<Object?>(html.window, 'naver');
  if (naver == null) return false;
  return js_util.getProperty<Object?>(naver, 'maps') != null;
}

Object _mapsNamespace() {
  final naver = js_util.getProperty<Object>(html.window, 'naver');
  return js_util.getProperty<Object>(naver, 'maps');
}

Object _latLng(double lat, double lng) {
  final latLngCtor = js_util.getProperty<Object>(_mapsNamespace(), 'LatLng');
  return js_util.callConstructor(latLngCtor, [lat, lng]);
}

Object _mapOptions({
  required Object center,
  required double zoom,
  int? width,
  int? height,
}) {
  final options = js_util.newObject();
  js_util.setProperty(options, 'center', center);
  js_util.setProperty(options, 'zoom', zoom);
  js_util.setProperty(options, 'zoomControl', true);
  if (width != null && height != null && width > 0 && height > 0) {
    final sizeCtor = js_util.getProperty<Object>(_mapsNamespace(), 'Size');
    js_util.setProperty(
      options,
      'size',
      js_util.callConstructor(sizeCtor, [width, height]),
    );
  }
  return options;
}

void _stretchElementTree(html.Element element) {
  var node = element;
  for (var depth = 0; depth < 8; depth++) {
    node.style
      ..display = 'block'
      ..width = '100%'
      ..height = '100%'
      ..minWidth = '100%'
      ..minHeight = '100%';
    final parent = node.parent;
    if (parent == null || parent is! html.Element) break;
    node = parent;
  }
  element.style
    ..position = 'absolute'
    ..top = '0'
    ..left = '0'
    ..right = '0'
    ..bottom = '0'
    ..touchAction = 'none';
}

Future<void> _waitForElementLayout(html.DivElement element) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    if (element.clientWidth > 240 && element.clientHeight > 240) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void _syncMapSize(Object map, html.DivElement element) {
  final width = element.clientWidth;
  final height = element.clientHeight;
  if (width <= 0 || height <= 0) return;

  final maps = _mapsNamespace();
  final sizeCtor = js_util.getProperty<Object>(maps, 'Size');
  final size = js_util.callConstructor(sizeCtor, [width, height]);
  js_util.callMethod(map, 'setSize', [size]);

  final eventNs = js_util.getProperty<Object>(maps, 'Event');
  js_util.callMethod(eventNs, 'trigger', [map, 'resize']);
}

Object? _strokeStyleType(String style) {
  try {
    final strokeStyle = js_util.getProperty<Object>(_mapsNamespace(), 'strokeStyleType');
    return js_util.getProperty<Object?>(strokeStyle, style);
  } catch (_) {
    return null;
  }
}

Object _markerHtmlIcon(Object maps, String markerHtml, double size) {
  final pointCtor = js_util.getProperty<Object>(maps, 'Point');
  final anchor = js_util.callConstructor(pointCtor, [size / 2, size / 2]);
  final icon = js_util.newObject();
  js_util.setProperty(icon, 'content', markerHtml);
  js_util.setProperty(icon, 'anchor', anchor);
  return icon;
}

Object _circleOptions({
  required Object map,
  required NaverMapWebCircleSpec spec,
}) {
  final options = js_util.newObject();
  js_util.setProperty(options, 'map', map);
  js_util.setProperty(
    options,
    'center',
    _latLng(spec.latitude, spec.longitude),
  );
  js_util.setProperty(options, 'radius', spec.radiusMeters);
  js_util.setProperty(options, 'fillColor', spec.fillColorHex);
  js_util.setProperty(options, 'fillOpacity', spec.fillOpacity);
  js_util.setProperty(options, 'strokeColor', spec.strokeColorHex);
  js_util.setProperty(options, 'strokeOpacity', spec.strokeOpacity);
  js_util.setProperty(options, 'strokeWeight', spec.strokeWeight);
  return options;
}

Object _polylineOptions({
  required Object map,
  required NaverMapWebPolylineSpec spec,
  required List<Object> path,
}) {
  final options = js_util.newObject();
  js_util.setProperty(options, 'map', map);
  js_util.setProperty(options, 'path', path);
  js_util.setProperty(options, 'strokeColor', spec.colorHex);
  js_util.setProperty(options, 'strokeWeight', spec.strokeWeight);
  js_util.setProperty(options, 'strokeOpacity', 0.85);
  if (spec.dashed) {
    final dash = _strokeStyleType('shortDash');
    if (dash != null) js_util.setProperty(options, 'strokeStyle', dash);
  }
  return options;
}

typedef NaverMapWebIdleCallback = void Function();
typedef NaverMapWebTapCallback = void Function(double lat, double lng);
typedef NaverMapWebCenterCallback = void Function(double lat, double lng);

class NaverMapWebMarkerSpec {
  const NaverMapWebMarkerSpec({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.colorHex,
    required this.label,
    this.isSelected = false,
    this.isOwn = false,
    this.size = 28,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String colorHex;
  final String label;
  final bool isSelected;
  final bool isOwn;
  final double size;
}

class NaverMapWebCircleSpec {
  const NaverMapWebCircleSpec({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.fillColorHex,
    required this.strokeColorHex,
    this.fillOpacity = 0.16,
    this.strokeOpacity = 1.0,
    this.strokeWeight = 2.5,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String fillColorHex;
  final String strokeColorHex;
  final double fillOpacity;
  final double strokeOpacity;
  final double strokeWeight;
}

class NaverMapWebPolylineSpec {
  const NaverMapWebPolylineSpec({
    required this.id,
    required this.points,
    required this.colorHex,
    this.strokeWeight = 5,
    this.dashed = false,
  });

  final String id;
  final List<({double latitude, double longitude})> points;
  final String colorHex;
  final double strokeWeight;
  final bool dashed;
}

abstract final class NaverMapWebColors {
  static String hex(Color color) {
    final v = color.toARGB32();
    return '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }
}

class NaverMapWebController {
  NaverMapWebController(this._map);

  final Object _map;
  bool _disposed = false;

  bool get isReady => !_disposed;

  Future<MapViewportBounds> getViewportBounds() async {
    if (_disposed) {
      return MapViewportBounds.fromCenter(
        centerLat: 37.5128,
        centerLng: 127.0471,
        latSpan: 0.06,
        lngSpan: 0.06,
      );
    }
    try {
      final bounds = js_util.callMethod<Object>(_map, 'getBounds', []);
      final sw = js_util.getProperty<Object>(bounds, 'min');
      final ne = js_util.getProperty<Object>(bounds, 'max');
      return MapViewportBounds(
        south: js_util.callMethod<num>(sw, 'lat', []).toDouble(),
        west: js_util.callMethod<num>(sw, 'lng', []).toDouble(),
        north: js_util.callMethod<num>(ne, 'lat', []).toDouble(),
        east: js_util.callMethod<num>(ne, 'lng', []).toDouble(),
      );
    } catch (_) {
      final camera = await getCameraPosition();
      return MapViewportBounds.fromCenter(
        centerLat: camera.latitude,
        centerLng: camera.longitude,
        latSpan: 0.06,
        lngSpan: 0.06,
      );
    }
  }

  Future<void> moveCamera({
    required double latitude,
    required double longitude,
    double? zoom,
  }) async {
    if (_disposed) return;
    final target = _latLng(latitude, longitude);
    if (zoom != null) {
      js_util.callMethod(_map, 'morph', [target, zoom]);
    } else {
      js_util.callMethod(_map, 'setCenter', [target]);
    }
  }

  Future<void> moveToCurrentLocation() async {
    if (_disposed) return;
    try {
      final position = await html.window.navigator.geolocation!.getCurrentPosition(
        enableHighAccuracy: true,
      );
      await moveCamera(
        latitude: position.coords!.latitude!.toDouble(),
        longitude: position.coords!.longitude!.toDouble(),
        zoom: MapConstants.defaultZoom,
      );
    } catch (_) {}
  }

  Future<({double latitude, double longitude, double zoom})> getCameraPosition() async {
    if (_disposed) {
      return (latitude: 37.5128, longitude: 127.0471, zoom: MapConstants.defaultZoom);
    }
    final center = js_util.callMethod<Object>(_map, 'getCenter', []);
    final zoom = js_util.callMethod<num>(_map, 'getZoom', []).toDouble();
    return (
      latitude: js_util.callMethod<num>(center, 'lat', []).toDouble(),
      longitude: js_util.callMethod<num>(center, 'lng', []).toDouble(),
      zoom: zoom,
    );
  }

  void dispose() {
    _disposed = true;
  }
}

class NaverMapWebWidget extends StatefulWidget {
  const NaverMapWebWidget({
    super.key,
    required this.clientId,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialZoom,
    this.markers = const [],
    this.circles = const [],
    this.polylines = const [],
    this.centerEditable = false,
    this.trackCenterLatitude,
    this.trackCenterLongitude,
    this.onMapReady,
    this.onCameraIdle,
    this.onCenterChanged,
    this.onMapTap,
    this.onMarkerTap,
    this.onInitFailed,
  });

  final String clientId;
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final List<NaverMapWebMarkerSpec> markers;
  final List<NaverMapWebCircleSpec> circles;
  final List<NaverMapWebPolylineSpec> polylines;
  final bool centerEditable;
  final double? trackCenterLatitude;
  final double? trackCenterLongitude;
  final void Function(NaverMapWebController controller)? onMapReady;
  final NaverMapWebIdleCallback? onCameraIdle;
  final NaverMapWebCenterCallback? onCenterChanged;
  final NaverMapWebTapCallback? onMapTap;
  final void Function(String markerId)? onMarkerTap;
  final VoidCallback? onInitFailed;

  @override
  State<NaverMapWebWidget> createState() => _NaverMapWebWidgetState();
}

class _NaverMapWebWidgetState extends State<NaverMapWebWidget> {
  NaverMapWebController? _controller;
  Object? _map;
  html.DivElement? _container;
  StreamSubscription<html.Event>? _windowResize;
  final Map<String, Object> _markerHandles = {};
  final Map<String, Object> _circleHandles = {};
  final Map<String, Object> _polylineHandles = {};
  bool _elementInitialized = false;
  bool _mapReady = false;
  String? _error;
  ({double lat, double lng})? _lastReportedCenter;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(NaverMapWebWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_map == null) return;

    if (oldWidget.markers != widget.markers ||
        oldWidget.circles != widget.circles ||
        oldWidget.polylines != widget.polylines) {
      _syncAllOverlays();
    }

    if (widget.trackCenterLatitude != null &&
        widget.trackCenterLongitude != null &&
        (oldWidget.trackCenterLatitude != widget.trackCenterLatitude ||
            oldWidget.trackCenterLongitude != widget.trackCenterLongitude)) {
      unawaited(
        _controller?.moveCamera(
          latitude: widget.trackCenterLatitude!,
          longitude: widget.trackCenterLongitude!,
        ),
      );
    }
  }

  @override
  void dispose() {
    _windowResize?.cancel();
    _controller?.dispose();
    _clearOverlayHandles(_markerHandles);
    _clearOverlayHandles(_circleHandles);
    _clearOverlayHandles(_polylineHandles);
    super.dispose();
  }

  void _clearOverlayHandles(Map<String, Object> handles) {
    for (final handle in handles.values) {
      js_util.callMethod(handle, 'setMap', [null]);
    }
    handles.clear();
  }

  void _onElementCreated(Object element) {
    if (_elementInitialized) return;
    _elementInitialized = true;
    final div = element as html.DivElement;
    _container = div;
    _stretchElementTree(div);
    unawaited(_initMap(div));
  }

  void _bindResize(html.DivElement element, Object map) {
    _windowResize?.cancel();
    _windowResize = html.window.onResize.listen((_) {
      if (_map == null) return;
      _syncMapSize(map, element);
    });

    try {
      final observerCtor = js_util.getProperty<Object?>(
        html.window,
        'ResizeObserver',
      );
      if (observerCtor == null) return;
      final observer = js_util.callConstructor(observerCtor, [
        js_util.allowInterop((dynamic _, dynamic __) {
          if (_map == null) return;
          _syncMapSize(map, element);
        }),
      ]);
      js_util.callMethod(observer, 'observe', [element]);
    } on Object {
      // ResizeObserver unavailable — window.onResize only
    }
  }

  Future<void> _initMap(html.DivElement element) async {
    try {
      await ensureNaverMapsScriptLoaded(widget.clientId).timeout(
        const Duration(seconds: 28),
        onTimeout: () => throw Exception(
          'NAVER 지도 초기화 시간 초과 — 터미널에서 q 후 ./run_web.sh 재실행',
        ),
      );
      if (!mounted) return;

      await _waitForElementLayout(element);
      _stretchElementTree(element);
      if (!mounted) return;

      final maps = _mapsNamespace();
      final center = _latLng(widget.initialLatitude, widget.initialLongitude);
      final options = _mapOptions(
        center: center,
        zoom: widget.initialZoom,
        width: element.clientWidth,
        height: element.clientHeight,
      );
      final mapCtor = js_util.getProperty<Object>(maps, 'Map');
      _map = js_util.callConstructor(mapCtor, [element, options]);
      _controller = NaverMapWebController(_map!);
      _bindResize(element, _map!);
      _syncMapSize(_map!, element);
      _syncAllOverlays();

      final eventNs = js_util.getProperty<Object>(maps, 'Event');
      js_util.callMethod(eventNs, 'addListener', [
        _map,
        'idle',
        js_util.allowInterop((Object? _) => _handleIdle()),
      ]);
      js_util.callMethod(eventNs, 'addListener', [
        _map,
        'click',
        js_util.allowInterop((Object? e) {
          if (e == null) return;
          final coord = js_util.getProperty<Object>(e, 'coord');
          final lat = js_util.callMethod<num>(coord, 'lat', []).toDouble();
          final lng = js_util.callMethod<num>(coord, 'lng', []).toDouble();
          widget.onMapTap?.call(lat, lng);
        }),
      ]);

      for (final delay in [100, 400, 1000]) {
        Future<void>.delayed(Duration(milliseconds: delay), () {
          if (!mounted || _map == null) return;
          _stretchElementTree(element);
          _syncMapSize(_map!, element);
        });
      }

      if (mounted) {
        widget.onMapReady?.call(_controller!);
        setState(() {
          _error = null;
          _mapReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        widget.onInitFailed?.call();
      }
    }
  }

  void _handleIdle() {
    widget.onCameraIdle?.call();
    if (!widget.centerEditable || widget.onCenterChanged == null) return;

    final map = _map;
    if (map == null) return;

    final center = js_util.callMethod<Object>(map, 'getCenter', []);
    final lat = js_util.callMethod<num>(center, 'lat', []).toDouble();
    final lng = js_util.callMethod<num>(center, 'lng', []).toDouble();

    final last = _lastReportedCenter;
    if (last != null &&
        (last.lat - lat).abs() < 0.000001 &&
        (last.lng - lng).abs() < 0.000001) {
      return;
    }
    _lastReportedCenter = (lat: lat, lng: lng);
    widget.onCenterChanged?.call(lat, lng);
    _syncAllOverlays();
  }

  void _syncAllOverlays() {
    try {
      _syncMarkers();
      _syncCircles();
      _syncPolylines();
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _syncMarkers() {
    final map = _map;
    if (map == null) return;

    final maps = _mapsNamespace();
    final nextIds = widget.markers.map((m) => m.id).toSet();

    for (final id in _markerHandles.keys.toList()) {
      if (!nextIds.contains(id)) {
        js_util.callMethod(_markerHandles[id]!, 'setMap', [null]);
        _markerHandles.remove(id);
      }
    }

    for (final spec in widget.markers) {
      final size = spec.isSelected ? spec.size * 1.15 : spec.size;
      final border = spec.isSelected ? '#FF6F00' : '#FFFFFF';
      final safeLabel = spec.label
          .replaceAll('&', '&amp;')
          .replaceAll('<', '&lt;')
          .replaceAll('>', '&gt;');
      final markerHtml =
          '<div style="width:${size}px;height:${size}px;border-radius:50%;'
          'background:${spec.colorHex};border:2.5px solid $border;'
          'display:flex;align-items:center;justify-content:center;'
          'color:#fff;font-weight:800;font-size:11px;'
          'box-shadow:0 2px 8px rgba(0,0,0,.35);cursor:pointer;">'
          '$safeLabel</div>';

      final icon = _markerHtmlIcon(maps, markerHtml, size);
      final existing = _markerHandles[spec.id];
      if (existing != null) {
        js_util.callMethod(existing, 'setPosition', [
          _latLng(spec.latitude, spec.longitude),
        ]);
        js_util.callMethod(existing, 'setIcon', [icon]);
        continue;
      }

      final markerOptions = js_util.newObject();
      js_util.setProperty(markerOptions, 'map', map);
      js_util.setProperty(
        markerOptions,
        'position',
        _latLng(spec.latitude, spec.longitude),
      );
      js_util.setProperty(markerOptions, 'icon', icon);
      final markerCtor = js_util.getProperty<Object>(maps, 'Marker');
      final marker = js_util.callConstructor(markerCtor, [markerOptions]);

      final eventNs = js_util.getProperty<Object>(maps, 'Event');
      js_util.callMethod(eventNs, 'addListener', [
        marker,
        'click',
        js_util.allowInterop((Object? _) {
          widget.onMarkerTap?.call(spec.id);
        }),
      ]);

      _markerHandles[spec.id] = marker;
    }
  }

  void _syncCircles() {
    final map = _map;
    if (map == null) return;

    final maps = _mapsNamespace();
    final nextIds = widget.circles.map((c) => c.id).toSet();

    for (final id in _circleHandles.keys.toList()) {
      if (!nextIds.contains(id)) {
        js_util.callMethod(_circleHandles[id]!, 'setMap', [null]);
        _circleHandles.remove(id);
      }
    }

    for (final spec in widget.circles) {
      final existing = _circleHandles[spec.id];
      final options = _circleOptions(map: map, spec: spec);

      if (existing != null) {
        js_util.callMethod(existing, 'setOptions', [options]);
        continue;
      }

      final circleCtor = js_util.getProperty<Object>(maps, 'Circle');
      final circle = js_util.callConstructor(circleCtor, [options]);
      _circleHandles[spec.id] = circle;
    }
  }

  void _syncPolylines() {
    final map = _map;
    if (map == null) return;

    final maps = _mapsNamespace();
    final nextIds = widget.polylines.map((p) => p.id).toSet();

    for (final id in _polylineHandles.keys.toList()) {
      if (!nextIds.contains(id)) {
        js_util.callMethod(_polylineHandles[id]!, 'setMap', [null]);
        _polylineHandles.remove(id);
      }
    }

    for (final spec in widget.polylines) {
      if (spec.points.length < 2) continue;

      final path = [
        for (final p in spec.points) _latLng(p.latitude, p.longitude),
      ];

      final existing = _polylineHandles[spec.id];
      if (existing != null) {
        js_util.callMethod(existing, 'setPath', [path]);
        continue;
      }

      final options = _polylineOptions(map: map, spec: spec, path: path);
      final polylineCtor = js_util.getProperty<Object>(maps, 'Polyline');
      final polyline = js_util.callConstructor(polylineCtor, [options]);
      _polylineHandles[spec.id] = polyline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'NAVER 지도를 불러오지 못했습니다.\n'
            'NCP Application - Dynamic Map + Web URL 등록을 확인해 주세요.\n'
            '아래 주소를 NCP Web URL에 그대로 추가: ${html.window.location.origin}\n\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: HtmlElementView.fromTagName(
              tagName: 'div',
              onElementCreated: _onElementCreated,
            ),
          ),
          if (!_mapReady)
            const ColoredBox(
              color: Color(0xFFE8EDF2),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'NAVER 지도 불러오는 중…',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
