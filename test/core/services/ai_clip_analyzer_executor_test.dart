import 'dart:async';
import 'dart:convert';
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
        provider: AiAnalysisProvider.externalCommand,
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
    'built-in analyzer creates structured local candidates before sidecar is configured',
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
      expect(changes.last.clipSegments, hasLength(3));
      expect(changes.last.clipSegments.first.tags, contains('built-in'));
      expect(changes.last.clipSegments.first.keywords, contains('source'));
      expect(changes.last.clipSegments.first.confidence, greaterThan(0.1));
    },
  );

  test('built-in visual strategy adds scene candidate detections', () async {
    final executor = AiClipAnalyzerExecutor();
    addTearDown(executor.dispose);
    final changes = <PostProcessTask>[];

    await executor.startTask(
      task: _task(),
      settings: _settings(mode: BuiltInClipAnalyzerMode.visualFocused),
      onTaskChanged: changes.add,
    );

    expect(changes.last.clipSegments, hasLength(4));
    expect(changes.last.clipSegments.first.tags, contains('visualFocused'));
    expect(
      changes.last.clipSegments.first.detections.single.label,
      'visual-scene-candidate',
    );
  });

  test('cloud endpoint receives candidates and returns manifest', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requestBodies = <Map<String, Object?>>[];
    unawaited(
      server.forEach((request) async {
        requestBodies.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>,
        );
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer token',
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'segments': [
              {
                'startMs': 3000,
                'endMs': 15000,
                'title': 'Cloud refined scene',
                'summary': 'Cloud model selected the product scene',
                'keywords': ['cloud', 'product'],
                'tags': ['cloud', 'llm'],
                'confidence': 0.92,
                'reason': 'cloud semantic refinement',
                'transcripts': [
                  {'startMs': 3200, 'endMs': 12000, 'text': 'cloud transcript'},
                ],
              },
            ],
          }),
        );
        await request.response.close();
      }),
    );
    final executor = AiClipAnalyzerExecutor();
    addTearDown(executor.dispose);
    final changes = <PostProcessTask>[];

    await executor.startTask(
      task: _task(),
      settings: _settings(
        provider: AiAnalysisProvider.cloudEndpoint,
        selectedAiCloudConfigId: 'custom-main',
        aiCloudConfigs: [
          AiCloudConfig(
            id: 'custom-main',
            vendor: AiCloudVendor.custom,
            name: 'Custom analyzer',
            endpoint: 'http://127.0.0.1:${server.port}/analyze',
            apiKey: 'token',
            model: 'clip-model',
          ),
        ],
      ),
      onTaskChanged: changes.add,
    );
    await pumpEventQueue();

    expect(requestBodies.single['model'], 'clip-model');
    expect(requestBodies.single['vendor'], 'custom');
    expect(requestBodies.single['builtInCandidates'], isA<List<Object?>>());
    expect(changes.last.status, PostProcessStatus.completed);
    expect(changes.last.clipSegments.single.title, 'Cloud refined scene');
    expect(changes.last.clipSegments.single.tags, ['cloud', 'llm']);
  });

  test(
    'cloud vendor profile sends chat request and parses model text',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requestBodies = <Map<String, Object?>>[];
      unawaited(
        server.forEach((request) async {
          requestBodies.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, Object?>,
          );
          expect(
            request.headers.value(HttpHeaders.authorizationHeader),
            'Bearer openai-token',
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': '''
```json
{
  "segments": [
    {
      "startMs": 5000,
      "endMs": 18000,
      "title": "LLM refined highlight",
      "summary": "OpenAI-compatible response",
      "keywords": ["llm"],
      "tags": ["cloud"],
      "confidence": 0.88,
      "reason": "semantic highlight"
    }
  ]
}
```
''',
                  },
                },
              ],
            }),
          );
          await request.response.close();
        }),
      );
      final executor = AiClipAnalyzerExecutor();
      addTearDown(executor.dispose);
      final changes = <PostProcessTask>[];

      await executor.startTask(
        task: _task(),
        settings: _settings(
          provider: AiAnalysisProvider.cloudEndpoint,
          selectedAiCloudConfigId: 'openai-main',
          aiCloudConfigs: [
            AiCloudConfig(
              id: 'openai-main',
              vendor: AiCloudVendor.openAI,
              name: 'OpenAI Main',
              endpoint: 'http://127.0.0.1:${server.port}/chat/completions',
              apiKey: 'openai-token',
              model: 'gpt-4o-mini',
            ),
          ],
        ),
        onTaskChanged: changes.add,
      );
      await pumpEventQueue();

      expect(requestBodies.single['model'], 'gpt-4o-mini');
      expect(requestBodies.single['messages'], isA<List<Object?>>());
      expect(requestBodies.single['response_format'], {'type': 'json_object'});
      expect(changes.last.status, PostProcessStatus.completed);
      expect(changes.last.clipSegments.single.title, 'LLM refined highlight');
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

DownloadSettings _settings({
  AiAnalysisProvider provider = AiAnalysisProvider.builtIn,
  BuiltInClipAnalyzerMode mode = BuiltInClipAnalyzerMode.balanced,
  String? aiAnalyzerCommand,
  String? aiCloudEndpoint,
  String? aiCloudApiKey,
  String? aiCloudModel,
  String? selectedAiCloudConfigId,
  List<AiCloudConfig> aiCloudConfigs = const [],
}) {
  return DownloadSettings(
    saveDirectory: '/downloads',
    downloadMode: DownloadMode.serial,
    concurrentCount: 1,
    defaultQuality: 'best',
    downloadSubtitles: false,
    downloadThumbnail: false,
    disclaimerAccepted: false,
    aiAnalysisProvider: provider,
    builtInClipAnalyzerMode: mode,
    aiAnalyzerCommand: aiAnalyzerCommand,
    aiCloudEndpoint: aiCloudEndpoint,
    aiCloudApiKey: aiCloudApiKey,
    aiCloudModel: aiCloudModel,
    selectedAiCloudConfigId: selectedAiCloudConfigId,
    aiCloudConfigs: aiCloudConfigs,
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
