import 'dart:async';
import 'dart:io';

import 'package:disk_space/disk_space.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_info/system_info.dart';
import 'package:wakelock/wakelock.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _memorySize;
  int _diskSpace;
  int _tenSecondsSize;
  Directory _tempDir;
  DateTime _startTime;
  CameraController _controller;
  Timer _timer;

  @override
  void initState() {
    Wakelock.enable();
    _getSysInfo();
    _initializeCameraController();
    super.initState();
  }

  void _getSysInfo() async {
    var totalVirtualMemory = SysInfo.getTotalVirtualMemory();
    var diskSpaceInMB = await DiskSpace.getFreeDiskSpace;
    var tempDir = await getTemporaryDirectory();
    setState(() {
      _tempDir = tempDir;
      _diskSpace = diskSpaceInMB.toInt() * 1024 * 1024;
      _memorySize = totalVirtualMemory;
    });
  }

  Future<void> _initializeCameraController() async {
    final cameras = await availableCameras();
    cameras
        .sort((a, b) => a.lensDirection == CameraLensDirection.back ? -1 : 1);
    final camera = cameras.first;

    final controller = CameraController(camera, ResolutionPreset.max);
    await controller.initialize();

    _controller = controller;
    setState(() {});
  }

  int _toMb(int bytes) {
    return bytes / 1024 ~/ 1024;
  }

  @override
  void dispose() {
    Wakelock.disable();
    super.dispose();
  }

  Future<void> _startVideo() async {
    await _controller.startVideoRecording();
    setState(() {});
    _timer?.cancel();
    _startTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      setState(() {});
    });

    if (_tenSecondsSize == null) {
      await Future<void>.delayed(Duration(seconds: 10));
      final file = await _controller.stopVideoRecording();
      _tenSecondsSize = await file.length();
      await _controller.startVideoRecording();

      _startTime = DateTime.now();
      setState(() {});
    }
  }

  String _videoLength() {
    var val = _memorySize * 10 ~/ _tenSecondsSize ~/ 60;
    return (val + 1).toString();
  }

  Future<void> _stopRecord() async {
    try {
      final file = await _controller.stopVideoRecording();
      _startTime = null;
      final fileName =
          p.join(_tempDir.path, 'tempFile${p.extension(file.path)}');

      // fix
      final sourceFile = File(file.path);
      await sourceFile.copy(fileName);
      print('copy operation performed');

      await File(fileName).delete();
      // saveTO
      await file.saveTo(fileName);
      print('saveTo operation performed');

      await File(fileName).delete();
    } catch (e, t) {
      print(e);
      print(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_diskSpace != null) ...[
              Text('Disk space: ${_toMb(_diskSpace)} MB'),
              if (_memorySize != null && _diskSpace < _memorySize)
                Text('You do not have enough disk space'),
            ],
            if (_memorySize != null)
              Text('Memory size: ${_toMb(_memorySize)} MB'),
            if (_tenSecondsSize != null)
              Text('10sec video has size: ${_toMb(_tenSecondsSize)} MB'),
            if (_tenSecondsSize != null)
              Text('Record video longer than : ${_videoLength()} min'),
            if (_startTime != null)
              Text('Elapsed: ${DateTime.now().difference(_startTime)}'),
            if (_controller != null)
              SizedBox(
                width: 100,
                height: 100,
                child: CameraPreview(_controller),
              ),
          ],
        ),
      ),
      floatingActionButton: _controller != null
          ? FloatingActionButton(
              onPressed: () {
                if (_controller.value.isRecordingVideo) {
                  _stopRecord();
                } else {
                  _startVideo();
                }
              },
              child:
                  Text(_controller.value.isRecordingVideo ? 'Stop' : 'Start'),
            )
          : null,
    );
  }
}
