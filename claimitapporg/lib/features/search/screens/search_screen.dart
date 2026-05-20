import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../auth/providers/auth_provider.dart';
import '../../shops/screens/shop_list_screen.dart';
import '../../shops/services/shop_service.dart';
import '../../../shared/widgets/shop_filter_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen
// States: empty (recent + popular) | typing (suggestions) | results
// ─────────────────────────────────────────────────────────────────────────────

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  String _query = '';
  bool _isTyping = false;

  // ── API search results ────────────────────────────────────────────────────
  List<ShopItem> _rawSearchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // ── Category name → ID (for searching "pharmacy", "salon", etc.) ──────────
  static const Map<String, int> _catNameToId = {
    'new deals': 1,    'groceries': 2,   'supermarket': 3,  'pharmacy': 4,
    'salon': 5,        'gym': 6,         'restaurant': 7,   'restaurants': 7,
    'cafe': 8,         'cafes': 8,       'coffee': 8,       'clothing': 9,
    'department': 10,  'electronics': 11,'books': 12,       'toys': 13,
    'baby': 14,        'home decor': 15, 'furniture': 16,   'spa': 17,
    'schools': 18,     'school': 18,     'colleges': 19,    'college': 19,
    'tutoring': 20,    'clinics': 21,    'clinic': 21,      'hospitals': 22,
    'hospital': 22,    'pets': 23,       'pet': 23,         'sports': 24,
    'travel': 25,      'mobile': 26,     'computer': 27,    'laptop': 27,
    'gifts': 28,       'jewellery': 29,  'jewelry': 29,     'shoes': 30,
  };

  // ── Filter state ──────────────────────────────────────────────────────────
  String? _sort;
  int? _filterCatId;
  double? _minRating;
  String? _priceSort;

  int get _filterCount {
    int c = 0;
    if (_sort != null) c++;
    if (_filterCatId != null) c++;
    if (_minRating != null) c++;
    if (_priceSort != null) c++;
    return c;
  }

  // ── Speech-to-text ────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  // Recent searches
  final List<String> _recentSearches = [
    'Sathya store',
    'restaurants',
    'mobile phones',
  ];

  final List<String> _popularSearches = [
    'Groceries near me',
    'Salon & Beauty',
    'Pharmacy',
    'Electronics',
    'Gym & Fitness',
    'Cafes & Coffee',
    'Jewellery',
    'Shoes & Footwear',
  ];

  // ── Filtered results (applied over raw API results) ───────────────────────
  List<ShopItem> get _results {
    if (_query.trim().isEmpty) return [];
    List<ShopItem> shops = List.of(_rawSearchResults);

    if (_sort == 'recently_added') {
      shops = [...shops]..sort((a, b) => a.addedDaysAgo.compareTo(b.addedDaysAgo));
    } else if (_sort == '30_disc') {
      shops = shops.where((s) => s.discount == 30).toList();
    } else if (_sort == '50_above') {
      shops = shops.where((s) => s.discount >= 50).toList();
    } else if (_sort == '20_disc') {
      shops = shops.where((s) => s.discount == 20).toList();
    } else if (_sort == '10_disc') {
      shops = shops.where((s) => s.discount == 10).toList();
    } else if (_sort == 'last_7_days') {
      shops = shops.where((s) => s.addedDaysAgo <= 7).toList();
    }

    if (_filterCatId != null) {
      shops = shops.where((s) => s.categoryIds.contains(_filterCatId)).toList();
    }
    if (_minRating != null) {
      shops = shops.where((s) => s.rating >= _minRating!).toList();
    }
    if (_priceSort == 'high_to_low') {
      shops = [...shops]..sort((a, b) => b.discount.compareTo(a.discount));
    } else if (_priceSort == 'low_to_high') {
      shops = [...shops]..sort((a, b) => a.discount.compareTo(b.discount));
    }

    return shops;
  }

  // ── Backend search ────────────────────────────────────────────────────────
  Future<void> _doSearch(String q) async {
    if (q.trim().isEmpty) return;
    if (!mounted) return;
    setState(() => _isSearching = true);
    try {
      final lower = q.trim().toLowerCase();
      final catId = _catNameToId[lower];
      final List<ShopItem> fetched = catId != null
          ? await ShopService.instance.fetchShopsByCategory(catId)
          : await ShopService.instance.searchShops(q.trim());
      if (mounted) setState(() { _rawSearchResults = fetched; _isSearching = false; });
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final text = _ctrl.text;
      setState(() {
        _query = text;
        _isTyping = text.isNotEmpty;
        if (text.trim().isEmpty) _rawSearchResults = [];
      });
      if (text.trim().isNotEmpty) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 450), () => _doSearch(text));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_isListening) _speech.stop();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Search helpers ────────────────────────────────────────────────────────
  void _submitSearch(String val) {
    if (val.trim().isEmpty) return;
    final q = val.trim();
    setState(() {
      _recentSearches.remove(q);
      _recentSearches.insert(0, q);
      if (_recentSearches.length > 8) _recentSearches.removeLast();
      _isTyping = false; // switch from suggestions pane → results pane
    });
    _focus.unfocus();
    _debounce?.cancel();
    _doSearch(q); // fire immediately on submit
  }

  void _clearAll() => setState(() => _recentSearches.clear());

  void _removeRecent(String item) => setState(() => _recentSearches.remove(item));

  void _tapSuggestion(String text) {
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    _submitSearch(text);
  }

  // ── Filter ────────────────────────────────────────────────────────────────
  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShopFilterSheet(
        initialSort: _sort,
        initialCatId: _filterCatId,
        initialRating: _minRating,
        initialPrice: _priceSort,
        onApply: (sort, catId, rating, price) {
          setState(() {
            _sort = sort;
            _filterCatId = catId;
            _minRating = rating;
            _priceSort = price;
          });
          // Re-fetch if query is active so category filter takes effect
          if (_query.trim().isNotEmpty) _doSearch(_query.trim());
        },
      ),
    );
  }

  // ── Speech-to-text ────────────────────────────────────────────────────────
  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Speech recognition not available on this device.'),
          backgroundColor: const Color(0xFF1565C0),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      _focus.unfocus();
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            _ctrl.text = words;
            _ctrl.selection = TextSelection.collapsed(offset: words.length);
            setState(() {
              _query = words;
              _isTyping = true;
            });
            if (result.finalResult) {
              _submitSearch(words);
              setState(() => _isListening = false);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_IN',
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final results = _results;
    final showResults = _query.trim().isNotEmpty;
    final showTyping = _isTyping && _query.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          showResults
              ? (_isSearching
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                  : (showTyping && results.isEmpty
                      ? _buildSuggestions()
                      : _buildResults(results)))
              : _buildEmpty(),
          if (_isListening) _buildListeningOverlay(),
        ],
      ),
    );
  }

  // ── AppBar — white, same design as home/dashboard ─────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final location = context.select<AuthProvider, String>(
      (a) => a.user?.location?.isNotEmpty == true
          ? a.user!.location!
          : 'Select Area',
    );

    return PreferredSize(
      preferredSize: const Size.fromHeight(112),
      child: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: logo + location + notification
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/main_icon.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'claimit',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => context.push('/location'),
                      child: Row(
                        children: [
                          Text(
                            location,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Notification — use go() because /notifications is a ShellRoute child
                    GestureDetector(
                      onTap: () => context.go('/notifications'),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 26,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFF3F4F6)),

              // Row 2: back + search field with live mic
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF1565C0), size: 20),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 42,
                        decoration: BoxDecoration(
                          color: _isListening
                              ? const Color(0xFFEFF6FF)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _isListening
                                ? const Color(0xFF1565C0)
                                : const Color(0xFFE5E7EB),
                            width: _isListening ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              Icons.search_rounded,
                              color: _isListening
                                  ? const Color(0xFF1565C0)
                                  : const Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _ctrl,
                                focusNode: _focus,
                                onSubmitted: _submitSearch,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF111827)),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: _isListening
                                      ? 'Listening...'
                                      : 'Search shops, offers...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: _isListening
                                        ? const Color(0xFF1565C0)
                                        : const Color(0xFF9CA3AF),
                                  ),
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_query.isNotEmpty && !_isListening)
                              GestureDetector(
                                onTap: () {
                                  _ctrl.clear();
                                  _focus.requestFocus();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(Icons.close_rounded,
                                      color: Color(0xFF6B7280), size: 18),
                                ),
                              ),
                            // Mic button
                            GestureDetector(
                              onTap: _toggleListening,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _isListening
                                    ? const _PulsingMic()
                                    : Icon(
                                        Icons.mic_rounded,
                                        color: _speechAvailable
                                            ? const Color(0xFF1565C0)
                                            : const Color(0xFF9CA3AF),
                                        size: 20,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Listening overlay (slides up from bottom) ─────────────────────────────
  Widget _buildListeningOverlay() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
                color: Color(0x20000000), blurRadius: 24, offset: Offset(0, -4)),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Animated mic rings
            const _AnimatedListeningMic(),

            const SizedBox(height: 20),

            const Text(
              'Listening...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Speak now — say a shop name, category or location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),

            // Live partial result
            if (_query.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF1565C0).withOpacity(0.3)),
                ),
                child: Text(
                  '"$_query"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Stop button
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.stop_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap to stop',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }

  // ── State 1: Empty ────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Search',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827)),
              ),
              GestureDetector(
                onTap: _clearAll,
                child: const Text(
                  'Clear all',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._recentSearches.map((item) => _RecentRow(
                text: item,
                onTap: () => _tapSuggestion(item),
                onRemove: () => _removeRecent(item),
              )),
          const SizedBox(height: 24),
        ],
        const Text(
          "Popular Search's",
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827)),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularSearches.map((item) {
            return GestureDetector(
              onTap: () => _tapSuggestion(item),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded,
                        size: 14, color: Color(0xFF1565C0)),
                    const SizedBox(width: 6),
                    Text(
                      item,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── State 2: Typing suggestions ───────────────────────────────────────────
  Widget _buildSuggestions() {
    final q = _query.toLowerCase();
    final suggestions = [
      ..._recentSearches.where((s) => s.toLowerCase().contains(q)),
      ..._popularSearches.where(
          (s) => s.toLowerCase().contains(q) && !_recentSearches.contains(s)),
    ];

    if (suggestions.isEmpty) return _buildNoResults();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: suggestions.length,
      itemBuilder: (_, i) {
        final s = suggestions[i];
        return _RecentRow(
          text: s,
          onTap: () => _tapSuggestion(s),
          onRemove:
              _recentSearches.contains(s) ? () => _removeRecent(s) : null,
        );
      },
    );
  }

  // ── State 3: Results ──────────────────────────────────────────────────────
  Widget _buildResults(List<ShopItem> results) {
    if (results.isEmpty) return _buildNoResults();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${results.length} result${results.length != 1 ? 's' : ''} found',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openFilter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _filterCount > 0
                        ? const Color(0xFFEFF6FF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filterCount > 0
                          ? const Color(0xFF1565C0)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded,
                          size: 14,
                          color: _filterCount > 0
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF374151)),
                      const SizedBox(width: 5),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 12,
                          color: _filterCount > 0
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_filterCount > 0) ...[
                        const SizedBox(width: 4),
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1565C0),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$_filterCount',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            itemCount: results.length,
            itemBuilder: (_, i) =>
                _SearchResultCard(shop: results[i], query: _query),
          ),
        ),
      ],
    );
  }

  // ── No results ────────────────────────────────────────────────────────────
  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded,
                size: 40, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No results found',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827)),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find shops matching "${_query.trim()}".\nTry a different search or adjust your filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing mic — small, shown inside the search field while listening
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingMic extends StatefulWidget {
  const _PulsingMic();

  @override
  State<_PulsingMic> createState() => _PulsingMicState();
}

class _PulsingMicState extends State<_PulsingMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: const Icon(Icons.mic_rounded, color: Color(0xFFEF4444), size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated listening mic — large, shown in the bottom overlay
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedListeningMic extends StatefulWidget {
  const _AnimatedListeningMic();

  @override
  State<_AnimatedListeningMic> createState() => _AnimatedListeningMicState();
}

class _AnimatedListeningMicState extends State<_AnimatedListeningMic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.25)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring
            Container(
              width: 88 * _pulse.value,
              height: 88 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1565C0).withOpacity(0.08),
              ),
            ),
            // Middle ring
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1565C0).withOpacity(0.15),
              ),
            ),
            // Core
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1565C0),
              ),
              child: const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 28),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent search row
// ─────────────────────────────────────────────────────────────────────────────

class _RecentRow extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  const _RecentRow({required this.text, required this.onTap, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF374151))),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded,
                      size: 16, color: Color(0xFF9CA3AF)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search result card
// ─────────────────────────────────────────────────────────────────────────────

class _SearchResultCard extends StatefulWidget {
  final ShopItem shop;
  final String query;
  const _SearchResultCard({required this.shop, required this.query});

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard> {
  bool _isFav = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.shop;
    return GestureDetector(
      onTap: () => context.push('/shop-detail', extra: s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 110,
                height: 110,
                child: s.imageData != null && s.imageData!.isNotEmpty
                    ? Image.memory(
                        base64Decode(s.imageData!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: s.fallbackColor,
                          alignment: Alignment.center,
                          child: Icon(s.fallbackIcon,
                              color: const Color(0xFF9CA3AF), size: 40),
                        ),
                      )
                    : Container(
                        color: s.fallbackColor,
                        alignment: Alignment.center,
                        child: Icon(s.fallbackIcon,
                            color: const Color(0xFF9CA3AF), size: 40),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _HighlightText(
                            text: s.name,
                            query: widget.query,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827)),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _isFav = !_isFav),
                          child: Icon(
                            _isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: _isFav
                                ? Colors.redAccent
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 12, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(s.location,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF6B7280)),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${s.discount}% OFF on eligible purchases',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1565C0),
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 11, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 3),
                              Text(
                                s.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (s.hasRewards)
                          _SmallChip(
                              label: 'Rewards',
                              color: const Color(0xFF10B981))
                        else if (s.hasRedeem)
                          _SmallChip(
                              label: 'Redeem',
                              color: const Color(0xFF1565C0)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SmallChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// Highlight the matched query text inside a result name
class _HighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  const _HighlightText(
      {required this.text, required this.query, required this.style});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx == -1) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: style.copyWith(
              color: const Color(0xFF1565C0),
              backgroundColor: const Color(0xFFDBEAFE),
            ),
          ),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
    );
  }
}
