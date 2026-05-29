import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // v0.4.0-alpha2 startup guard:
  // Background audio is an integration layer. If the native service init hangs
  // or throws on a specific Android ROM, the app must still open normally.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.rakyzu.musicplayer.channel.audio',
      androidNotificationChannelName: 'Rakyzu Music Playback',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    ).timeout(const Duration(seconds: 4));
  } catch (_) {
    // Keep foreground playback alive; we will refine notification service in beta.
  }

  runApp(const RakyzuApp());
}

class RakyzuApp extends StatelessWidget {
  const RakyzuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rakyzu Music Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF08080C),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD6A84F),
          brightness: Brightness.dark,
        ),
      ),
      home: const MusicHomePage(),
    );
  }
}

enum SortMode {
  title,
  artist,
  album,
  durationShort,
  durationLong,
}

enum RepeatMode {
  off,
  one,
  all,
}

enum LibraryViewMode {
  all,
  favorites,
  recent,
}

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final Random _random = Random();

  final List<SongModel> _rawSongs = <SongModel>[];
  final List<SongModel> _songs = <SongModel>[];

  StreamSubscription<PlayerState>? _playerStateSub;
  SharedPreferences? _prefs;

  bool _loading = true;
  bool _permissionGranted = false;
  bool _hideNoise = true;
  bool _removeDuplicates = true;
  bool _shuffle = false;

  int _currentIndex = -1;
  int _hiddenCount = 0;

  String _search = '';

  SortMode _sortMode = SortMode.title;
  RepeatMode _repeatMode = RepeatMode.off;
  LibraryViewMode _viewMode = LibraryViewMode.all;

  Set<int> _favoriteIds = <int>{};
  List<int> _recentIds = <int>[];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleCompleted();
      }
    });
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

    await _loadPrefs();

    bool granted = await _audioQuery.permissionsStatus();
    if (!granted) {
      granted = await _audioQuery.permissionsRequest();
    }

    if (!mounted) return;

    if (!granted) {
      setState(() {
        _permissionGranted = false;
        _loading = false;
      });
      return;
    }

    final songs = await _audioQuery.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    if (!mounted) return;

    setState(() {
      _permissionGranted = true;
      _rawSongs
        ..clear()
        ..addAll(songs);
      _recentIds = _recentIds.where((id) => _rawSongs.any((song) => song.id == id)).toList();
      _favoriteIds = _favoriteIds.where((id) => _rawSongs.any((song) => song.id == id)).toSet();
      _rebuildLibrary(preserveCurrent: true);
      _loading = false;
    });

    await _savePrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    _hideNoise = prefs.getBool('hideNoise') ?? true;
    _removeDuplicates = prefs.getBool('removeDuplicates') ?? true;
    _shuffle = prefs.getBool('shuffle') ?? false;

    _sortMode = _enumByName(SortMode.values, prefs.getString('sortMode')) ?? SortMode.title;
    _repeatMode = _enumByName(RepeatMode.values, prefs.getString('repeatMode')) ?? RepeatMode.off;
    _viewMode = _enumByName(LibraryViewMode.values, prefs.getString('viewMode')) ?? LibraryViewMode.all;

    _favoriteIds = (prefs.getStringList('favoriteIds') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();

    _recentIds = (prefs.getStringList('recentIds') ?? <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toList();
  }

  T? _enumByName<T extends Enum>(List<T> values, String? name) {
    if (name == null) return null;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  Future<void> _savePrefs() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setBool('hideNoise', _hideNoise);
    await prefs.setBool('removeDuplicates', _removeDuplicates);
    await prefs.setBool('shuffle', _shuffle);
    await prefs.setString('sortMode', _sortMode.name);
    await prefs.setString('repeatMode', _repeatMode.name);
    await prefs.setString('viewMode', _viewMode.name);
    await prefs.setStringList('favoriteIds', _favoriteIds.map((id) => id.toString()).toList());
    await prefs.setStringList('recentIds', _recentIds.map((id) => id.toString()).toList());
  }

  void _rebuildLibrary({required bool preserveCurrent}) {
    final currentId = preserveCurrent ? _currentSong?.id : null;
    final cleaned = _applyLibraryRules(_rawSongs);

    _songs
      ..clear()
      ..addAll(cleaned);

    _hiddenCount = max(0, _rawSongs.length - _songs.length);

    if (currentId != null) {
      _currentIndex = _songs.indexWhere((song) => song.id == currentId);
    } else if (_currentIndex >= _songs.length) {
      _currentIndex = -1;
    }
  }

  List<SongModel> _applyLibraryRules(List<SongModel> source) {
    final result = <SongModel>[];
    final seen = <String>{};

    for (final song in source) {
      final duration = song.duration ?? 0;
      if (duration < 30000) continue;
      if (_hideNoise && _looksLikeNoise(song)) continue;

      if (_removeDuplicates) {
        final key = _duplicateKey(song);
        if (seen.contains(key)) continue;
        seen.add(key);
      }

      result.add(song);
    }

    _sortSongs(result);
    return result;
  }

  bool _looksLikeNoise(SongModel song) {
    final name = '${song.displayNameWOExt} ${song.title}'.toLowerCase();
    final path = song.data.toLowerCase();

    final noisyText = <String>[
      'ptt',
      'voice note',
      'voicenote',
      'recording',
      'screenrecord',
      'call recording',
    ];

    final noisyPath = <String>[
      '/whatsapp/',
      '/recordings/',
      '/ringtones/',
      '/notifications/',
      '/alarms/',
      '/telegram audio/',
    ];

    return noisyText.any(name.contains) || noisyPath.any(path.contains);
  }

  String _duplicateKey(SongModel song) {
    final title = _normalized(song.title);
    final creator = _normalized(_smartArtistOrAlbum(song));
    final durationBucket = ((song.duration ?? 0) / 1000).round();
    return '$title::$creator::$durationBucket';
  }

  String _normalized(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f\u3130-\u318f\uac00-\ud7af]+'), '')
        .trim();
  }

  void _sortSongs(List<SongModel> list) {
    list.sort((a, b) {
      switch (_sortMode) {
        case SortMode.title:
          return _compareText(a.title, b.title);
        case SortMode.artist:
          final artist = _compareText(_safeArtist(a), _safeArtist(b));
          return artist == 0 ? _compareText(a.title, b.title) : artist;
        case SortMode.album:
          final album = _compareText(_safeAlbum(a), _safeAlbum(b));
          return album == 0 ? _compareText(a.title, b.title) : album;
        case SortMode.durationShort:
          return (a.duration ?? 0).compareTo(b.duration ?? 0);
        case SortMode.durationLong:
          return (b.duration ?? 0).compareTo(a.duration ?? 0);
      }
    });
  }

  int _compareText(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

  bool _isUnknownMeta(String? value) {
    if (value == null) return true;
    final cleaned = value.trim();
    if (cleaned.isEmpty) return true;
    final normalized = cleaned.toLowerCase();
    return normalized == '' ||
        normalized == 'unknown' ||
        normalized == 'unknown artist' ||
        normalized == 'unknown album' ||
        normalized == 'null';
  }

  String? _cleanMeta(String? value) {
    if (_isUnknownMeta(value)) return null;
    return value!.trim();
  }

  String _safeArtist(SongModel song) {
    return _cleanMeta(song.artist) ?? 'Unknown Artist';
  }

  String _safeAlbum(SongModel song) {
    return _cleanMeta(song.album) ?? 'Unknown Album';
  }

  String _smartArtistOrAlbum(SongModel song) {
    return _cleanMeta(song.artist) ?? _cleanMeta(song.album) ?? 'Unknown Artist';
  }

  List<SongModel> get _viewSongs {
    switch (_viewMode) {
      case LibraryViewMode.all:
        return List<SongModel>.from(_songs);
      case LibraryViewMode.favorites:
        return _songs.where((song) => _favoriteIds.contains(song.id)).toList();
      case LibraryViewMode.recent:
        final byId = <int, SongModel>{for (final song in _songs) song.id: song};
        return _recentIds.map((id) => byId[id]).whereType<SongModel>().toList();
    }
  }

  List<SongModel> get _visibleSongs {
    final q = _search.trim().toLowerCase();
    final source = _viewSongs;

    if (q.isEmpty) return source;

    return source.where((song) {
      final title = song.title.toLowerCase();
      final artist = _safeArtist(song).toLowerCase();
      final album = _safeAlbum(song).toLowerCase();
      return title.contains(q) || artist.contains(q) || album.contains(q);
    }).toList();
  }

  SongModel? get _currentSong {
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return null;
    return _songs[_currentIndex];
  }

  Uri _uriFor(SongModel song) {
    final raw = song.uri;
    if (raw != null && raw.isNotEmpty) return Uri.parse(raw);
    return Uri.file(song.data);
  }

  Future<void> _playSong(SongModel song) async {
    final index = _songs.indexWhere((item) => item.id == song.id);
    if (index < 0) return;

    setState(() => _currentIndex = index);

    try {
      final durationMs = song.duration ?? 0;

      await _player.setAudioSource(
        AudioSource.uri(
          _uriFor(song),
          tag: MediaItem(
            id: song.id.toString(),
            title: song.title,
            artist: _smartArtistOrAlbum(song),
            album: _safeAlbum(song),
            duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
          ),
        ),
      );
      await _player.play();
      await _rememberRecent(song.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memutar: ${song.title}')),
      );
    }
  }

  Future<void> _rememberRecent(int songId) async {
    _recentIds.remove(songId);
    _recentIds.insert(0, songId);

    if (_recentIds.length > 80) {
      _recentIds = _recentIds.take(80).toList();
    }

    await _savePrefs();
  }

  Future<void> _togglePlayPause() async {
    if (_songs.isEmpty) return;

    if (_currentIndex < 0) {
      final source = _visibleSongs.isNotEmpty ? _visibleSongs : _songs;
      await _playSong(source.first);
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _handleCompleted() async {
    if (_songs.isEmpty) return;

    if (_repeatMode == RepeatMode.one && _currentIndex >= 0) {
      await _playSong(_songs[_currentIndex]);
      return;
    }

    if (_currentIndex == _songs.length - 1 && _repeatMode == RepeatMode.off && !_shuffle) {
      await _player.stop();
      return;
    }

    await _next();
  }

  Future<void> _next() async {
    final queue = _visibleSongs.isNotEmpty ? _visibleSongs : _songs;
    if (queue.isEmpty) return;

    final currentId = _currentSong?.id;
    int currentQueueIndex = queue.indexWhere((song) => song.id == currentId);

    int next;
    if (_shuffle && queue.length > 1) {
      do {
        next = _random.nextInt(queue.length);
      } while (next == currentQueueIndex);
    } else {
      next = currentQueueIndex + 1;
      if (next >= queue.length) next = 0;
    }

    await _playSong(queue[next]);
  }

  Future<void> _previous() async {
    final queue = _visibleSongs.isNotEmpty ? _visibleSongs : _songs;
    if (queue.isEmpty) return;

    final currentId = _currentSong?.id;
    int currentQueueIndex = queue.indexWhere((song) => song.id == currentId);
    if (currentQueueIndex < 0) currentQueueIndex = 0;

    final prev = currentQueueIndex - 1 < 0 ? queue.length - 1 : currentQueueIndex - 1;
    await _playSong(queue[prev]);
  }

  Future<void> _toggleFavorite(SongModel song) async {
    setState(() {
      if (_favoriteIds.contains(song.id)) {
        _favoriteIds.remove(song.id);
      } else {
        _favoriteIds.add(song.id);
      }
    });

    await _savePrefs();
  }

  Future<void> _toggleCurrentFavorite() async {
    final song = _currentSong;
    if (song == null) return;
    await _toggleFavorite(song);
  }

  Future<void> _cycleRepeatMode() async {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.off:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.off;
          break;
      }
    });

    await _savePrefs();
  }

  String _repeatLabel() {
    switch (_repeatMode) {
      case RepeatMode.off:
        return 'Repeat off';
      case RepeatMode.one:
        return 'Repeat one';
      case RepeatMode.all:
        return 'Repeat all';
    }
  }

  IconData _repeatIcon() {
    switch (_repeatMode) {
      case RepeatMode.off:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat_on;
    }
  }

  String _viewLabel(LibraryViewMode mode) {
    switch (mode) {
      case LibraryViewMode.all:
        return 'Semua';
      case LibraryViewMode.favorites:
        return 'Favorit';
      case LibraryViewMode.recent:
        return 'Riwayat';
    }
  }

  IconData _viewIcon(LibraryViewMode mode) {
    switch (mode) {
      case LibraryViewMode.all:
        return Icons.library_music;
      case LibraryViewMode.favorites:
        return Icons.favorite;
      case LibraryViewMode.recent:
        return Icons.history;
    }
  }

  String _sortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.title:
        return 'Title A-Z';
      case SortMode.artist:
        return 'Artist A-Z';
      case SortMode.album:
        return 'Album A-Z';
      case SortMode.durationShort:
        return 'Durasi pendek';
      case SortMode.durationLong:
        return 'Durasi panjang';
    }
  }

  Future<void> _setViewMode(LibraryViewMode mode) async {
    setState(() => _viewMode = mode);
    await _savePrefs();
  }

  Future<void> _setSortMode(SortMode mode) async {
    setState(() {
      _sortMode = mode;
      _rebuildLibrary(preserveCurrent: true);
    });
    await _savePrefs();
  }

  Future<void> _setHideNoise(bool value) async {
    setState(() {
      _hideNoise = value;
      _rebuildLibrary(preserveCurrent: true);
    });
    await _savePrefs();
  }

  Future<void> _setRemoveDuplicates(bool value) async {
    setState(() {
      _removeDuplicates = value;
      _rebuildLibrary(preserveCurrent: true);
    });
    await _savePrefs();
  }

  Future<void> _setShuffle(bool value) async {
    setState(() => _shuffle = value);
    await _savePrefs();
  }

  Future<void> _clearFavorites() async {
    setState(() {
      _favoriteIds.clear();
      if (_viewMode == LibraryViewMode.favorites) {
        _viewMode = LibraryViewMode.all;
      }
    });
    await _savePrefs();
  }

  Future<void> _clearRecent() async {
    setState(() {
      _recentIds.clear();
      if (_viewMode == LibraryViewMode.recent) {
        _viewMode = LibraryViewMode.all;
      }
    });
    await _savePrefs();
  }

  void _openLibraryTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            void refreshSheet(Future<void> Function() action) {
              action().then((_) {
                if (mounted) sheetSetState(() {});
              });
            }

            final media = MediaQuery.of(context);

            return Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                media.viewPadding.bottom + 12,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: media.size.height * 0.82,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF15151D),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x33D6A84F)),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Library Control',
                              style: TextStyle(
                                color: Color(0xFFF4F1EA),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_rawSongs.length} audio discan • ${_songs.length} ditampilkan • $_hiddenCount disembunyikan',
                        style: const TextStyle(color: Color(0xFFA9A5A0)),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _favoriteIds.isEmpty ? null : () => refreshSheet(_clearFavorites),
                            icon: const Icon(Icons.heart_broken, size: 16),
                            label: const Text('Clear favorit'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF4F1EA),
                              side: const BorderSide(color: Color(0x33D6A84F)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _recentIds.isEmpty ? null : () => refreshSheet(_clearRecent),
                            icon: const Icon(Icons.history_toggle_off, size: 16),
                            label: const Text('Clear riwayat'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF4F1EA),
                              side: const BorderSide(color: Color(0x33D6A84F)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Mode Library',
                        style: TextStyle(color: Color(0xFFF4F1EA), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: LibraryViewMode.values.map((mode) {
                          final selected = _viewMode == mode;
                          return ChoiceChip(
                            avatar: Icon(
                              _viewIcon(mode),
                              size: 16,
                              color: selected ? const Color(0xFF08080C) : const Color(0xFFD6A84F),
                            ),
                            selected: selected,
                            label: Text(_viewLabel(mode)),
                            onSelected: (_) => refreshSheet(() => _setViewMode(mode)),
                            selectedColor: const Color(0xFFD6A84F),
                            labelStyle: TextStyle(
                              color: selected ? const Color(0xFF08080C) : const Color(0xFFF4F1EA),
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Sorting',
                        style: TextStyle(color: Color(0xFFF4F1EA), fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: SortMode.values.map((mode) {
                          final selected = _sortMode == mode;
                          return ChoiceChip(
                            selected: selected,
                            label: Text(_sortLabel(mode)),
                            onSelected: (_) => refreshSheet(() => _setSortMode(mode)),
                            selectedColor: const Color(0xFFD6A84F),
                            labelStyle: TextStyle(
                              color: selected ? const Color(0xFF08080C) : const Color(0xFFF4F1EA),
                              fontWeight: FontWeight.w700,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _removeDuplicates,
                        activeColor: const Color(0xFFD6A84F),
                        onChanged: (value) => refreshSheet(() => _setRemoveDuplicates(value)),
                        title: const Text(
                          'Sembunyikan file identik',
                          style: TextStyle(color: Color(0xFFF4F1EA)),
                        ),
                        subtitle: const Text(
                          'Berdasarkan judul + creator + durasi',
                          style: TextStyle(color: Color(0xFFA9A5A0)),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _hideNoise,
                        activeColor: const Color(0xFFD6A84F),
                        onChanged: (value) => refreshSheet(() => _setHideNoise(value)),
                        title: const Text(
                          'Filter audio non-musik',
                          style: TextStyle(color: Color(0xFFF4F1EA)),
                        ),
                        subtitle: const Text(
                          'WhatsApp, rekaman, ringtone, notification',
                          style: TextStyle(color: Color(0xFFA9A5A0)),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _songMeta(SongModel song) {
    final duration = Duration(milliseconds: song.duration ?? 0);
    final artist = _cleanMeta(song.artist);
    final album = _cleanMeta(song.album);

    final parts = <String>[];

    if (artist != null) parts.add(artist);

    if (album != null && _normalized(album) != _normalized(artist ?? '')) {
      parts.add(album);
    }

    if (parts.isEmpty) parts.add('Local audio');

    parts.add(_formatDuration(duration));
    return parts.join(' • ');
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _searchController.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSongs = _visibleSongs;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              count: _songs.length,
              totalCount: _rawSongs.length,
              hiddenCount: _hiddenCount,
              loading: _loading,
              sortLabel: _sortLabel(_sortMode),
              viewLabel: _viewLabel(_viewMode),
              favoriteCount: _favoriteIds.length,
              recentCount: _recentIds.length,
              onRefresh: _bootstrap,
              onTools: _openLibraryTools,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                style: const TextStyle(color: Color(0xFFF4F1EA)),
                decoration: InputDecoration(
                  hintText: 'Cari lagu, artist, atau album...',
                  hintStyle: const TextStyle(color: Color(0xFF8F8A84)),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF15151D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _StatusStrip(
              visibleCount: visibleSongs.length,
              libraryCount: _rawSongs.length,
              hiddenCount: _hiddenCount,
              favoriteCount: _favoriteIds.length,
              recentCount: _recentIds.length,
              viewLabel: _viewLabel(_viewMode),
              shuffle: _shuffle,
              repeatLabel: _repeatLabel(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_permissionGranted
                      ? _PermissionPanel(onRequest: _bootstrap)
                      : visibleSongs.isEmpty
                          ? _EmptyPanel(hasSearch: _search.trim().isNotEmpty, viewLabel: _viewLabel(_viewMode))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                              itemCount: visibleSongs.length,
                              itemBuilder: (context, index) {
                                final song = visibleSongs[index];
                                final isActive = _currentSong?.id == song.id;
                                return _SongTile(
                                  song: song,
                                  active: isActive,
                                  favorite: _favoriteIds.contains(song.id),
                                  meta: _songMeta(song),
                                  onTap: () => _playSong(song),
                                  onFavorite: () => _toggleFavorite(song),
                                );
                              },
                            ),
            ),
            _MiniPlayer(
              song: _currentSong,
              player: _player,
              favorite: _currentSong != null && _favoriteIds.contains(_currentSong!.id),
              metaBuilder: _songMeta,
              formatDuration: _formatDuration,
              shuffle: _shuffle,
              repeatLabel: _repeatLabel(),
              repeatIcon: _repeatIcon(),
              onPrev: _previous,
              onToggle: _togglePlayPause,
              onNext: _next,
              onToggleShuffle: () => _setShuffle(!_shuffle),
              onCycleRepeat: _cycleRepeatMode,
              onToggleFavorite: _toggleCurrentFavorite,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.totalCount,
    required this.hiddenCount,
    required this.loading,
    required this.sortLabel,
    required this.viewLabel,
    required this.favoriteCount,
    required this.recentCount,
    required this.onRefresh,
    required this.onTools,
  });

  final int count;
  final int totalCount;
  final int hiddenCount;
  final bool loading;
  final String sortLabel;
  final String viewLabel;
  final int favoriteCount;
  final int recentCount;
  final VoidCallback onRefresh;
  final VoidCallback onTools;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rakyzu Music Player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFF4F1EA),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Premium offline music player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xFFA9A5A0), fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  loading
                      ? 'Scanning library...'
                      : '$viewLabel • $sortLabel • $favoriteCount favorit • $recentCount riwayat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF8F8A84), fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: loading ? null : onTools,
                    icon: const Icon(Icons.tune),
                    color: const Color(0xFFD6A84F),
                  ),
                  IconButton(
                    onPressed: loading ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                    color: const Color(0xFFD6A84F),
                  ),
                ],
              ),
              Text(
                loading ? 'scan' : '$count lagu',
                style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.visibleCount,
    required this.libraryCount,
    required this.hiddenCount,
    required this.favoriteCount,
    required this.recentCount,
    required this.viewLabel,
    required this.shuffle,
    required this.repeatLabel,
  });

  final int visibleCount;
  final int libraryCount;
  final int hiddenCount;
  final int favoriteCount;
  final int recentCount;
  final String viewLabel;
  final bool shuffle;
  final String repeatLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _TinyPill(icon: Icons.library_music, text: '$visibleCount tampil / $libraryCount audio'),
            const SizedBox(width: 8),
            _TinyPill(icon: Icons.visibility_off, text: '$hiddenCount disembunyikan'),
            const SizedBox(width: 8),
            _TinyPill(icon: Icons.favorite, text: '$favoriteCount favorit'),
            const SizedBox(width: 8),
            _TinyPill(icon: Icons.history, text: '$recentCount riwayat'),
            const SizedBox(width: 8),
            _TinyPill(icon: Icons.view_list, text: viewLabel),
            const SizedBox(width: 8),
            _TinyPill(icon: shuffle ? Icons.shuffle_on : Icons.shuffle, text: shuffle ? 'Shuffle on' : 'Shuffle off'),
            const SizedBox(width: 8),
            _TinyPill(icon: Icons.repeat, text: repeatLabel),
          ],
        ),
      ),
    );
  }
}

class _TinyPill extends StatelessWidget {
  const _TinyPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF15151D),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22222222)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFD6A84F)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 11)),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.active,
    required this.favorite,
    required this.meta,
    required this.onTap,
    required this.onFavorite,
  });

  final SongModel song;
  final bool active;
  final bool favorite;
  final String meta;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF302716) : const Color(0xFF15151D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? const Color(0xFFD6A84F) : const Color(0x22222222),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            artworkHeight: 52,
            artworkWidth: 52,
            artworkFit: BoxFit.cover,
            nullArtworkWidget: Container(
              width: 52,
              height: 52,
              color: const Color(0xFF25252F),
              child: Icon(
                active ? Icons.graphic_eq : Icons.music_note,
                color: const Color(0xFFD6A84F),
              ),
            ),
          ),
        ),
        title: Text(
          song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFF4F1EA),
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: onFavorite,
          icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
          color: favorite ? const Color(0xFFD6A84F) : const Color(0xFF8F8A84),
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.song,
    required this.player,
    required this.favorite,
    required this.metaBuilder,
    required this.formatDuration,
    required this.shuffle,
    required this.repeatLabel,
    required this.repeatIcon,
    required this.onPrev,
    required this.onToggle,
    required this.onNext,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onToggleFavorite,
  });

  final SongModel? song;
  final AudioPlayer player;
  final bool favorite;
  final String Function(SongModel song) metaBuilder;
  final String Function(Duration duration) formatDuration;
  final bool shuffle;
  final String repeatLabel;
  final IconData repeatIcon;
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF15151D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x33D6A84F)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: song == null
                    ? Container(
                        width: 56,
                        height: 56,
                        color: const Color(0xFF25252F),
                        child: const Icon(Icons.music_note, color: Color(0xFFD6A84F)),
                      )
                    : QueryArtworkWidget(
                        id: song!.id,
                        type: ArtworkType.AUDIO,
                        artworkHeight: 56,
                        artworkWidth: 56,
                        artworkFit: BoxFit.cover,
                        nullArtworkWidget: Container(
                          width: 56,
                          height: 56,
                          color: const Color(0xFF25252F),
                          child: const Icon(Icons.music_note, color: Color(0xFFD6A84F)),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song?.title ?? 'Belum ada lagu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF4F1EA),
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song == null ? 'Pilih lagu dari library' : metaBuilder(song!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: song == null ? null : onToggleFavorite,
                icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
                color: favorite ? const Color(0xFFD6A84F) : const Color(0xFF8F8A84),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _ModeButton(
                active: shuffle,
                icon: shuffle ? Icons.shuffle_on : Icons.shuffle,
                label: 'Shuffle',
                onTap: onToggleShuffle,
              ),
              const SizedBox(width: 8),
              _ModeButton(
                active: repeatLabel != 'Repeat off',
                icon: repeatIcon,
                label: repeatLabel.replaceAll('Repeat ', ''),
                onTap: onCycleRepeat,
              ),
              const SizedBox(width: 8),
              _ModeButton(
                active: favorite,
                icon: favorite ? Icons.favorite : Icons.favorite_border,
                label: 'Fav',
                onTap: song == null ? () {} : onToggleFavorite,
              ),
            ],
          ),
          const SizedBox(height: 4),
          StreamBuilder<Duration>(
            stream: player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = player.duration ?? Duration.zero;
              final max = duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
              final value = position.inMilliseconds.clamp(0, max.toInt()).toDouble();

              return Column(
                children: [
                  Slider(
                    min: 0,
                    max: max,
                    value: value,
                    activeColor: const Color(0xFFD6A84F),
                    inactiveColor: const Color(0xFF3A3A44),
                    onChanged: song == null
                        ? null
                        : (newValue) {
                            player.seek(Duration(milliseconds: newValue.toInt()));
                          },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(position), style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 11)),
                      Text(formatDuration(duration), style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 11)),
                    ],
                  ),
                ],
              );
            },
          ),
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(onPressed: onPrev, icon: const Icon(Icons.skip_previous)),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: onToggle,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD6A84F),
                      foregroundColor: const Color(0xFF08080C),
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                  const SizedBox(width: 10),
                  IconButton(onPressed: onNext, icon: const Icon(Icons.skip_next)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD6A84F) : const Color(0xFF20202A),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF08080C) : const Color(0xFFA9A5A0)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF08080C) : const Color(0xFFA9A5A0),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.library_music, color: Color(0xFFD6A84F), size: 72),
            const SizedBox(height: 18),
            const Text(
              'Permission audio diperlukan',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFF4F1EA), fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rakyzu perlu izin membaca audio lokal agar bisa menampilkan file musik dari device ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA9A5A0)),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRequest, child: const Text('Berikan Permission')),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.hasSearch, required this.viewLabel});

  final bool hasSearch;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    final title = hasSearch ? 'Tidak ada hasil' : '$viewLabel kosong';
    final body = hasSearch
        ? 'Coba kata kunci lain, atau ubah filter library.'
        : 'Belum ada lagu di mode ini. Tambahkan favorit, putar lagu, atau ubah mode library.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_off, color: Color(0xFFD6A84F), size: 72),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(color: Color(0xFFF4F1EA), fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA9A5A0)),
            ),
          ],
        ),
      ),
    );
  }
}
