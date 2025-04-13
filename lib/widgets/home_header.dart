import 'package:flutter/material.dart';

class HomeHeader extends StatefulWidget {
  final Function()? onMenuPressed;
  final Function()? onScanPressed;
  final Function(String) onFilterChanged;
  final String currentFilter;

  const HomeHeader({
    Key? key,
    this.onMenuPressed,
    this.onScanPressed,
    required this.onFilterChanged,
    required this.currentFilter,
  }) : super(key: key);

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  // List of available filters
  final List<String> _filters = ["JOINED", "NEW", "SHOW ALL"];

  // Controller for horizontal swiping
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the correct initial page
    int initialPage = _filters.indexOf(widget.currentFilter);
    if (initialPage == -1) initialPage = 1; // Default to NEW if not found
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top row with hamburger menu and QR scanner
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Hamburger menu
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 28,
              ),

              // QR code scanner
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: widget.onScanPressed,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 28,
              ),
            ],
          ),
        ),

        // Filter tabs arranged horizontally
        Container(
          height: 60, // Taller height for larger text
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildFilterTab("JOINED", widget.currentFilter == "JOINED")),
              Expanded(child: _buildFilterTab("NEW", widget.currentFilter == "NEW")),
              Expanded(child: _buildFilterTab("SHOW ALL", widget.currentFilter == "SHOW ALL")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onFilterChanged(label),
      child: Container(
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            // Use theme's text color with appropriate opacity
            color: isSelected
              ? Theme.of(context).textTheme.bodyLarge?.color
              : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(128),
            fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300, // Bold for active, light for inactive
            fontSize: 22, // Even larger font size
            letterSpacing: 1.2, // Slightly spaced letters for better readability
          ),
        ),
      ),
    );
  }
}
