import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';

Future<void>? _scriptLoadFuture;
String? _loadedClientId;

Future<void> ensureNaverMapsScriptLoaded(String clientId) {
  if (clientId.isEmpty) {
    return Future.error(StateError('NAVER_MAP_CLIENT_ID is empty'));
  }
  if (_scriptLoadFuture != null && _loadedClientId == clientId) {
    return _scriptLoadFuture!;
  }
  _loadedClientId = clientId;
  _scriptLoadFuture = _loadScript(clientId);
  return _scriptLoadFuture!;
}

Future<void> _loadScript(String clientId) {
  if (_isNaverReady()) return Future.value();

  final completer = Completer<void>();
  final script = html.ScriptElement()
    ..type = 'text/javascript'
    ..src =
        'https://oapi.map.naver.com/openapi/v3/maps.js?ncpClientId=$clientId';
  script.dataset['iljari-naver-map'] = '1';
  script.onLoad.listen((_) {
    if (!completer.isCompleted) completer.complete();
  });
  script.onError.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError(Exception('NAVER Maps JS load failed'));
    }
  });
  html.document.head!.append(script);
  return completer.future;
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
  return js_util.callMethod(_mapsNamespace(), 'LatLng', [lat, lng]);
}

Object? _strokeStyleType(String style) {
  try {
    final strokeStyle = js_util.getProperty<Object>(_mapsNamespace(), 'strokeStyleType');
    return js_util.getProperty<Object?>(strokeStyle, style);
  } catch (_) {
    return null;
  }
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
    final bounds = js_util.callMethod<Object>(_map, 'getBounds', []);
    final sw = js_util.getProperty<Object>(bounds, 'min');
    final ne = js_util.getProperty<Object>(bounds, 'max');
    return MapViewportBounds(
      south: js_util.callMethod<num>(sw, 'lat', []).toDouble(),
      west: js_util.callMethod<num>(sw, 'lng', []).toDouble(),
      north: js_util.callMethod<num>(ne, 'lat', []).toDouble(),
      east: js_util.callMethod<num>(ne, 'lng', []).toDouble(),
    );
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
        zoom: 15,
      );
    } catch (_) {}
  }

  Future<({double latitude, double longitude, double zoom})> getCameraPosition() async {
    if (_disposed) {
      return (latitude: 37.5128, longitude: 127.0471, zoom: 13.0);
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

  @override
  State<NaverMapWebWidget> createState() => _NaverMapWebWidgetState();
}

class _NaverMapWebWidgetState extends State<NaverMapWebWidget> {
  static int _viewCounter = 0;

  late final String _viewType = 'iljari-naver-map-${_viewCounter++}';
  NaverMapWebController? _controller;
  Object? _map;
  final Map<String, Object> _markerHandles = {};
  final Map<String, Object> _circleHandles = {};
  final Map<String, Object> _polylineHandles = {};
  bool _registered = false;
  String? _error;
  ({double lat, double lng})? _lastReportedCenter;

  @override
  void initState() {
    super.initState();
    _registerView();
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

  void _registerView() {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final div = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.touchAction = 'none';
      unawaited(_initMap(div));
      return div;
    });
  }

  Future<void> _initMap(html.DivElement element) async {
    try {
      await ensureNaverMapsScriptLoaded(widget.clientId);
      if (!mounted) return;

      final maps = _mapsNamespace();
      final center = _latLng(widget.initialLatitude, widget.initialLongitude);
      final positionTopRight = js_util.getProperty<Object>(
        js_util.getProperty<Object>(maps, 'Position'),
        'TOP_RIGHT',
      );
      final options = js_util.jsify({
        'center': center,
        'zoom': widget.initialZoom,
        'zoomControl': true,
        'zoomControlOptions': {'position': positionTopRight},
      });

      _map = js_util.callMethod(maps, 'Map', [element, options]);
      _controller = NaverMapWebController(_map!);
      _syncAllOverlays();

      final eventNs = js_util.getProperty<Object>(maps, 'Event');
      js_util.callMethod(eventNs, 'addListener', [
        _map,
        'idle',
        js_util.allowInterop((_) => _handleIdle()),
      ]);
      js_util.callMethod(eventNs, 'addListener', [
        _map,
        'click',
        js_util.allowInterop((Object e) {
          final coord = js_util.getProperty<Object>(e, 'coord');
          final lat = js_util.callMethod<num>(coord, 'lat', []).toDouble();
          final lng = js_util.callMethod<num>(coord, 'lng', []).toDouble();
          widget.onMapTap?.call(lat, lng);
        }),
      ]);

      if (mounted) {
        widget.onMapReady?.call(_controller!);
        setState(() => _error = null);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
    _syncMarkers();
    _syncCircles();
    _syncPolylines();
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

      final existing = _markerHandles[spec.id];
      if (existing != null) {
        js_util.callMethod(existing, 'setPosition', [
          _latLng(spec.latitude, spec.longitude),
        ]);
        js_util.callMethod(existing, 'setIcon', [
          js_util.jsify({
            'content': markerHtml,
            'anchor': {'x': size / 2, 'y': size / 2},
          }),
        ]);
        continue;
      }

      final marker = js_util.callMethod<Object>(maps, 'Marker', [
        js_util.jsify({
          'map': map,
          'position': _latLng(spec.latitude, spec.longitude),
          'icon': {
            'content': markerHtml,
            'anchor': {'x': size / 2, 'y': size / 2},
          },
        }),
      ]);

      final eventNs = js_util.getProperty<Object>(maps, 'Event');
      js_util.callMethod(eventNs, 'addListener', [
        marker,
        'click',
        js_util.allowInterop((_) {
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
      final options = js_util.jsify({
        'map': map,
        'center': _latLng(spec.latitude, spec.longitude),
        'radius': spec.radiusMeters,
        'fillColor': spec.fillColorHex,
        'fillOpacity': spec.fillOpacity,
        'strokeColor': spec.strokeColorHex,
        'strokeOpacity': spec.strokeOpacity,
        'strokeWeight': spec.strokeWeight,
      });

      if (existing != null) {
        js_util.callMethod(existing, 'setOptions', [options]);
        continue;
      }

      final circle = js_util.callMethod<Object>(maps, 'Circle', [options]);
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

      final optionsMap = <String, Object?>{
        'map': map,
        'path': path,
        'strokeColor': spec.colorHex,
        'strokeWeight': spec.strokeWeight,
        'strokeOpacity': 0.85,
      };
      if (spec.dashed) {
        final dash = _strokeStyleType('shortDash');
        if (dash != null) optionsMap['strokeStyle'] = dash;
      }

      final existing = _polylineHandles[spec.id];
      if (existing != null) {
        js_util.callMethod(existing, 'setPath', [path]);
        continue;
      }

      final polyline = js_util.callMethod<Object>(
        maps,
        'Polyline',
        [js_util.jsify(optionsMap)],
      );
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
            'Web Dynamic Map Client ID와 도메인 등록을 확인해 주세요.\n\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
      );
    }
    return HtmlElementView(viewType: _viewType);
  }
}
