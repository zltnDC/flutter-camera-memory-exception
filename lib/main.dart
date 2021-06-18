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
  int _totalMemory, _freeMemory;
  int _diskSpace;
  int _twelveSecondsSize;
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

  Future<void> _getSysInfo() async {
    //Free physical memory ?
    if (Platform.isAndroid) {
      var totalMemory = SysInfo.getTotalVirtualMemory();
      var freeMemory = SysInfo.getFreeVirtualMemory();

      _freeMemory = freeMemory;
      _totalMemory = totalMemory;
    }

    var diskSpaceInMB = await DiskSpace.getFreeDiskSpace;

    setState(() {
      _diskSpace = (diskSpaceInMB * 1024 * 1024).toInt();
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
    await _getSysInfo();
    await _controller.startVideoRecording();
    setState(() {});
    _timer?.cancel();
    _startTime = DateTime.now();
    _timer = Timer.periodic(Duration(seconds: 1), (t) {
      setState(() {});
    });

    if (_twelveSecondsSize == null) {
      await Future<void>.delayed(Duration(seconds: 12));
      final file = await _controller.stopVideoRecording();
      _twelveSecondsSize = await file.length();
      await _controller.startVideoRecording();

      _startTime = DateTime.now();
      setState(() {});
    }
  }

  int _aproxVideoLengthInMinutes() {
    if (Platform.isAndroid &&
        _twelveSecondsSize != null &&
        _freeMemory != null &&
        _totalMemory != null) {
      var aproxVideoSize = (_freeMemory + _totalMemory) / 2;
      var oneMinuteSize = _twelveSecondsSize * 5;
      var val = aproxVideoSize ~/ oneMinuteSize;
      return val + 1;
    }
    return null;
  }

  Future<void> _stopRecord() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final xfile = await _controller.stopVideoRecording();
      _startTime = null;
      final fileName =
          p.join(tempDir.path, 'tempFile${p.extension(xfile.path)}');

      print('start copy');
      // fix
      final sourceFile = File(xfile.path);
      await sourceFile.copy(fileName);
      print('copy operation performed');
      final len = await File(fileName).length();
      print('fileName(copy) length: $len');
      await File(fileName).delete();
      print('delete(copy) operation performed');

      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content: Text('File.copy performed'),
              actions: [
                TextButton(
                    onPressed: () {
                      saveToOperation(xfile, fileName);
                      Navigator.of(context).pop();
                    },
                    child: Text('Test Xfile.saveTo'))
              ],
            );
          });
    } catch (e, t) {
      print(e);
      print(t);
    }
  }

  Future<void> saveToOperation(XFile xfile, String fileName) async {
    try {
      print('start saveTo');
      // saveTO
      await xfile.saveTo(fileName);
      print('saveTo operation performed');

      final len = await File(fileName).length();
      print('fileName(saveTo) length: $len');

      await File(fileName).delete();
      print('delete(saveTo) operation performed');

      await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              content:
                  Text('XFile.saveTo performed, try to record longer movie'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text('Ok'),
                )
              ],
            );
          });

      await File(xfile.path).delete();
    } catch (e, t) {
      print(e);
      print(t);
      await File(xfile.path).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final aproxVideoLength = _aproxVideoLengthInMinutes();
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
              if (_totalMemory != null && _diskSpace < _totalMemory)
                Text('You do not have enough disk space'),
            ],
            if (_totalMemory != null)
              Text('Total memory size: ${_toMb(_totalMemory)} MB'),
            if (_freeMemory != null)
              Text('Free memory size: ${_toMb(_freeMemory)} MB'),
            if (_twelveSecondsSize != null)
              Text('12sec video has size: ${_toMb(_twelveSecondsSize)} MB'),
            if (_twelveSecondsSize != null)
              Text(
                  '1min video has size: ~ ${_toMb(_twelveSecondsSize * 5)} MB'),
            if (aproxVideoLength != null)
              Text('Record video longer than : $aproxVideoLength min'),
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
