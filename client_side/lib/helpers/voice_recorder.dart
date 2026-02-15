import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';

class VoiceRecorder extends StatefulWidget {
  final Function(String path) onStop;
  final VoidCallback onCancel;

  const VoiceRecorder({
    super.key, 
    required this.onStop,
    required this.onCancel,
  });

  @override
  State<VoiceRecorder> createState() => _VoiceRecorderState();
}

class _VoiceRecorderState extends State<VoiceRecorder> {
  late AudioRecorder _audioRecorder;
  Timer? _timer;

  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _startRecording() async {
    try {
      bool hasPermission = false;
      
      if (kIsWeb) {
        hasPermission = await _audioRecorder.hasPermission();
      } else {
        final status = await Permission.microphone.request();
        hasPermission = status.isGranted;
      }

      if (hasPermission) {
        String path = '';
        if (!kIsWeb) {
           final dir = await getTemporaryDirectory();
           path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }
        
        // Start recording
        // On web, path is ignored/handled by the browser if empty? 
        // Actually for web we might need to rely on stream or default behavior.
        // record 5.x+ usually handles path='' as default logic (blob/temp).
        
        await _audioRecorder.start(
          const RecordConfig(), 
          path: path
        );
        
        setState(() {
          _recordDuration = 0;
        });


        _startTimer();
      } else {
        print("Microphone permission denied");
        widget.onCancel();
      }
    } catch (e) {
      print('Error starting recording: $e');
      widget.onCancel();
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();



    if (path != null) {
      widget.onStop(path);
    } else {
      widget.onCancel();
    }
  }
  
  void _cancelRecording() async {
     _timer?.cancel();
     await _audioRecorder.stop();
     widget.onCancel();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration++;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
           const Icon(Icons.mic, color: Colors.red, size: 24),
           const SizedBox(width: 12),
           Text(
             _formatDuration(_recordDuration),
             style: const TextStyle(
               fontSize: 16, 
               fontWeight: FontWeight.bold,
               color: Colors.red
             ),
           ),
           const Spacer(),
           TextButton(
             onPressed: _cancelRecording, 
             child: const Text('Cancel')
           ),
           const SizedBox(width: 8),
           CircleAvatar(
            backgroundColor: AppPrimaryColor,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _stopRecording,
            ),
           ),
        ],
      ),
    );
  }
}
