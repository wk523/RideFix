import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:ridefix/Controller/EmergencyService/EmergencyServiceController.dart';
import 'package:ridefix/Model/emergency_service_model.dart';
import 'package:ridefix/View/RoadsideEmergency/SosConfirmation.dart';

class EmergencyServicePage extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const EmergencyServicePage({super.key, required this.userDoc});

  @override
  State<EmergencyServicePage> createState() => _EmergencyServicePageState();
}

class _EmergencyServicePageState extends State<EmergencyServicePage> {
  // Map Controller is now managed by the EmergencyServiceController.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = Provider.of<EmergencyServiceController>(
        context,
        listen: false,
      );
      controller.loadEmergencyServices(context);
      // Call the new method to load favorites for the current user
      controller.loadFavorites(widget.userDoc.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<EmergencyServiceController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadside Service'),
        centerTitle: true,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Google Map View
          _buildMapView(controller),

          // 2. Search, Filter, and Locate Bar
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _buildCombinedSearchBar(controller),
          ),

          // 3. Action Buttons (SOS & Checklist)
          Positioned(top: 75, right: 10, child: _buildActionButtons(context)),

          // 4. Expandable Service List (Bottom Sheet)
          Positioned.fill(
            child: DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.85,
              builder: (context, scrollController) {
                return _buildServiceListSheet(controller, scrollController);
              },
            ),
          ),

          if (controller.isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  // --- Combined Search/Filter/Locate Bar ---

  Widget _buildCombinedSearchBar(EmergencyServiceController controller) {
    return Row(
      children: [
        // 1. Search Bar
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              onChanged: controller
                  .setSearchQuery, // FIX 3: Correctly calls setSearchQuery
              decoration: const InputDecoration(
                hintText: 'Search Service Here',
                border: InputBorder.none,
                icon: Icon(Icons.search, color: Colors.grey),
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Filter Button
        _buildFilterButton(controller),
        const SizedBox(width: 8),

        // 3. Locate (Recenter) Button
        _buildRecenterButton(controller),
      ],
    );
  }

  Widget _buildFilterButton(EmergencyServiceController controller) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.filter_list),
        color: Colors.black54,
        onPressed: () => _showFilterDialog(context, controller),
      ),
    );
  }

  Widget _buildRecenterButton(EmergencyServiceController controller) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.my_location),
        color: controller.currentPosition != null ? Colors.blue : Colors.grey,
        onPressed: () => controller.recenterMap(
          context,
        ), // FIX 2: Passes context to recenterMap
      ),
    );
  }

  // --- Action Buttons (omitted for brevity) ---

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FloatingActionButton.extended(
            heroTag: "sosBtn",
            onPressed: () {
              // Navigate to the new page for the quick checklist and final SOS trigger
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SosConfirmationPage(
                    userDoc: widget.userDoc, // <--- Pass the userDoc
                  ),
                ),
              );
            },
            icon: const Icon(Icons.sos_outlined, size: 24),
            label: const Text('Send SOS'),
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // --- Map View ---

  Widget _buildMapView(EmergencyServiceController controller) {
    final LatLng initialTarget =
        controller.currentPosition ??
        EmergencyServiceController.kDefaultLocation.target;

    return GoogleMap(
      markers: controller.markers,
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: 14.0),
      onMapCreated: (mapController) {
        controller.setMapController(mapController);
      },
      myLocationEnabled: controller.currentPosition != null,
      myLocationButtonEnabled: false,
    );
  }

  // --- Service List Sheet ---

  Widget _buildServiceListSheet(
    EmergencyServiceController controller,
    ScrollController scrollController,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Nearby Roadside Services (${controller.filteredServices.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Service List
          Expanded(
            child: controller.filteredServices.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No services found. Try widening your search or check your location settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: controller.filteredServices.length,
                    itemBuilder: (context, index) {
                      final service = controller.filteredServices[index];
                      return _buildServiceListItem(context, service);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceListItem(BuildContext context, ServicePlace service) {
    final controller = Provider.of<EmergencyServiceController>(context);
    final isFavorite = controller.favoriteServiceIds.contains(service.id);
    final userId = widget.userDoc.id; // Get the user ID from the widget

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.call, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            // Call the phone number function
                            controller.callService(service.phone);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Attempting to call ${service.phone}',
                                ),
                              ),
                            );
                          },
                          child: Text(
                            // Show phone number, handle 'N/A' case
                            service.phone != 'N/A'
                                ? service.phone
                                : 'Phone Unavailable',
                            style: TextStyle(
                              fontSize: 14,
                              color: service.phone != 'N/A'
                                  ? Colors.green.shade700
                                  : Colors.grey,
                              decoration: service.phone != 'N/A'
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${service.rating.toStringAsFixed(1)} (${service.totalReviews})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${service.distanceKm.toStringAsFixed(1)} km (${service.distanceKm <= 1.5 ? "near to you" : "away"})',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    // 1. Icon changes based on state
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: Colors.red,
                    ),
                    // 2. Tap handler calls the new controller method
                    onPressed: () {
                      controller.toggleFavorite(userId, service);
                    },
                  ),
                  // IconButton(
                  //   icon: const Icon(Icons.info_outline, color: Colors.blue),
                  //   onPressed: () {
                  //     // Show detailed info
                  //   },
                  // ),
                ],
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  void _showFilterDialog(
    BuildContext context,
    EmergencyServiceController controller,
  ) {
    // Use the local context (which has the provider) to show the sheet.
    // We use the same 'context' that was passed into this function.
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        // Use a new variable name 'sheetContext' for clarity
        // FIX: Use the controller instance passed to the method to read the current filter
        final currentFilter = controller.selectedFilter;

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sort Results By',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.swap_vert),
                title: const Text('Nearest Distance'),
                // Check the filter directly from the controller instance
                trailing: currentFilter == 'Distance'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  // Call the controller method directly
                  controller.setSortFilter('Distance');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.star),
                title: const Text('Highest Rating'),
                // Check the filter directly from the controller instance
                trailing: currentFilter == 'Rating'
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  // Call the controller method directly
                  controller.setSortFilter('Rating');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
