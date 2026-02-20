import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/currency_service.dart';

class DeliverySettingsScreen extends StatefulWidget {
  final String? accountId;
  const DeliverySettingsScreen({super.key, this.accountId});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _cities = [];
  bool _isLoadingZones = false;
  bool _isLoadingCities = false;

  String? _selectedZoneId;
  String? _selectedCityId;

  final Map<String, String> _zoneNamesById = {};
  final Map<String, String> _cityNamesById = {};
  final Map<String, String> _cityZoneById = {};

  final TextEditingController _priceLbpController = TextEditingController();
  final TextEditingController _priceUsdController = TextEditingController();

  bool _isSaving = false;
  double? _usdRate;
  bool _isUpdatingConversion = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
    _loadAllZonesAndCities();
    // Do not auto-fill fields on page entry; keep controllers empty.
  }

  Future<void> _loadAllZonesAndCities() async {
    try {
      final zResp = await _supabase.from('zones').select('id, name_en');
      if (zResp != null) {
        for (var z in (zResp as List)) {
          final row = z as Map<String, dynamic>;
          final id = row['id'] as String?;
          final name = row['name_en'] as String?;
          if (id != null && name != null) _zoneNamesById[id] = name;
        }
      }

      final cResp = await _supabase
          .from('cities')
          .select('id, name_en, zone_id');
      if (cResp != null) {
        for (var c in (cResp as List)) {
          final row = c as Map<String, dynamic>;
          final id = row['id'] as String?;
          final name = row['name_en'] as String?;
          final zoneId = row['zone_id'] as String?;
          if (id != null && name != null) _cityNamesById[id] = name;
          if (id != null && zoneId != null) _cityZoneById[id] = zoneId;
        }
      }
    } catch (e) {
      debugPrint('Error loading all zones/cities: $e');
    }
  }

  @override
  void dispose() {
    _priceLbpController.dispose();
    _priceUsdController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    setState(() => _isLoadingZones = true);
    try {
      final resp = await _supabase
          .from('zones')
          .select('id, name_en')
          .order('name_en');
      if (resp != null) {
        _zones = List<Map<String, dynamic>>.from(resp as List);
      }
    } catch (e) {
      debugPrint('Error loading zones: $e');
    } finally {
      if (mounted) setState(() => _isLoadingZones = false);
    }
  }

  Future<void> _loadCitiesForZone(String zoneId) async {
    setState(() => _isLoadingCities = true);
    try {
      final resp = await _supabase
          .from('cities')
          .select('id, name_en, zone_id')
          .eq('zone_id', zoneId)
          .order('name_en');
      if (resp != null) {
        _cities = List<Map<String, dynamic>>.from(resp as List);
      }
    } catch (e) {
      debugPrint('Error loading cities: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _loadExistingPricing() async {
    // Called at init to prefill when account has a single existing rate
    if (widget.accountId == null) return;

    try {
      final cityResp = await _supabase
          .from('store_delivery_city_pricing')
          .select('id, city_id, price_lbp, price_usd, is_available')
          .eq('account_id', widget.accountId)
          .limit(1);

      if (cityResp != null && (cityResp as List).isNotEmpty) {
        final row = (cityResp as List).first as Map<String, dynamic>;
        setState(() {
          _selectedCityId = row['city_id'] as String?;
          _priceLbpController.text = (row['price_lbp'] ?? '').toString();
          _priceUsdController.text = (row['price_usd'] ?? '').toString();
        });
        if (_selectedCityId != null) {
          // load cities for zone if we can derive zone from city
          try {
            final cityInfo = await _supabase
                .from('cities')
                .select('zone_id')
                .eq('id', _selectedCityId)
                .maybeSingle();
            if (cityInfo != null && cityInfo['zone_id'] != null) {
              _selectedZoneId = cityInfo['zone_id'] as String?;
              await _loadCitiesForZone(_selectedZoneId!);
            }
          } catch (_) {}
        }
        return;
      }

      final zoneResp = await _supabase
          .from('store_delivery_zone_pricing')
          .select('id, zone_id, price_lbp, price_usd, is_available')
          .eq('account_id', widget.accountId)
          .limit(1);

      if (zoneResp != null && (zoneResp as List).isNotEmpty) {
        final row = (zoneResp as List).first as Map<String, dynamic>;
        setState(() {
          _selectedZoneId = row['zone_id'] as String?;
          _selectedCityId = null;
          _priceLbpController.text = (row['price_lbp'] ?? '').toString();
          _priceUsdController.text = (row['price_usd'] ?? '').toString();
        });
        if (_selectedZoneId != null) await _loadCitiesForZone(_selectedZoneId!);
      }
    } catch (e) {
      debugPrint('Error loading existing pricing: $e');
    }
  }

  Future<void> _savePricing() async {
    if (widget.accountId == null) return;
    final lbp = double.tryParse(_priceLbpController.text) ?? 0.0;
    final usd = double.tryParse(_priceUsdController.text) ?? 0.0;

    if ((_selectedZoneId == null || _selectedZoneId!.isEmpty) &&
        (_selectedCityId == null || _selectedCityId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a zone or city')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_selectedCityId != null && _selectedCityId!.isNotEmpty) {
        final payload = {
          'account_id': widget.accountId,
          'city_id': _selectedCityId,
          'price_lbp': lbp,
          'price_usd': usd,
          'is_available': true,
        };
        await _supabase
            .from('store_delivery_city_pricing')
            .upsert(payload, onConflict: 'account_id,city_id')
            .select()
            .maybeSingle();
      } else {
        final payload = {
          'account_id': widget.accountId,
          'zone_id': _selectedZoneId,
          'price_lbp': lbp,
          'price_usd': usd,
          'is_available': true,
        };
        await _supabase
            .from('store_delivery_zone_pricing')
            .upsert(payload, onConflict: 'account_id,zone_id')
            .select()
            .maybeSingle();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery pricing saved'),
            backgroundColor: Colors.green,
          ),
        );
        // Clear input fields and selections after successful save
        setState(() {
          _selectedZoneId = null;
          _selectedCityId = null;
          _cities = [];
          _priceLbpController.clear();
          _priceUsdController.clear();
        });
      }
    } catch (e) {
      debugPrint('Error saving pricing: $e');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save pricing: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configure delivery pricing per zone and city',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select Zone',
                border: OutlineInputBorder(),
              ),
              items: _zones
                  .map(
                    (z) => DropdownMenuItem(
                      value: z['id'] as String,
                      child: Text(z['name_en'] ?? ''),
                    ),
                  )
                  .toList(),
              value: _selectedZoneId,
              onChanged: (v) async {
                setState(() {
                  _selectedZoneId = v;
                  _selectedCityId = null;
                  _cities = [];
                });
                if (v != null && v.isNotEmpty) await _loadCitiesForZone(v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Select City (optional)',
                border: OutlineInputBorder(),
              ),
              items: _cities
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text(c['name_en'] ?? ''),
                    ),
                  )
                  .toList(),
              value: _selectedCityId,
              onChanged: (_selectedZoneId == null)
                  ? null
                  : (v) => setState(() => _selectedCityId = v),
            ),
            const SizedBox(height: 12),
            
            TextField(
              controller: _priceUsdController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price in USD',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) async {
                if (_isUpdatingConversion) return;
                _isUpdatingConversion = true;
                try {
                  final usd = double.tryParse(val) ?? 0.0;
                  if (_usdRate == null) {
                    try {
                      _usdRate = await CurrencyService.getUsdRate();
                    } catch (_) {}
                  }
                  if (_usdRate != null && usd > 0) {
                    final lbp = (usd * _usdRate!).round();
                    _priceLbpController.text = lbp.toString();
                  } else if (usd == 0) {
                    _priceLbpController.text = '';
                  }
                } catch (_) {}
                _isUpdatingConversion = false;
              },
            ),

            const SizedBox(height: 12),
            TextField(
              controller: _priceLbpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price in LBP',
                border: OutlineInputBorder(),
              ),
              onChanged: (val) async {
                if (_isUpdatingConversion) return;
                _isUpdatingConversion = true;
                try {
                  final raw = val.replaceAll(',', '');
                  final lbp = double.tryParse(raw) ?? 0.0;
                  if (_usdRate == null) {
                    try {
                      _usdRate = await CurrencyService.getUsdRate();
                    } catch (_) {}
                  }
                  if (_usdRate != null && lbp > 0) {
                    final usd = lbp / _usdRate!;
                    _priceUsdController.text = usd.toStringAsFixed(2);
                  } else if (lbp == 0) {
                    _priceUsdController.text = '';
                  }
                } catch (_) {}
                _isUpdatingConversion = false;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _savePricing,
                    child: _isSaving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Existing pricing (for this account):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder(
                future: _fetchPricingList(),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done)
                    return const Center(child: CircularProgressIndicator());
                  final items = snap.data as List<Map<String, dynamic>>;
                  if (items.isEmpty)
                    return const Text('No pricing defined yet.');
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final it = items[idx];
                      return ListTile(
                        title: Text(it['label'] as String? ?? ''),
                        subtitle: Text(
                          '${it['price_lbp']?.toString() ?? '0'} LBP — ${it['price_usd']?.toString() ?? '0'} USD',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            setState(() {
                              _selectedCityId = it['city_id'] as String?;
                              _priceLbpController.text = (it['price_lbp'] ?? '')
                                  .toString();
                              _priceUsdController.text = (it['price_usd'] ?? '')
                                  .toString();
                            });
                            if (_selectedCityId != null) {
                              try {
                                final cityInfo = await _supabase
                                    .from('cities')
                                    .select('zone_id')
                                    .eq('id', _selectedCityId)
                                    .maybeSingle();
                                if (cityInfo != null &&
                                    cityInfo['zone_id'] != null) {
                                  _selectedZoneId =
                                      cityInfo['zone_id'] as String?;
                                  await _loadCitiesForZone(_selectedZoneId!);
                                }
                              } catch (_) {}
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchPricingList() async {
    if (widget.accountId == null) return [];
    try {
      final cityResp = await _supabase
          .from('store_delivery_city_pricing')
          .select('city_id, price_lbp, price_usd')
          .eq('account_id', widget.accountId);
      final zoneResp = await _supabase
          .from('store_delivery_zone_pricing')
          .select('zone_id, price_lbp, price_usd')
          .eq('account_id', widget.accountId);

      final List<Map<String, dynamic>> list = [];
      if (cityResp != null) {
        for (var r in (cityResp as List)) {
          final row = r as Map<String, dynamic>;
          final cityId = row['city_id'] as String?;
          final cityName = cityId != null
              ? (_cityNamesById[cityId] ?? cityId)
              : null;
          final zoneId = cityId != null ? _cityZoneById[cityId] : null;
          final zoneName = zoneId != null
              ? (_zoneNamesById[zoneId] ?? zoneId)
              : null;
          final label = (zoneName != null && cityName != null)
              ? '$zoneName, $cityName'
              : (cityName ?? 'City');
          list.add({
            'label': label,
            'zone_id': zoneId,
            'city_id': cityId,
            'price_lbp': row['price_lbp'],
            'price_usd': row['price_usd'],
          });
        }
      }
      if (zoneResp != null) {
        for (var r in (zoneResp as List)) {
          final row = r as Map<String, dynamic>;
          final zid = row['zone_id'] as String?;
          final zname = zid != null ? (_zoneNamesById[zid] ?? zid) : 'Zone';
          list.add({
            'label': zname,
            'zone_id': zid,
            'city_id': null,
            'price_lbp': row['price_lbp'],
            'price_usd': row['price_usd'],
          });
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error fetching pricing list: $e');
      return [];
    }
  }
}
