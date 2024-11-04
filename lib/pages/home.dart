import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:polybool/polybool.dart' as pb;
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
  }
  return await Geolocator.getCurrentPosition();
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  MapController mapController = MapController();
  LatLng currentPosition = const LatLng(0.0, 0.0);

  var mainPolygon = Polygon(points: [
    LatLng(-90, -180),
    LatLng(-90, 180),
    LatLng(90, 180),
    LatLng(90, -180)
  ], holePointsList: [], color: Colors.grey.withOpacity(0.85));

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      currentPosition = LatLng(position.latitude, position.longitude);
      combinePolygons(position);
    });
  }

  void moveCamera(LatLng currentPosition) {
    mapController.move(this.currentPosition, 17);
  }

  void zoomCamera(double zoomLevel) {
    mapController.move(
        mapController.camera.center, mapController.camera.zoom + zoomLevel);
  }

  void combinePolygons(Position position) async {
    pb.Polygon tempPolygon = pb.Polygon(regions: [
      [
        pb.Coordinate(position.latitude - 0.0004, position.longitude - 0.0004),
        pb.Coordinate(position.latitude - 0.0004, position.longitude + 0.0004),
        pb.Coordinate(position.latitude + 0.0004, position.longitude + 0.0004),
        pb.Coordinate(position.latitude + 0.0004, position.longitude - 0.0004)
      ]
    ]);

    pb.Polygon tempPolygon2 = pb.Polygon(
        regions: mainPolygon.holePointsList!.map((innerList) {
      return innerList
          .map((latLng) => pb.Coordinate(latLng.latitude, latLng.longitude))
          .toList();
    }).toList());
    tempPolygon = tempPolygon.union(tempPolygon2);

    mainPolygon.holePointsList?.clear();
    mainPolygon.holePointsList?.addAll(tempPolygon.regions.map((innerList) {
      return innerList
          .map((coordinates) => LatLng(coordinates.x, coordinates.y))
          .toList();
    }));
  }

  @override
  Widget build(BuildContext context) {
    BorderRadiusGeometry radius = const BorderRadius.only(
      topLeft: Radius.circular(24.0),
      topRight: Radius.circular(24.0),
    );
    return Scaffold(
      body: SlidingUpPanel(
        minHeight: MediaQuery.of(context).size.height * 0.075,
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        parallaxEnabled: true,
        parallaxOffset: 0.5,
        borderRadius: radius,
        panel: slindingUpPanel(),
        body: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialZoom: 17,
                initialCenter: currentPosition,
                minZoom: 2,
                maxZoom: 19,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.fogofland.app',
                ),
                PolygonLayer(
                  polygons: [mainPolygon],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(
                          Uri.parse('https://openstreetmap.org/copyright')),
                    ),
                  ],
                ),
                gpsMarker(),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              height: MediaQuery.of(context).size.height * 0.925,
              child: Stack(
                children: [
                  mapControlButtons(),
                  gpsButton(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget slindingUpPanel() => Center(
          child: Container(
        width: 40,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
      ));

  Widget mapControlButtons() => Align(
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () => zoomCamera(1),
              tooltip: 'ZoomUp',
              backgroundColor: const Color.fromARGB(255, 110, 248, 115),
              child: Icon(Icons.add_circle_outline_rounded),
            ),
            SizedBox(height: 10),
            FloatingActionButton(
              onPressed: () => zoomCamera(-1),
              tooltip: 'ZoomDown',
              backgroundColor: const Color.fromARGB(255, 110, 248, 115),
              child: Icon(Icons.remove_circle_outline_rounded),
            ),
          ],
        ),
      );
  Widget gpsButton() => Align(
      alignment: Alignment.bottomRight,
      child: FloatingActionButton(
        onPressed: () => moveCamera(mapController.camera.center),
        tooltip: 'GPS',
        backgroundColor: const Color.fromARGB(255, 110, 248, 115),
        child: Icon(Icons.gps_fixed),
      ));

  Widget gpsMarker() => CurrentLocationLayer(
      alignPositionOnUpdate: AlignOnUpdate.always,
      alignDirectionOnUpdate: AlignOnUpdate.never,
      style: LocationMarkerStyle(
        marker: const DefaultLocationMarker(
          color: Colors.green,
          child: Icon(
            Icons.person,
            color: Colors.white,
            size: 16,
          ),
        ),
        markerSize: const Size.square(35),
        accuracyCircleColor:
            const Color.fromARGB(255, 110, 248, 115).withOpacity(0.2),
        headingSectorColor:
            const Color.fromARGB(255, 110, 248, 115).withOpacity(0.9),
      ),
      moveAnimationDuration: Durations.long3);
}
