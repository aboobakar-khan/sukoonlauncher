import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/hadith_dua_models.dart';

/// Service for fetching Hadith and Dua from APIs
class HadithDuaService {
  // Primary and fallback API URLs
  static const String _primaryUrl = 'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1';
  static const String _fallbackUrl = 'https://raw.githubusercontent.com/fawazahmed0/hadith-api/1';
  
  // Cache for loaded collections
  final Map<String, List<Hadith>> _hadithCache = {};
  final Map<String, Map<String, String>> _sectionsCache = {};
  
  /// Fetch from primary URL with fallback
  Future<http.Response?> _fetchWithFallback(String path) async {
    try {
      final response = await http.get(
        Uri.parse('$_primaryUrl$path'),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      // Primary failed, try fallback
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_fallbackUrl$path'),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      // Both failed
    }
    
    return null;
  }

  /// Fetch hadiths from a specific collection
  Future<List<Hadith>> fetchHadiths(HadithCollection collection) async {
    // Return cached if available
    if (_hadithCache.containsKey(collection.id)) {
      return _hadithCache[collection.id]!;
    }

    try {
      // Use minified version for faster loading
      final response = await _fetchWithFallback('/editions/${collection.apiKey}.min.json');
      
      if (response != null) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Get sections for reference
        final metadata = data['metadata'] as Map<String, dynamic>?;
        final sections = metadata?['section'] as Map<String, dynamic>? ?? {};
        _sectionsCache[collection.id] = sections.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        
        // Parse hadiths with enhanced data
        final hadithsData = data['hadiths'] as List<dynamic>? ?? [];
        final hadiths = <Hadith>[];
        
        for (final h in hadithsData) {
          try {
            var hadith = Hadith.fromJson(
              h as Map<String, dynamic>,
              collection: collection.name,
              section: _getSectionForHadith(collection.id, h['hadithnumber'] as int? ?? 0),
              sectionDetails: _sectionsCache[collection.id],
            );
            
            // Apply default grade for sahih collections if not graded
            if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
              hadith = hadith.copyWith(grade: collection.defaultGrade);
            }
            
            hadiths.add(hadith);
          } catch (e) {
            // Skip malformed hadith
            continue;
          }
        }

        _hadithCache[collection.id] = hadiths;
        return hadiths;
      }
    } catch (e) {
      // Return empty on error
    }
    return [];
  }

  /// Download hadiths for offline storage - ALWAYS fetches fresh from API
  /// This bypasses the in-memory cache to ensure we get the actual data
  Future<List<Hadith>> downloadHadithsForOffline(HadithCollection collection, {Function(int, int)? onProgress}) async {
    print('HadithDuaService: Starting FRESH download for ${collection.name}...');
    
    try {
      final url = '/editions/${collection.apiKey}.min.json';
      print('HadithDuaService: Fetching from $url');
      
      final response = await _fetchWithFallback(url);
      
      if (response == null) {
        print('HadithDuaService: Failed to fetch ${collection.name} - no response');
        return [];
      }
      
      print('HadithDuaService: Got response for ${collection.name}, parsing...');
      final data = json.decode(response.body) as Map<String, dynamic>;
      
      // Get sections for reference
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final sections = metadata?['section'] as Map<String, dynamic>? ?? {};
      _sectionsCache[collection.id] = sections.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      
      // Parse hadiths with enhanced data
      final hadithsData = data['hadiths'] as List<dynamic>? ?? [];
      final hadiths = <Hadith>[];
      
      print('HadithDuaService: Parsing ${hadithsData.length} hadiths from ${collection.name}...');
      
      for (int i = 0; i < hadithsData.length; i++) {
        final h = hadithsData[i];
        try {
          var hadith = Hadith.fromJson(
            h as Map<String, dynamic>,
            collection: collection.name,
            section: _getSectionForHadith(collection.id, h['hadithnumber'] as int? ?? 0),
            sectionDetails: _sectionsCache[collection.id],
          );
          
          // Apply default grade for sahih collections if not graded
          if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
            hadith = hadith.copyWith(grade: collection.defaultGrade);
          }
          
          hadiths.add(hadith);
          
          // Report progress every 500 hadiths
          if (onProgress != null && i % 500 == 0) {
            onProgress(i, hadithsData.length);
          }
        } catch (e) {
          // Skip malformed hadith
          continue;
        }
      }

      // Also update in-memory cache
      _hadithCache[collection.id] = hadiths;
      
      print('HadithDuaService: ✓ Downloaded ${hadiths.length} hadiths from ${collection.name}');
      return hadiths;
    } catch (e) {
      print('HadithDuaService: Error downloading ${collection.name}: $e');
      return [];
    }
  }

  /// Fetch a specific range of hadiths (for faster loading)
  Future<List<Hadith>> fetchHadithsRange(HadithCollection collection, int start, int end) async {
    final hadiths = <Hadith>[];
    
    for (int i = start; i <= end; i++) {
      try {
        final response = await _fetchWithFallback('/editions/${collection.apiKey}/$i.min.json');
        
        if (response != null) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final hadithsData = data['hadiths'] as List<dynamic>? ?? [];
          
          for (final h in hadithsData) {
            try {
              var hadith = Hadith.fromJson(
                h as Map<String, dynamic>,
                collection: collection.name,
              );
              
              if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
                hadith = hadith.copyWith(grade: collection.defaultGrade);
              }
              
              hadiths.add(hadith);
            } catch (e) {
              continue;
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    return hadiths;
  }

  /// Fetch a few random sections for quick loading
  Future<List<Hadith>> fetchRandomSections(HadithCollection collection, {int sections = 3}) async {
    final hadiths = <Hadith>[];
    final random = Random();
    final maxSection = _getMaxSection(collection.id);
    final fetchedSections = <int>{};
    
    while (fetchedSections.length < sections) {
      final section = random.nextInt(maxSection) + 1;
      if (fetchedSections.contains(section)) continue;
      fetchedSections.add(section);
      
      try {
        final response = await _fetchWithFallback('/editions/${collection.apiKey}/$section.min.json');
        
        if (response != null) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final hadithsData = data['hadiths'] as List<dynamic>? ?? [];
          
          for (final h in hadithsData) {
            try {
              var hadith = Hadith.fromJson(
                h as Map<String, dynamic>,
                collection: collection.name,
              );
              
              if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
                hadith = hadith.copyWith(grade: collection.defaultGrade);
              }
              
              hadiths.add(hadith);
            } catch (e) {
              continue;
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    return hadiths;
  }

  int _getMaxSection(String collectionId) {
    switch (collectionId) {
      case 'bukhari': return 97;
      case 'muslim': return 56;
      case 'abudawud': return 43;
      case 'tirmidhi': return 49;
      case 'nasai': return 51;
      case 'ibnmajah': return 37;
      default: return 30;
    }
  }

  String? _getSectionForHadith(String collectionId, int hadithNumber) {
    final sections = _sectionsCache[collectionId];
    if (sections == null) return null;
    
    // Find the section this hadith belongs to
    if (sections.isNotEmpty) {
      return sections.values.first; // Return first section name for now
    }
    return null;
  }

  /// Get a random hadith from a collection
  Future<Hadith?> getRandomHadith({String? collectionId}) async {
    final collection = collectionId != null
        ? HadithCollection.fromId(collectionId)
        : HadithCollection.collections[Random().nextInt(HadithCollection.collections.length)];

    // Try to get from cache first
    if (_hadithCache.containsKey(collection.id) && _hadithCache[collection.id]!.isNotEmpty) {
      final hadiths = _hadithCache[collection.id]!;
      return hadiths[Random().nextInt(hadiths.length)];
    }

    // Fetch a random section
    final random = Random();
    final section = random.nextInt(_getMaxSection(collection.id)) + 1;
    
    try {
      final response = await _fetchWithFallback('/editions/${collection.apiKey}/$section.min.json');
      
      if (response != null) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final hadithsData = data['hadiths'] as List<dynamic>? ?? [];
        
        if (hadithsData.isNotEmpty) {
          final randomIndex = random.nextInt(hadithsData.length);
          var hadith = Hadith.fromJson(
            hadithsData[randomIndex] as Map<String, dynamic>,
            collection: collection.name,
          );
          
          if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
            hadith = hadith.copyWith(grade: collection.defaultGrade);
          }
          
          return hadith;
        }
      }
    } catch (e) {
      // Return null on error
    }
    
    return null;
  }

  /// Get multiple random hadiths for the "Load More" feature
  Future<List<Hadith>> getMultipleRandomHadiths({
    String? collectionId,
    int count = 5,
    List<int>? excludeNumbers,
  }) async {
    final results = <Hadith>[];
    final collection = collectionId != null
        ? HadithCollection.fromId(collectionId)
        : HadithCollection.collections[Random().nextInt(HadithCollection.collections.length)];

    // Fetch from multiple random sections
    final random = Random();
    final fetchedSections = <int>{};
    int attempts = 0;
    
    while (results.length < count && attempts < 10) {
      attempts++;
      final section = random.nextInt(_getMaxSection(collection.id)) + 1;
      if (fetchedSections.contains(section)) continue;
      fetchedSections.add(section);
      
      try {
        final response = await _fetchWithFallback('/editions/${collection.apiKey}/$section.min.json');
        
        if (response != null) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final hadithsData = data['hadiths'] as List<dynamic>? ?? [];
          
          for (final h in hadithsData) {
            if (results.length >= count) break;
            
            try {
              final hadithNum = h['hadithnumber'] as int? ?? 0;
              if (excludeNumbers?.contains(hadithNum) ?? false) continue;
              
              var hadith = Hadith.fromJson(
                h as Map<String, dynamic>,
                collection: collection.name,
              );
              
              if (hadith.grade == HadithGrade.unknown && collection.defaultGrade != HadithGrade.unknown) {
                hadith = hadith.copyWith(grade: collection.defaultGrade);
              }
              
              results.add(hadith);
            } catch (e) {
              continue;
            }
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    return results;
  }

  /// Get hadiths by category
  Future<List<Hadith>> getHadithsByCategory({
    required HadithCategory category,
    String? collectionId,
    int limit = 20,
  }) async {
    final collections = collectionId != null
        ? [HadithCollection.fromId(collectionId)]
        : HadithCollection.collections;

    final results = <Hadith>[];

    for (final collection in collections) {
      final hadiths = await fetchHadiths(collection);
      results.addAll(
        hadiths.where((h) => h.categories.contains(category)),
      );
      if (results.length >= limit) break;
    }

    return results.take(limit).toList();
  }

  /// Search hadiths by text with optional filters
  Future<List<Hadith>> searchHadiths(
    String query, {
    String? collectionId,
    HadithGrade? gradeFilter,
    HadithCategory? categoryFilter,
  }) async {
    final collections = collectionId != null
        ? [HadithCollection.fromId(collectionId)]
        : HadithCollection.collections;

    final results = <Hadith>[];
    final queryLower = query.toLowerCase();

    for (final collection in collections) {
      final hadiths = await fetchHadiths(collection);
      var filtered = hadiths.where((h) => h.text.toLowerCase().contains(queryLower));
      
      // Apply grade filter
      if (gradeFilter != null) {
        filtered = filtered.where((h) => h.grade == gradeFilter);
      }
      
      // Apply category filter
      if (categoryFilter != null) {
        filtered = filtered.where((h) => h.categories.contains(categoryFilter));
      }
      
      results.addAll(filtered);
      
      // Limit results
      if (results.length >= 50) break;
    }

    return results.take(50).toList();
  }

  /// Get curated duas (embedded since API might not be reliable)
  List<Dua> getCuratedDuas() {
    return _curatedDuas;
  }

  /// Get a random dua
  Dua getRandomDua() {
    return _curatedDuas[Random().nextInt(_curatedDuas.length)];
  }

  /// Search duas
  List<Dua> searchDuas(String query) {
    final queryLower = query.toLowerCase();
    return _curatedDuas.where((d) =>
      d.title.toLowerCase().contains(queryLower) ||
      d.translation.toLowerCase().contains(queryLower) ||
      d.transliteration.toLowerCase().contains(queryLower) ||
      (d.category?.toLowerCase().contains(queryLower) ?? false)
    ).toList();
  }

  // Curated collection of authentic duas
  static final List<Dua> _curatedDuas = [
    // Morning & Evening
    Dua(
      id: 'morning_1',
      title: 'Morning Remembrance',
      arabicText: 'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَٰهَ إِلَّا اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ',
      transliteration: "Asbahna wa asbahal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la shareeka lah",
      translation: "We have reached the morning and at this very time the whole kingdom belongs to Allah. All praise is due to Allah. None has the right to be worshipped except Allah alone, without any partner.",
      category: 'Morning & Evening',
      source: 'Muslim',
    ),
    Dua(
      id: 'evening_1',
      title: 'Evening Remembrance',
      arabicText: 'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لاَ إِلَٰهَ إِلَّا اللهُ وَحْدَهُ لاَ شَرِيكَ لَهُ',
      transliteration: "Amsayna wa amsal-mulku lillah, walhamdu lillah, la ilaha illallahu wahdahu la shareeka lah",
      translation: "We have reached the evening and at this very time the whole kingdom belongs to Allah. All praise is due to Allah. None has the right to be worshipped except Allah alone, without any partner.",
      category: 'Morning & Evening',
      source: 'Muslim',
    ),
    Dua(
      id: 'morning_protection',
      title: 'Seeking Protection (Morning)',
      arabicText: 'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
      transliteration: "Allahumma bika asbahna, wa bika amsayna, wa bika nahya, wa bika namootu, wa ilaykan-nushoor",
      translation: "O Allah, by You we enter the morning, by You we enter the evening, by You we live, by You we die, and to You is the resurrection.",
      category: 'Morning & Evening',
      source: 'Tirmidhi',
    ),
    
    // Protection
    Dua(
      id: 'protection_1',
      title: 'Seeking Refuge',
      arabicText: 'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
      transliteration: "A'udhu bikalimatillahit-tammati min sharri ma khalaq",
      translation: "I seek refuge in the perfect words of Allah from the evil of what He has created.",
      category: 'Protection',
      source: 'Muslim',
    ),
    Dua(
      id: 'protection_2',
      title: 'Protection from Evil',
      arabicText: 'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
      transliteration: "Bismillahil-ladhi la yadurru ma'as-mihi shay'un fil-ardi wa la fis-sama'i, wa Huwas-Sami'ul-'Alim",
      translation: "In the name of Allah, with whose name nothing in the earth or the sky can cause harm, and He is the All-Hearing, the All-Knowing.",
      category: 'Protection',
      source: 'Abu Dawud, Tirmidhi',
    ),
    
    // Before Sleep
    Dua(
      id: 'sleep_1',
      title: 'Before Sleeping',
      arabicText: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
      transliteration: "Bismika Allahumma amootu wa ahya",
      translation: "In Your name, O Allah, I die and I live.",
      category: 'Sleep',
      source: 'Bukhari',
    ),
    Dua(
      id: 'sleep_2',
      title: 'Sleeping Dua',
      arabicText: 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَأَحْيَا',
      transliteration: "Allahumma bismika amootu wa ahya",
      translation: "O Allah, in Your name I die and I live.",
      category: 'Sleep',
      source: 'Bukhari',
    ),
    Dua(
      id: 'wakeup_1',
      title: 'Upon Waking Up',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
      transliteration: "Alhamdu lillahil-ladhi ahyana ba'da ma amatana, wa ilayhin-nushoor",
      translation: "All praise is due to Allah, who gave us life after causing us to die, and unto Him is the resurrection.",
      category: 'Sleep',
      source: 'Bukhari',
    ),
    
    // Eating & Drinking
    Dua(
      id: 'eating_1',
      title: 'Before Eating',
      arabicText: 'بِسْمِ اللَّهِ',
      transliteration: "Bismillah",
      translation: "In the name of Allah.",
      category: 'Food & Drink',
      source: 'Abu Dawud, Tirmidhi',
    ),
    Dua(
      id: 'eating_2',
      title: 'After Eating',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلاَ قُوَّةٍ',
      transliteration: "Alhamdu lillahil-ladhi at'amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah",
      translation: "All praise is due to Allah who fed me this and provided it for me without any might or strength on my part.",
      category: 'Food & Drink',
      source: 'Abu Dawud, Tirmidhi',
    ),
    Dua(
      id: 'eating_3',
      title: 'When Forgetting Bismillah',
      arabicText: 'بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ',
      transliteration: "Bismillahi awwalahu wa akhirah",
      translation: "In the name of Allah at the beginning and at the end of it.",
      category: 'Food & Drink',
      source: 'Abu Dawud, Tirmidhi',
    ),
    Dua(
      id: 'drinking_1',
      title: 'After Drinking Water',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي سَقَانَا عَذْبًا فُرَاتًا بِرَحْمَتِهِ وَلَمْ يَجْعَلْهُ مِلْحًا أُجَاجًا بِذُنُوبِنَا',
      transliteration: "Alhamdu lillahil-ladhi saqana 'adhban furatan bi rahmatih, wa lam yaj'alhu milhan ujajan bi dhunubina",
      translation: "All praise is due to Allah who gave us sweet, fresh water by His mercy and did not make it salty and bitter due to our sins.",
      category: 'Food & Drink',
      source: 'Tabarani',
    ),
    
    // Travel
    Dua(
      id: 'travel_1',
      title: 'Starting a Journey',
      arabicText: 'سُبْحَانَ الَّذِي سَخَّرَ لَنَا هَٰذَا وَمَا كُنَّا لَهُ مُقْرِنِينَ وَإِنَّا إِلَىٰ رَبِّنَا لَمُنْقَلِبُونَ',
      transliteration: "Subhanal-ladhi sakhkhara lana hadha wama kunna lahu muqrinin, wa inna ila Rabbina lamunqaliboon",
      translation: "Glory be to Him who has subjected this for us, and we would not have been able to subdue it. And indeed, to our Lord we will return.",
      category: 'Travel',
      source: 'Muslim',
    ),
    Dua(
      id: 'travel_2',
      title: 'Returning from Travel',
      arabicText: 'آيِبُونَ تَائِبُونَ عَابِدُونَ لِرَبِّنَا حَامِدُونَ',
      transliteration: "Ayibuna, ta'ibuna, 'abiduna, li Rabbina hamidun",
      translation: "We return, repenting, worshipping, and praising our Lord.",
      category: 'Travel',
      source: 'Muslim',
    ),
    Dua(
      id: 'travel_3',
      title: 'Entering a Town or City',
      arabicText: 'اللَّهُمَّ رَبَّ السَّمَاوَاتِ السَّبْعِ وَمَا أَظْلَلْنَ، وَرَبَّ الْأَرَضِينَ السَّبْعِ وَمَا أَقْلَلْنَ، أَسْأَلُكَ خَيْرَ هَٰذِهِ الْقَرْيَةِ وَخَيْرَ أَهْلِهَا',
      transliteration: "Allahumma Rabbas-samawatis-sab'i wa ma azlalna, wa Rabbal-aradinas-sab'i wa ma aqlalna, as'aluka khayra hadhihil-qaryati wa khayra ahliha",
      translation: "O Allah, Lord of the seven heavens and all they shade, Lord of the seven earths and all they bear, I ask You for the good of this town and the good of its people.",
      category: 'Travel',
      source: 'Ibn Hibban',
    ),
    
    // Forgiveness
    Dua(
      id: 'forgiveness_1',
      title: 'Seeking Forgiveness (Sayyidul Istighfar)',
      arabicText: 'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَٰهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ بِذَنْبِي فَاغْفِرْ لِي فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
      transliteration: "Allahumma anta Rabbi, la ilaha illa anta, khalaqtani wa ana 'abduka, wa ana 'ala 'ahdika wa wa'dika mastata'tu, a'udhu bika min sharri ma sana'tu, abu'u laka bini'matika 'alayya, wa abu'u bidhanbi, faghfir li, fa innahu la yaghfirudh-dhunuba illa anta",
      translation: "O Allah, You are my Lord, there is no god but You. You created me and I am Your servant, and I hold to Your covenant and promise as much as I can. I seek refuge in You from the evil I have done. I acknowledge Your blessings upon me, and I acknowledge my sins. So forgive me, for none forgives sins but You.",
      category: 'Forgiveness',
      source: 'Bukhari',
    ),
    Dua(
      id: 'forgiveness_2',
      title: 'Simple Istighfar',
      arabicText: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
      transliteration: "Astaghfirullaha wa atubu ilayh",
      translation: "I seek the forgiveness of Allah and repent to Him.",
      category: 'Forgiveness',
      source: 'Bukhari, Muslim',
    ),
    
    // Anxiety & Distress
    Dua(
      id: 'anxiety_1',
      title: 'For Anxiety and Sorrow',
      arabicText: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْهَمِّ وَالْحَزَنِ، وَالْعَجْزِ وَالْكَسَلِ، وَالْبُخْلِ وَالْجُبْنِ، وَضَلَعِ الدَّيْنِ وَغَلَبَةِ الرِّجَالِ',
      transliteration: "Allahumma inni a'udhu bika minal-hammi wal-hazan, wal-'ajzi wal-kasal, wal-bukhli wal-jubn, wa dala'id-dayni wa ghalabatir-rijal",
      translation: "O Allah, I seek refuge in You from anxiety and grief, from weakness and laziness, from miserliness and cowardice, from being overwhelmed by debt and from being overpowered by men.",
      category: 'Distress',
      source: 'Bukhari',
    ),
    Dua(
      id: 'distress_1',
      title: 'In Times of Distress',
      arabicText: 'لَا إِلَٰهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَٰهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَٰهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ',
      transliteration: "La ilaha illallahul-'Azimul-Halim, la ilaha illallahu Rabbul-'Arshil-'Azim, la ilaha illallahu Rabbus-samawati wa Rabbul-ardi wa Rabbul-'Arshil-Karim",
      translation: "There is no god but Allah, the Mighty, the Forbearing. There is no god but Allah, Lord of the Magnificent Throne. There is no god but Allah, Lord of the heavens and Lord of the earth, and Lord of the Noble Throne.",
      category: 'Distress',
      source: 'Bukhari, Muslim',
    ),
    
    // Guidance
    Dua(
      id: 'guidance_1',
      title: 'For Guidance',
      arabicText: 'اللَّهُمَّ اهْدِنِي وَسَدِّدْنِي',
      transliteration: "Allahumma'hdini wa saddidni",
      translation: "O Allah, guide me and keep me on the right path.",
      category: 'Guidance',
      source: 'Muslim',
    ),
    Dua(
      id: 'guidance_2',
      title: 'Istikhara (Seeking Guidance)',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْتَخِيرُكَ بِعِلْمِكَ، وَأَسْتَقْدِرُكَ بِقُدْرَتِكَ، وَأَسْأَلُكَ مِنْ فَضْلِكَ الْعَظِيمِ',
      transliteration: "Allahumma inni astakhiruka bi'ilmika, wa astaqdiruka biqudratika, wa as'aluka min fadlikal-'azim",
      translation: "O Allah, I seek Your guidance by virtue of Your knowledge, and I seek ability by virtue of Your power, and I ask You of Your great bounty.",
      category: 'Guidance',
      source: 'Bukhari',
    ),
    
    // Gratitude
    Dua(
      id: 'gratitude_1',
      title: 'Expressing Gratitude',
      arabicText: 'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ',
      transliteration: "Allahumma a'inni 'ala dhikrika wa shukrika wa husni 'ibadatik",
      translation: "O Allah, help me to remember You, to thank You, and to worship You well.",
      category: 'Gratitude',
      source: 'Abu Dawud, Nasai',
    ),
    Dua(
      id: 'gratitude_2',
      title: 'When Seeing Someone in Trial',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي مِمَّا ابْتَلَاكَ بِهِ، وَفَضَّلَنِي عَلَى كَثِيرٍ مِمَّنْ خَلَقَ تَفْضِيلًا',
      transliteration: "Alhamdu lillahil-ladhi 'afani mimmabtilaka bihi, wa faddalani 'ala kathirin mimman khalaqa tafdila",
      translation: "All praise is due to Allah who has saved me from what He has tested you with, and has favored me greatly over many of His creation.",
      category: 'Gratitude',
      source: 'Tirmidhi',
    ),
    Dua(
      id: 'gratitude_3',
      title: 'Upon Receiving Good News',
      arabicText: 'الْحَمْدُ لِلَّهِ الَّذِي بِنِعْمَتِهِ تَتِمُّ الصَّالِحَاتُ',
      transliteration: "Alhamdu lillahil-ladhi bi ni'matihi tatimmus-salihat",
      translation: "All praise is due to Allah by whose blessing all good things are completed.",
      category: 'Gratitude',
      source: 'Ibn Majah',
    ),
    
    // Health
    Dua(
      id: 'health_1',
      title: 'For Good Health',
      arabicText: 'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي',
      transliteration: "Allahumma 'afini fi badani, Allahumma 'afini fi sam'i, Allahumma 'afini fi basari",
      translation: "O Allah, grant me health in my body. O Allah, grant me health in my hearing. O Allah, grant me health in my sight.",
      category: 'Health',
      source: 'Abu Dawud',
    ),
    Dua(
      id: 'health_2',
      title: 'For Healing',
      arabicText: 'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا',
      transliteration: "Allahumma Rabban-nas, adhibil-ba's, ishfi antash-Shafi, la shifa'a illa shifa'uka, shifa'an la yughadiru saqama",
      translation: "O Allah, Lord of mankind, remove the illness. Cure it, for You are the Healer. There is no cure except Your cure — a cure that leaves no illness behind.",
      category: 'Health',
      source: 'Bukhari, Muslim',
    ),
    Dua(
      id: 'health_3',
      title: 'Visiting the Sick',
      arabicText: 'لَا بَأْسَ طَهُورٌ إِنْ شَاءَ اللَّهُ',
      transliteration: "La ba'sa, tahoorun in sha Allah",
      translation: "No worry, it is a purification, if Allah wills.",
      category: 'Health',
      source: 'Bukhari',
    ),
    
    // Knowledge
    Dua(
      id: 'knowledge_1',
      title: 'Seeking Beneficial Knowledge',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا',
      transliteration: "Allahumma inni as'aluka 'ilman nafi'an, wa rizqan tayyiban, wa 'amalan mutaqabbalan",
      translation: "O Allah, I ask You for beneficial knowledge, goodly provision, and accepted deeds.",
      category: 'Knowledge',
      source: 'Ibn Majah',
    ),
    Dua(
      id: 'knowledge_2',
      title: 'Increase in Knowledge',
      arabicText: 'رَبِّ زِدْنِي عِلْمًا',
      transliteration: "Rabbi zidni 'ilma",
      translation: "My Lord, increase me in knowledge.",
      category: 'Knowledge',
      source: 'Quran 20:114',
    ),
    Dua(
      id: 'knowledge_3',
      title: 'Before Studying',
      arabicText: 'اللَّهُمَّ انْفَعْنِي بِمَا عَلَّمْتَنِي، وَعَلِّمْنِي مَا يَنْفَعُنِي، وَزِدْنِي عِلْمًا',
      transliteration: "Allahumma-nfa'ni bima 'allamtani, wa 'allimni ma yanfa'uni, wa zidni 'ilma",
      translation: "O Allah, benefit me with what You have taught me, teach me that which will benefit me, and increase me in knowledge.",
      category: 'Knowledge',
      source: 'Tirmidhi',
    ),
    
    // Parents
    Dua(
      id: 'parents_1',
      title: 'For Parents',
      arabicText: 'رَبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
      transliteration: "Rabbir-hamhuma kama rabbayani saghira",
      translation: "My Lord, have mercy upon them as they brought me up when I was small.",
      category: 'Family',
      source: 'Quran 17:24',
    ),
    Dua(
      id: 'family_2',
      title: 'For Spouse and Children',
      arabicText: 'رَبَّنَا هَبْ لَنَا مِنْ أَزْوَاجِنَا وَذُرِّيَّاتِنَا قُرَّةَ أَعْيُنٍ وَاجْعَلْنَا لِلْمُتَّقِينَ إِمَامًا',
      transliteration: "Rabbana hab lana min azwajina wa dhurriyyatina qurrata a'yunin waj'alna lil-muttaqina imama",
      translation: "Our Lord, grant us from our spouses and offspring comfort to our eyes, and make us leaders for the righteous.",
      category: 'Family',
      source: 'Quran 25:74',
    ),
    Dua(
      id: 'family_3',
      title: 'For Righteous Offspring',
      arabicText: 'رَبِّ هَبْ لِي مِنَ الصَّالِحِينَ',
      transliteration: "Rabbi hab li minas-salihin",
      translation: "My Lord, grant me righteous offspring.",
      category: 'Family',
      source: 'Quran 37:100',
    ),
    
    // General
    Dua(
      id: 'general_1',
      title: 'Comprehensive Dua',
      arabicText: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
      transliteration: "Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan waqina 'adhaban-nar",
      translation: "Our Lord, give us good in this world and in the Hereafter, and protect us from the punishment of the Fire.",
      category: 'General',
      source: 'Quran 2:201',
    ),
    Dua(
      id: 'general_2',
      title: 'For All Good',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنَ الْخَيْرِ كُلِّهِ عَاجِلِهِ وَآجِلِهِ، مَا عَلِمْتُ مِنْهُ وَمَا لَمْ أَعْلَمْ',
      transliteration: "Allahumma inni as'aluka minal-khayri kullihi, 'ajilihi wa ajilihi, ma 'alimtu minhu wa ma lam a'lam",
      translation: "O Allah, I ask You for all that is good, in this world and in the Hereafter, what I know and what I do not know.",
      category: 'General',
      source: 'Ibn Majah',
    ),
    Dua(
      id: 'general_3',
      title: 'For Steadfastness',
      arabicText: 'يَا مُقَلِّبَ الْقُلُوبِ ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
      transliteration: "Ya Muqallibal-qulub, thabbit qalbi 'ala dinik",
      translation: "O Turner of the hearts, make my heart firm upon Your religion.",
      category: 'General',
      source: 'Tirmidhi',
    ),
    Dua(
      id: 'general_4',
      title: 'Entering the Masjid',
      arabicText: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
      transliteration: "Allahumma-ftah li abwaba rahmatik",
      translation: "O Allah, open for me the doors of Your mercy.",
      category: 'General',
      source: 'Muslim',
    ),
    Dua(
      id: 'general_5',
      title: 'Leaving the Masjid',
      arabicText: 'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ',
      transliteration: "Allahumma inni as'aluka min fadlik",
      translation: "O Allah, I ask You from Your bounty.",
      category: 'General',
      source: 'Muslim',
    ),
  ];
}
