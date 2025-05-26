//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

import AVFoundation
import Foundation

final class GuitarChordDetectionViewModel: BaseViewModel<GuitarChordDetectionViewState> {
  private let detector = GuitarChordDetector()

  init() {
    super.init(state: .init(
      isDetecting: false,
      currentChord: "코드를 연주하세요",
      confidence: 0.0,
      allMatches: []
    ))

    requestMicrophonePermission()
  }

  deinit {
    stopDetection()
  }

  private func requestMicrophonePermission() {
    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        if !granted {
          self?.emit(self?.state.copy(currentChord: "마이크 권한이 필요합니다") ?? GuitarChordDetectionViewState())
        }
      }
    }
  }

  func toggleDetection() {
    if state.isDetecting {
      stopDetection()
    } else {
      startDetection()
    }
  }

  private func startDetection() {
    detector.startRealTimeDetection { [weak self] result in
      self?.updateChordResult(result)
    }

    emit(state.copy(
      isDetecting: true,
      currentChord: "감지 중...",
      confidence: 0.0
    ))
  }

  private func stopDetection() {
    detector.stopRealTimeDetection()

    emit(state.copy(
      isDetecting: false,
      currentChord: "코드를 연주하세요",
      confidence: 0.0,
      allMatches: []
    ))
  }

  private func updateChordResult(_ result: GuitarChordDetector.ChordResult) {
    emit(state.copy(
      currentChord: result.chord,
      confidence: result.confidence,
      allMatches: result.allMatches
    ))
  }
}
