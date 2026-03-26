import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' as ui;

void main() {
  runApp(const NeonWaveApp());
}

// --- МОДЕЛЬ ДАННЫХ (без изменений) ---
class Track {
  final int id;
  final String title;
  final String artist;
  final String minioKey;
  final String coverUrl;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.minioKey,
    required this.coverUrl,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'],
      title: json['title'],
      artist: json['artist'] ?? "Unknown Artist",
      minioKey: json['minio_key'],
      coverUrl: json['cover_url'] ?? "",
    );
  }
}

// --- ГЛАВНОЕ ПРИЛОЖЕНИЕ ---
class NeonWaveApp extends StatelessWidget {
  const NeonWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NeonWave Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0F1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFF4081),
          surface: Color(0xFF111827),
          background: Color(0xFF0A0F1A),
        ),
        useMaterial3: true,
      ),
      home: const MobileFrame(child: MusicPlayerScreen()),
    );
  }
}

// Рамка для мобильного вида
class MobileFrame extends StatelessWidget {
  final Widget child;
  const MobileFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0F1A),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: child,
          ),
        ),
      ),
    );
  }
}

// --- ОСНОВНОЙ ЭКРАН ---
class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Track> _tracks = [];
  List<Track> _filteredTracks = [];
  Track? _currentTrack;
  bool _isLoading = true;
  String _searchQuery = "";
  late AnimationController _pulseController;

  final String baseUrl = "http://172.24.12.22:30964";
  int _selectedNavIndex = 0; // для нижней навигации

  @override
  void initState() {
    super.initState();
    _fetchTracks();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchTracks() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tracks'));
      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        setState(() {
          _tracks = jsonResponse.map((data) => Track.fromJson(data)).toList();
          _filteredTracks = _tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tracks: $e");
    }
  }

  void _filterTracks(String query) {
    setState(() {
      _searchQuery = query;
      _filteredTracks = _tracks
          .where((t) =>
              t.title.toLowerCase().contains(query.toLowerCase()) ||
              t.artist.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _playTrack(Track track) async {
    if (_currentTrack?.id == track.id) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }

    setState(() => _currentTrack = track);

    try {
      await _audioPlayer.stop();
      final streamUrl = "$baseUrl/stream?key=${track.minioKey}";
      await _audioPlayer.setUrl(streamUrl);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint("Error streaming: $e");
    }
  }

  void _openFullPlayer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FullPlayerPage(
        track: _currentTrack!,
        player: _audioPlayer,
        baseUrl: baseUrl,
      ),
    );
  }

  void _showUploadSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          color: Color(0xFF111827),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: UploadTrackForm(baseUrl: baseUrl),
        ),
      ),
    ).then((_) {
      _fetchTracks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Фоновый градиент
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A0F1A), Color(0xFF0F172A)],
              ),
            ),
          ),
          // Основной контент
          CustomScrollView(
            slivers: [
              _buildAppBar(), // изменённый AppBar
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16,
                          100), // отступ снизу для мини-плеера и навбара
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildTrackCard(_filteredTracks[index]),
                          childCount: _filteredTracks.length,
                        ),
                      ),
                    ),
            ],
          ),
          // Мини-плеер (плавающий)
          if (_currentTrack != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 80, // поднят выше, чтобы не перекрывать навбар
              child: _buildGlassMiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: _buildFloatingUploadButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Новый AppBar без большого отступа для поиска
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 100,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFFF4081)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(Icons.waves, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              "NEONWAVE",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 16, bottom: 12),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
          ),
          child: TextField(
            onChanged: _filterTracks,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Найти трек...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF00E5FF)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard(Track track) {
    bool isPlaying = _currentTrack?.id == track.id;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPlaying
              ? [
                  const Color(0xFF00E5FF).withOpacity(0.2),
                  const Color(0xFFFF4081).withOpacity(0.2)
                ]
              : [
                  Colors.white.withOpacity(0.05),
                  Colors.white.withOpacity(0.02)
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPlaying ? const Color(0xFF00E5FF) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _playTrack(track),
            splashColor: const Color(0xFF00E5FF).withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isPlaying
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.4),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _CORSImage(url: track.coverUrl, size: 55),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: TextStyle(
                            color: isPlaying
                                ? const Color(0xFF00E5FF)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artist,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPlaying)
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF00E5FF).withOpacity(0.2),
                          ),
                          child: Icon(
                            Icons.equalizer,
                            color: const Color(0xFF00E5FF),
                            size: 24,
                          ),
                        );
                      },
                    )
                  else
                    const Icon(Icons.play_arrow,
                        color: Colors.white38, size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassMiniPlayer() {
    return GestureDetector(
      onTap: _openFullPlayer,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _CORSImage(url: _currentTrack!.coverUrl, size: 45),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTrack!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _currentTrack!.artist,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<PlayerState>(
                    stream: _audioPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                            size: 28),
                        color: const Color(0xFF00E5FF),
                        onPressed:
                            playing ? _audioPlayer.pause : _audioPlayer.play,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_filled, "Главная", 0),
              _buildNavItem(Icons.explore, "Обзор", 1),
              _buildNavItem(Icons.library_music, "Медиатека", 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNavIndex = index;
        });
        // Здесь можно добавить логику переключения между экранами, но пока оставим просто визуал
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00E5FF) : Colors.white54,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingUploadButton() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF00E5FF), Color(0xFFFF4081)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withOpacity(0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: _showUploadSheet,
      ),
    );
  }
}

// --- ПОЛНОЭКРАННЫЙ ПЛЕЕР (без изменений, кроме импорта) ---
class FullPlayerPage extends StatefulWidget {
  final Track track;
  final AudioPlayer player;
  final String baseUrl;

  const FullPlayerPage({
    super.key,
    required this.track,
    required this.player,
    required this.baseUrl,
  });

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage>
    with TickerProviderStateMixin {
  late AnimationController _colorController;

  @override
  void initState() {
    super.initState();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: _colorController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.5,
                colors: [
                  Color.lerp(
                    const Color(0xFF00E5FF),
                    const Color(0xFFFF4081),
                    (_colorController.value * 2) % 1,
                  )!
                      .withOpacity(0.3),
                  const Color(0xFF0A0F1A),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_downward,
                          color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(flex: 1),
                  Hero(
                    tag: 'cover-${widget.track.id}',
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.5),
                            blurRadius: 30,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child:
                            _CORSImage(url: widget.track.coverUrl, size: 280),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          widget.track.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.track.artist,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildNeonProgressBar(),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNeonButton(Icons.shuffle, () {}),
                      _buildNeonButton(Icons.skip_previous,
                          () => widget.player.seek(Duration.zero)),
                      StreamBuilder<PlayerState>(
                        stream: widget.player.playerStateStream,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return GestureDetector(
                            onTap: playing
                                ? widget.player.pause
                                : widget.player.play,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00E5FF),
                                    Color(0xFFFF4081)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E5FF)
                                        .withOpacity(0.6),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                              child: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildNeonButton(
                          Icons.skip_next,
                          () => widget.player
                              .seek(widget.player.duration ?? Duration.zero)),
                      _buildNeonButton(Icons.repeat, () {}),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNeonButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 28),
        color: Colors.white,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildNeonProgressBar() {
    return StreamBuilder<Duration>(
      stream: widget.player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = widget.player.duration ?? Duration.zero;
        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: const Color(0xFFFF4081),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFF00E5FF),
                overlayColor: const Color(0xFF00E5FF).withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0, duration.inMilliseconds.toDouble()),
                max: duration.inMilliseconds.toDouble(),
                onChanged: (v) =>
                    widget.player.seek(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white60)),
                  Text(_formatDuration(duration),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white60)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

// --- ВИДЖЕТ ЗАГРУЗКИ ОБЛОЖКИ (без изменений) ---
class _CORSImage extends StatelessWidget {
  final String url;
  final double size;
  final double radius;

  const _CORSImage({required this.url, required this.size, this.radius = 10});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _placeholder();

    return FutureBuilder<Uint8List>(
      future: http.get(Uri.parse(url)).then((res) => res.bodyBytes),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Icon(Icons.music_note, color: Colors.white38),
    );
  }
}

// --- ФОРМА ЗАГРУЗКИ (без изменений) ---
class UploadTrackForm extends StatefulWidget {
  final String baseUrl;
  const UploadTrackForm({super.key, required this.baseUrl});

  @override
  State<UploadTrackForm> createState() => _UploadTrackFormState();
}

class _UploadTrackFormState extends State<UploadTrackForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _artistController = TextEditingController();

  PlatformFile? _audioFile;
  PlatformFile? _coverFile;
  bool _isUploading = false;

  Future<void> _pickAudio() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null) setState(() => _audioFile = result.files.first);
  }

  Future<void> _pickCover() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) setState(() => _coverFile = result.files.first);
  }

  Future<void> _uploadTrack() async {
    if (_titleController.text.isEmpty ||
        _artistController.text.isEmpty ||
        _audioFile == null ||
        _coverFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Заполните все поля и выберите файлы!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFFFF4081),
      ));
      return;
    }

    setState(() => _isUploading = true);

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('${widget.baseUrl}/upload-track'));

      request.fields['title'] = _titleController.text;
      request.fields['artist'] = _artistController.text;

      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        _audioFile!.bytes!,
        filename: _audioFile!.name,
      ));

      request.files.add(http.MultipartFile.fromBytes(
        'cover',
        _coverFile!.bytes!,
        filename: _coverFile!.name,
      ));

      var response = await request.send();

      if (response.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Трек успешно загружен!"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ));
        }
      } else {
        throw Exception("Ошибка загрузки: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Ошибка: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "ЗАГРУЗИТЬ ТРЕК",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Color(0xFF00E5FF),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Название",
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _artistController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: "Исполнитель",
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickAudio,
                icon: const Icon(Icons.audiotrack),
                label: Text(_audioFile != null ? "MP3 выбран" : "MP3"),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: const Color(0xFF00E5FF).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickCover,
                icon: const Icon(Icons.image),
                label: Text(_coverFile != null ? "Фото выбрано" : "Фото"),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: const Color(0xFFFF4081).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        _isUploading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF00E5FF),
                  strokeWidth: 3,
                ),
              )
            : ElevatedButton(
                onPressed: _uploadTrack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "ЗАГРУЗИТЬ",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
        const SizedBox(height: 20),
      ],
    );
  }
}
