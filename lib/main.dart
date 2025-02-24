import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras));
}
class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  MyApp(this.cameras);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(cameras),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  CameraScreen(this.cameras);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late VideoPlayerController _videoController;
  String _videoPath = "";
  bool _isRecording = false;
  bool _isPlayingVideo = false;
  int _selectedCameraIndex = 0;
  double _brightness = 0.5;
  double _colorValue = 0.0;
  Color _appBarColor = Colors.red;
  double _appBarOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // Initialize the camera
  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;
    _controller = CameraController(widget.cameras[_selectedCameraIndex], ResolutionPreset.high);
    await _controller.initialize();
    setState(() {});
  }

  // Switch between front and back camera
  Future<void> _switchCamera() async {
    if (widget.cameras.isEmpty) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    _controller = CameraController(widget.cameras[_selectedCameraIndex], ResolutionPreset.high);
    await _controller.initialize();
    setState(() {});
  }

  // Start recording method
  Future<void> _startRecording() async {
    if (!_controller.value.isInitialized || _isRecording) return;

    final directory = await getTemporaryDirectory();
    _videoPath = '${directory.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      await _controller.startVideoRecording();
      setState(() {
        _isRecording = true;
        _isPlayingVideo = false;
      });
    } catch (e) {
      print("Error starting video recording: $e");
    }
  }

  // Stop recording method
  Future<void> _stopRecording() async {
    if (!_controller.value.isRecordingVideo || !_isRecording) return;

    try {
      final file = await _controller.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = file.path;
        _isPlayingVideo = true;
      });

      _videoController = VideoPlayerController.file(File(_videoPath))
        ..initialize().then((_) {
          setState(() {});
          _videoController.play();
        });
    } catch (e) {
      print("Error stopping video recording: $e");
    }
  }

  // Update screen brightness
  void _changeBrightness(double value) {
    setState(() {
      _brightness = value;
      _appBarOpacity = value;
    });
  }

  // Update AppBar color
  void _changeAppBarColor(double value) {
    List<Color> colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
    int index = (value * (colors.length - 1)).toInt();
    setState(() {
      _colorValue = value;
      _appBarColor = colors[index].withOpacity(_appBarOpacity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(80),
        child: AppBar(
          backgroundColor: _appBarColor.withOpacity(_appBarOpacity),
          elevation: 0,
        ),
      ),
      body: Stack(
        children: [
          // Display video player after recording
          if (_isPlayingVideo && !_isRecording)
            Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayer(_videoController),
              ),
            ),

          // Camera preview before recording
          if (!_isPlayingVideo)
            Center(
              child: _controller.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: CameraPreview(_controller),
                    )
                  : Container(color: Colors.black),
            ),

          // Brightness slider on the left
          Positioned(
            left: 10,
            top: 100,
            bottom: 100,
            child: RotatedBox(
              quarterTurns: -1,
              child: Slider(
                value: _brightness,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.yellow,
                onChanged: _changeBrightness,
              ),
            ),
          ),

          // Color slider on the left to control AppBar color
          Positioned(
            left: 50,
            top: 100,
            bottom: 100,
            child: RotatedBox(
              quarterTurns: -1,
              child: Slider(
                value: _colorValue,
                min: 0.0,
                max: 1.0,
                activeColor: Colors.blue,
                onChanged: _changeAppBarColor,
              ),
            ),
          ),

          // Record button in the center
          Positioned(
            bottom: 50,
            left: MediaQuery.of(context).size.width / 2 - 40,
            child: IconButton(
              icon: Icon(
                _isRecording ? Icons.stop : Icons.circle,
                color: Colors.red,
                size: 80,
              ),
              onPressed: _isRecording ? _stopRecording : _startRecording,
            ),
          ),

          // Switch camera button at the top right
          Positioned(
            top: 50,
            right: 20,
            child: FloatingActionButton(
              child: Icon(Icons.switch_camera),
              onPressed: _switchCamera,
            ),
          ),
        ],
      ),
    );
  }
}
