import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

void main() {
  runApp(const ZPlayerApp());
}

class ZPlayerApp extends StatelessWidget {
  const ZPlayerApp({super.key});

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

class MusicHomePage extends StatefulWidget {
  const MusicHomePage({super.key});

  @override
  State<MusicHomePage> createState() => _MusicHomePageState();
}

class _MusicHomePageState extends State<MusicHomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _player = AudioPlayer();

  final List<SongModel> _songs = <SongModel>[];
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<PlayerState>? _playerStateSub;

  bool _loading = true;
  bool _permissionGranted = false;
  int _currentIndex = -1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _bootstrap();

    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _next();
      }
    });
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);

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

    final filtered = songs.where((song) {
      final duration = song.duration ?? 0;
      final isRealMusic = duration >= 30000;
      final looksLikeNoise = song.displayNameWOExt.toLowerCase().contains('ptt') ||
          song.data.toLowerCase().contains('/whatsapp/') ||
          song.data.toLowerCase().contains('/recordings/');
      return isRealMusic && !looksLikeNoise;
    }).toList();

    if (!mounted) return;

    setState(() {
      _permissionGranted = true;
      _songs
        ..clear()
        ..addAll(filtered);
      _loading = false;
    });
  }

  List<SongModel> get _visibleSongs {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _songs;

    return _songs.where((song) {
      final title = song.title.toLowerCase();
      final artist = (song.artist ?? '').toLowerCase();
      final album = (song.album ?? '').toLowerCase();
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
      await _player.setAudioSource(AudioSource.uri(_uriFor(song)));
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memutar: ${song.title}')),
      );
    }
  }

  Future<void> _togglePlayPause() async {
    if (_songs.isEmpty) return;

    if (_currentIndex < 0) {
      await _playSong(_songs.first);
      return;
    }

    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _next() async {
    if (_songs.isEmpty) return;
    final next = _currentIndex + 1 >= _songs.length ? 0 : _currentIndex + 1;
    await _playSong(_songs[next]);
  }

  Future<void> _previous() async {
    if (_songs.isEmpty) return;
    final prev = _currentIndex - 1 < 0 ? _songs.length - 1 : _currentIndex - 1;
    await _playSong(_songs[prev]);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _songMeta(SongModel song) {
    final artist = (song.artist == null || song.artist == '<unknown>') ? 'Unknown Artist' : song.artist!;
    final album = (song.album == null || song.album == '<unknown>') ? 'Unknown Album' : song.album!;
    final duration = Duration(milliseconds: song.duration ?? 0);
    return '$artist • $album • ${_formatDuration(duration)}';
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
              loading: _loading,
              onRefresh: _bootstrap,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _search = value),
                style: const TextStyle(color: Color(0xFFF4F1EA)),
                decoration: InputDecoration(
                  hintText: 'Cari lagu, artist, atau album...',
                  hintStyle: const TextStyle(color: Color(0xFF8F8A84)),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFF15151D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_permissionGranted
                      ? _PermissionPanel(onRequest: _bootstrap)
                      : visibleSongs.isEmpty
                          ? const _EmptyPanel()
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              itemCount: visibleSongs.length,
                              itemBuilder: (context, index) {
                                final song = visibleSongs[index];
                                final isActive = _currentSong?.id == song.id;
                                return _SongTile(
                                  song: song,
                                  active: isActive,
                                  meta: _songMeta(song),
                                  onTap: () => _playSong(song),
                                );
                              },
                            ),
            ),
            _MiniPlayer(
              song: _currentSong,
              player: _player,
              metaBuilder: _songMeta,
              formatDuration: _formatDuration,
              onPrev: _previous,
              onToggle: _togglePlayPause,
              onNext: _next,
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
    required this.loading,
    required this.onRefresh,
  });

  final int count;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rakyzu Music Player',
                  style: TextStyle(
                    color: Color(0xFFF4F1EA),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Premium offline music player',
                  style: TextStyle(color: Color(0xFFA9A5A0), fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: loading ? null : onRefresh,
                icon: const Icon(Icons.refresh),
                color: const Color(0xFFD6A84F),
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

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.active,
    required this.meta,
    required this.onTap,
  });

  final SongModel song;
  final bool active;
  final String meta;
  final VoidCallback onTap;

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
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFFA9A5A0), fontSize: 12),
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.song,
    required this.player,
    required this.metaBuilder,
    required this.formatDuration,
    required this.onPrev,
    required this.onToggle,
    required this.onNext,
  });

  final SongModel? song;
  final AudioPlayer player;
  final String Function(SongModel song) metaBuilder;
  final String Function(Duration duration) formatDuration;
  final VoidCallback onPrev;
  final VoidCallback onToggle;
  final VoidCallback onNext;

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
                        fontWeight: FontWeight.w800,
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
            ],
          ),
          const SizedBox(height: 6),
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
                        : (newValue) => player.seek(Duration(milliseconds: newValue.toInt())),
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
              style: TextStyle(color: Color(0xFFF4F1EA), fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'ZPlayer perlu izin membaca audio lokal agar bisa menampilkan file musik dari device ini.',
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
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off, color: Color(0xFFD6A84F), size: 72),
            SizedBox(height: 18),
            Text(
              'Library kosong',
              style: TextStyle(color: Color(0xFFF4F1EA), fontSize: 20, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Pastikan device punya file MP3/M4A/WAV lokal yang terindeks oleh Android MediaStore.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFA9A5A0)),
            ),
          ],
        ),
      ),
    );
  }
}
