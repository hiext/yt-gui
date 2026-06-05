import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiext_yt_gui/core/models/app_models.dart';
import 'package:hiext_yt_gui/core/services/ai_clip_analyzer_executor.dart';

void main() {
  test('external analyzer manifest becomes structured clip segments', () async {
    final process = _FakeProcess(exitCodeValue: 0);
    String? executable;
    List<String>? arguments;
    final executor = AiClipAnalyzerExecutor(
      processRunner: (path, args) async {
        executable = path;
        arguments = args;
        return process;
      },
    );
    addTearDown(executor.dispose);
    final changes = <PostProcessTask>[];

    await executor.startTask(
      task: _task(),
      settings: _settings(
        aiAnalyzerCommand:
            'python3 tools/ai_clip_analyzer.py --yolo-model local.pt',
      ),
      onTaskChanged: changes.add,
    );
    process.addStdout('''
{
  "schemaVersion": 1,
  "segments": [
    {
      "startMs": 1200,
      "endMs": 9800,
      "title": "Coffee demo",
      "summary": "A person presents coffee beans",
      "keywords": ["coffee", "beans"],
      "tags": ["yolo", "whisper"],
      "confidence": 0.86,
      "reason": "person + speech",
      "detections": [
        {"timestampMs": 1500, "label": "person", "confidence": 0.91, "bbox": [1, 2, 3, 4]}
      ],
      "transcripts": [
        {"startMs": 1300, "endMs": 9000, "text": "fresh coffee beans", "words": ["fresh", "coffee", "beans"]}
      ]
    }
  ]
}
''');
    await process.close();
    await pumpEventQueue();

    expect(executable, 'python3');
    expect(arguments, containsAll(['--input', '/downloads/source.mp4']));
    expect(arguments, containsAll(['--task-id', 'post-1']));
    expect(changes.first.status, PostProcessStatus.running);
    expect(changes.last.status, PostProcessStatus.completed);
    final segment = changes.last.clipSegments.single;
    expect(segment.summary, 'A person presents coffee beans');
    expect(segment.detections.single.label, 'person');
    expect(segment.transcripts.single.text, 'fresh coffee beans');
  });

  test(
    'fallback segment keeps analysis chain searchable before sidecar is configured',
    () async {
      final executor = AiClipAnalyzerExecutor();
      addTearDown(executor.dispose);
      final changes = <PostProcessTask>[];

      await executor.startTask(
        task: _task(),
        settings: _settings(),
        onTaskChanged: changes.add,
      );

      expect(changes.last.status, PostProcessStatus.completed);
      expect(changes.last.clipSegments.single.tags, ['pending-ai-analysis']);
      expect(changes.last.clipSegments.single.confidence, lessThan(0.1));
    },
  );
}

PostProcessTask _task() {
  return PostProcessTask(
    id: 'post-1',
    sourceTaskId: 'download-1',
    title: 'Source Video',
    type: PostProcessTaskType.aiClipAnalysis,
    status: PostProcessStatus.queued,
    progress: 0,
    sourcePath: '/downloads/source.mp4',
    outputDirectory: '/downloads/source.mp4.clips',
  );
}

DownloadSettings _settings({String? aiAnalyzerCommand}) {
  return DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
    aiAnalyzerCommand: aiAnalyzerCommand,
  );
}

class _FakeProcess implements Process {
  _FakeProcess({required this.exitCodeValue});

  final int exitCodeValue;
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exit = Completer<int>();

  void addStdout(String text) {
    _stdout.add(text.codeUnits);
  }

  Future<void> close() async {
    await _stdout.close();
    await _stderr.close();
    if (!_exit.isCompleted) {
      _exit.complete(exitCodeValue);
    }
  }

  @override
  Future<int> get exitCode => _exit.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;
}
