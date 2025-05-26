//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

import Foundation

import SoundAnalysis

class SoundResultObserver: NSObject, SNResultsObserving {
  weak var viewModel: VoiceControlViewModel?

  init(viewModel: VoiceControlViewModel) {
    self.viewModel = viewModel
  }

  func request(_: SNRequest, didProduce result: SNResult) {
    guard let result = result as? SNClassificationResult else { return }

    // 🔹 전체 결과 콘솔 출력
    print("🎯 [분류 결과 전체 출력]")
    for classification in result.classifications {
      let percent = classification.confidence * 100
      print(" - \(classification.identifier): \(String(format: "%.2f", percent))%")
    }

    // 🔹 가장 높은 결과만 뷰모델에 전달
    if let best = result.classifications.first {
      viewModel?.updatePrediction(best.identifier, confidence: best.confidence)
    }
  }

  func request(_: SNRequest, didFailWithError error: Error) {
    print("❌ 분석 실패: \(error)")
  }

  func requestDidComplete(_: SNRequest) {}
}
