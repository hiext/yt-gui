#!/usr/bin/env python3
"""AI clip analyzer sidecar for Hiext YT GUI.

Outputs a JSON manifest consumed by AiClipAnalyzerExecutor. Optional features:
- YOLO detections via ultralytics when --yolo-model is provided.
- Audio transcription via faster-whisper when --whisper-model is provided.
The script never downloads models by itself; point the flags at local models or
names that your Python environment already knows how to resolve.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass
class Transcript:
    start_ms: int
    end_ms: int
    text: str
    words: list[str]


@dataclass
class Detection:
    timestamp_ms: int
    label: str
    confidence: float
    bbox: list[float]
    track_id: str | None = None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--task-id", required=True)
    parser.add_argument("--source-task-id", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--yolo-model")
    parser.add_argument("--whisper-model")
    parser.add_argument("--sample-every", type=float, default=2.0)
    parser.add_argument("--min-clip-seconds", type=float, default=8.0)
    parser.add_argument("--max-clip-seconds", type=float, default=90.0)
    args = parser.parse_args()

    source = Path(args.input)
    duration_ms = probe_duration_ms(source)
    transcripts = transcribe(source, args.whisper_model)
    detections = detect_objects(source, args.yolo_model, args.sample_every)
    segments = build_segments(
        task_id=args.task_id,
        source=source,
        title=args.title,
        duration_ms=duration_ms,
        transcripts=transcripts,
        detections=detections,
        min_clip_ms=int(args.min_clip_seconds * 1000),
        max_clip_ms=int(args.max_clip_seconds * 1000),
    )

    print(
        json.dumps(
            {
                "schemaVersion": 1,
                "engine": "hiext-ai-clip-sidecar",
                "sourcePath": str(source),
                "segments": segments,
            },
            ensure_ascii=False,
        )
    )
    return 0


def probe_duration_ms(source: Path) -> int:
    if not shutil.which("ffprobe"):
        return 60000
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(source),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return max(1000, int(float(result.stdout.strip()) * 1000))
    except Exception as exc:  # pragma: no cover - diagnostic only
        print(f"ffprobe skipped: {exc}", file=sys.stderr)
        return 60000


def transcribe(source: Path, whisper_model: str | None) -> list[Transcript]:
    if not whisper_model:
        return []
    try:
        from faster_whisper import WhisperModel  # type: ignore
    except Exception as exc:
        print(f"faster-whisper unavailable: {exc}", file=sys.stderr)
        return []

    try:
        model = WhisperModel(whisper_model, compute_type="int8")
        segments, _info = model.transcribe(
            str(source),
            vad_filter=True,
            word_timestamps=True,
        )
        results: list[Transcript] = []
        for segment in segments:
            words = [
                getattr(word, "word", "").strip()
                for word in (getattr(segment, "words", None) or [])
                if getattr(word, "word", "").strip()
            ]
            text = getattr(segment, "text", "").strip()
            if not text:
                continue
            results.append(
                Transcript(
                    start_ms=int(float(segment.start) * 1000),
                    end_ms=int(float(segment.end) * 1000),
                    text=text,
                    words=words,
                )
            )
        return results
    except Exception as exc:
        print(f"whisper analysis skipped: {exc}", file=sys.stderr)
        return []


def detect_objects(
    source: Path,
    yolo_model: str | None,
    sample_every: float,
) -> list[Detection]:
    if not yolo_model:
        return []
    try:
        import cv2  # type: ignore
        from ultralytics import YOLO  # type: ignore
    except Exception as exc:
        print(f"YOLO dependencies unavailable: {exc}", file=sys.stderr)
        return []

    detections: list[Detection] = []
    try:
        model = YOLO(yolo_model)
        capture = cv2.VideoCapture(str(source))
        fps = capture.get(cv2.CAP_PROP_FPS) or 30
        frame_step = max(1, int(fps * sample_every))
        frame_index = 0
        while True:
            ok, frame = capture.read()
            if not ok:
                break
            if frame_index % frame_step == 0:
                timestamp_ms = int(frame_index / fps * 1000)
                for result in model(frame, verbose=False):
                    names = getattr(result, "names", {})
                    boxes = getattr(result, "boxes", None)
                    if boxes is None:
                        continue
                    for box in boxes:
                        cls = int(box.cls[0])
                        xyxy = [float(v) for v in box.xyxy[0].tolist()]
                        detections.append(
                            Detection(
                                timestamp_ms=timestamp_ms,
                                label=str(names.get(cls, cls)),
                                confidence=float(box.conf[0]),
                                bbox=xyxy,
                            )
                        )
            frame_index += 1
        capture.release()
    except Exception as exc:
        print(f"YOLO analysis skipped: {exc}", file=sys.stderr)
    return detections


def build_segments(
    task_id: str,
    source: Path,
    title: str,
    duration_ms: int,
    transcripts: list[Transcript],
    detections: list[Detection],
    min_clip_ms: int,
    max_clip_ms: int,
) -> list[dict[str, Any]]:
    windows = transcript_windows(transcripts, duration_ms, min_clip_ms, max_clip_ms)
    segments: list[dict[str, Any]] = []
    for index, (start_ms, end_ms, text_items) in enumerate(windows, start=1):
        segment_id = f"{task_id}#segment-{index}"
        segment_detections = [
            detection
            for detection in detections
            if start_ms <= detection.timestamp_ms <= end_ms
        ]
        labels = sorted({d.label for d in segment_detections})
        transcript_text = " ".join(t.text for t in text_items).strip()
        keywords = sorted(set(labels + extract_keywords(transcript_text, title)))
        tags = []
        if labels:
            tags.append("yolo")
        if transcript_text:
            tags.append("whisper")
        if not tags:
            tags.append("fallback")
        confidence = 0.8 if labels and transcript_text else 0.55 if labels or transcript_text else 0.1
        reason_parts = []
        if labels:
            reason_parts.append("objects: " + ", ".join(labels[:6]))
        if transcript_text:
            reason_parts.append("speech segment")
        if not reason_parts:
            reason_parts.append("duration window")
        segments.append(
            {
                "id": segment_id,
                "startMs": start_ms,
                "endMs": end_ms,
                "title": f"{title} #{index}",
                "summary": transcript_text or f"Detected labels: {', '.join(labels)}" or source.name,
                "keywords": keywords,
                "tags": tags,
                "confidence": confidence,
                "reason": " + ".join(reason_parts),
                "detections": [
                    {
                        "timestampMs": d.timestamp_ms,
                        "label": d.label,
                        "confidence": d.confidence,
                        "bbox": d.bbox,
                        "trackId": d.track_id,
                    }
                    for d in segment_detections
                ],
                "transcripts": [
                    {
                        "startMs": t.start_ms,
                        "endMs": t.end_ms,
                        "text": t.text,
                        "words": t.words,
                    }
                    for t in text_items
                ],
            }
        )
    return segments


def transcript_windows(
    transcripts: list[Transcript],
    duration_ms: int,
    min_clip_ms: int,
    max_clip_ms: int,
) -> list[tuple[int, int, list[Transcript]]]:
    if not transcripts:
        count = max(1, math.ceil(duration_ms / max_clip_ms))
        return [
            (
                i * max_clip_ms,
                min(duration_ms, (i + 1) * max_clip_ms),
                [],
            )
            for i in range(count)
        ]

    windows: list[tuple[int, int, list[Transcript]]] = []
    current: list[Transcript] = []
    start_ms = transcripts[0].start_ms
    for item in transcripts:
        if current and item.end_ms - start_ms > max_clip_ms:
            windows.append((start_ms, max(current[-1].end_ms, start_ms + min_clip_ms), current))
            current = []
            start_ms = item.start_ms
        current.append(item)
    if current:
        windows.append((start_ms, max(current[-1].end_ms, start_ms + min_clip_ms), current))
    return windows


def extract_keywords(text: str, title: str) -> list[str]:
    tokens = []
    for raw in f"{title} {text}".replace("_", " ").split():
        token = raw.strip(".,!?;:()[]{}\"'").lower()
        if len(token) >= 3:
            tokens.append(token)
    return tokens[:20]


if __name__ == "__main__":
    raise SystemExit(main())
