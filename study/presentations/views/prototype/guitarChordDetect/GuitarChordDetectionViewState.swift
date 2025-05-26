//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

struct GuitarChordDetectionViewState {
  let isDetecting: Bool
  let currentChord: String
  let confidence: Float
  let allMatches: [(chord: String, confidence: Float)]

  init(
    isDetecting: Bool = false,
    currentChord: String = "코드를 연주하세요",
    confidence: Float = 0.0,
    allMatches: [(chord: String, confidence: Float)] = []
  ) {
    self.isDetecting = isDetecting
    self.currentChord = currentChord
    self.confidence = confidence
    self.allMatches = allMatches
  }

  func copy(
    isDetecting: Bool? = nil,
    currentChord: String? = nil,
    confidence: Float? = nil,
    allMatches: [(chord: String, confidence: Float)]? = nil
  ) -> GuitarChordDetectionViewState {
    return GuitarChordDetectionViewState(
      isDetecting: isDetecting ?? self.isDetecting,
      currentChord: currentChord ?? self.currentChord,
      confidence: confidence ?? self.confidence,
      allMatches: allMatches ?? self.allMatches
    )
  }
}
