// lib/View/workshop/workshop_locator_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:provider/provider.dart';
import 'package:ridefix/Controller/workshop_controller.dart';
import 'widgets/workshop_list_item_card.dart';
import 'package:ridefix/Model/workshop_model.dart';

class WorkshopLocatorPage extends StatefulWidget {
  const WorkshopLocatorPage({Key? key}) : super(key: key);

  @override
  State<WorkshopLocatorPage> createState() => _WorkshopLocatorPageState();
}

class _WorkshopLocatorPageState extends State<WorkshopLocatorPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkshopController(),
      child: Consumer<WorkshopController>(
        builder: (context, controller, child) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Nearby Workshops'),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
            ),
            body: Column(
              children: [
                _buildSearchBar(controller),
                _buildMap(controller),
                _buildWorkshopList(controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(WorkshopController controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              controller.getAutocompleteSuggestions(value);
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                controller.searchNearbyWorkshops(keyword: value);
                _searchController.clear();
                FocusScope.of(context).unfocus();
              }
            },
            decoration: InputDecoration(
              hintText: 'Search workshop, location, or service...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: const Icon(Icons.search, color: Colors.blue),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  controller.getAutocompleteSuggestions('');
                  FocusScope.of(context).unfocus();
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
        ),

        // 搜索建议列表
        if (controller.predictions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 8,
                  color: Colors.black.withOpacity(0.1),
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: controller.predictions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prediction = controller.predictions[index];
                return ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: Colors.blue,
                  ),
                  title: Text(
                    prediction.mainText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    prediction.secondaryText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  onTap: () {
                    _searchController.text = prediction.mainText;
                    FocusScope.of(context).unfocus();
                    controller.searchAtPlace(prediction.placeId);
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMap(WorkshopController controller) {
    return Expanded(
      flex: 2,
      child: controller.currentPosition == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      )
          : gmaps.GoogleMap(
        onMapCreated: controller.setMapController,
        initialCameraPosition: gmaps.CameraPosition(
          target: gmaps.LatLng(
            controller.currentPosition!.latitude,
            controller.currentPosition!.longitude,
          ),
          zoom: 12,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        mapType: gmaps.MapType.normal,
        markers: controller.workshops.map((Workshop w) {
          return gmaps.Marker(
            markerId: gmaps.MarkerId(w.placeId),
            position: gmaps.LatLng(w.location.lat, w.location.lng),
            infoWindow: gmaps.InfoWindow(
              title: w.name,
              snippet: '${w.rating} ⭐ • ${w.address}',
            ),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueBlue,
            ),
          );
        }).toSet(),
      ),
    );
  }

  Widget _buildWorkshopList(WorkshopController controller) {
    if (controller.isLoading && controller.workshops.isEmpty) {
      return const Expanded(
        flex: 3,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (controller.workshops.isEmpty) {
      return Expanded(
        flex: 3,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No workshops found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try searching in a different area',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      flex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Found ${controller.workshops.length} workshops',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => controller.searchNearbyWorkshops(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.workshops.length,
              itemBuilder: (context, index) {
                final Workshop workshop = controller.workshops[index];
                final distance = controller.getDistanceToWorkshop(workshop);
                return WorkshopListItemCard(
                  workshop: workshop,
                  distanceInMeters: distance,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}