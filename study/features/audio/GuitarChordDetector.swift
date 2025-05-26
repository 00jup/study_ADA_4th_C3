//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

import Accelerate
import AVFoundation
import Foundation

class GuitarChordDetector {
  // 개선된 코드 템플릿 (더 정확한 음향학적 특성 반영)
  private let chordTemplates: [String: [Float]] = [
    "C": [1.0, 0.0, 0.2, 0.0, 0.8, 0.0, 0.1, 0.9, 0.0, 0.0, 0.1, 0.0], // C-E-G
    "Dm": [0.0, 0.1, 0.9, 0.0, 0.0, 0.8, 0.0, 0.0, 0.2, 1.0, 0.0, 0.0], // D-F-A
    "Em": [0.0, 0.0, 0.1, 0.0, 0.9, 0.0, 0.0, 0.8, 0.0, 0.0, 0.2, 1.0], // E-G-B
    "F": [0.8, 0.0, 0.0, 0.1, 0.0, 1.0, 0.0, 0.0, 0.2, 0.9, 0.0, 0.0], // F-A-C
    "G": [0.2, 0.0, 0.8, 0.0, 0.0, 0.1, 0.0, 1.0, 0.0, 0.0, 0.3, 0.9], // G-B-D
    "Am": [0.9, 0.0, 0.0, 0.2, 0.0, 0.0, 0.1, 0.0, 0.8, 1.0, 0.0, 0.0], // A-C-E
    "Bdim": [0.0, 0.0, 0.8, 0.0, 0.0, 0.9, 0.0, 0.0, 0.1, 0.0, 0.2, 1.0], // B-D-F
    "A": [0.0, 0.1, 0.0, 0.2, 0.8, 0.0, 0.0, 0.1, 0.0, 1.0, 0.0, 0.0], // A-C#-E
    "D": [0.0, 0.0, 1.0, 0.0, 0.1, 0.0, 0.8, 0.0, 0.0, 0.9, 0.0, 0.0], // D-F#-A
    "E": [0.0, 0.0, 0.0, 0.1, 1.0, 0.0, 0.0, 0.2, 0.8, 0.0, 0.0, 0.9], // E-G#-B
  ]

  private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

  // 오디오 엔진
  private let audioEngine = AVAudioEngine()
  private var isRecording = false

  struct ChordResult {
    let chord: String
    let confidence: Float
    let allMatches: [(chord: String, confidence: Float)]
  }

  // MARK: - 파일에서 코드 감지
  func detectChord(from audioURL: URL) -> ChordResult? {
    do {
      let audioFile = try AVAudioFile(forReading: audioURL)
      let format = audioFile.processingFormat
      let frameCount = UInt32(audioFile.length)

      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        return nil
      }

      try audioFile.read(into: buffer)

      guard let channelData = buffer.floatChannelData?[0] else {
        return nil
      }

      let audioData = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
      return detectChord(from: audioData, sampleRate: Float(format.sampleRate))

    } catch {
      print("오디오 파일 읽기 오류: \(error)")
      return nil
    }
  }

  // MARK: - 오디오 배열에서 코드 감지
  func detectChord(from audioData: [Float], sampleRate: Float = 22050) -> ChordResult {
    // 1. 크로마 특성 추출
    let chromaFeatures = extractChromaFeatures(from: audioData, sampleRate: sampleRate)

    // 2. 코드 매칭
    return matchChord(chromaFeatures: chromaFeatures)
  }

  // MARK: - 크로마 특성 추출 (개선된 버전)
  private func extractChromaFeatures(from audioData: [Float], sampleRate: Float) -> [Float] {
    let frameSize = 4096 // 더 큰 프레임 크기로 주파수 해상도 향상
    let hopSize = 1024 // 오버랩 증가로 안정성 향상
    let frameCount = max(1, (audioData.count - frameSize) / hopSize + 1)

    var chromaSum = Array(repeating: Float(0), count: 12)
    var validFrames = 0

    for i in 0 ..< frameCount {
      let start = i * hopSize
      let end = min(start + frameSize, audioData.count)

      if end - start < frameSize {
        // 부족한 부분을 0으로 패딩
        var paddedFrame = Array(audioData[start ..< end])
        paddedFrame.append(contentsOf: Array(repeating: 0.0, count: frameSize - paddedFrame.count))

        let spectrum = performFFT(paddedFrame)
        let chroma = spectrumToChroma(spectrum, sampleRate: sampleRate)

        // 에너지 임계값 적용 (노이즈 필터링)
        let totalEnergy = chroma.reduce(0, +)
        if totalEnergy > 0.01 { // 최소 에너지 임계값
          for j in 0 ..< 12 {
            chromaSum[j] += chroma[j]
          }
          validFrames += 1
        }
        break
      }

      let frame = Array(audioData[start ..< end])
      let spectrum = performFFT(frame)
      let chroma = spectrumToChroma(spectrum, sampleRate: sampleRate)

      // 에너지 기반 가중치 적용
      let totalEnergy = chroma.reduce(0, +)
      if totalEnergy > 0.01 {
        for j in 0 ..< 12 {
          chromaSum[j] += chroma[j]
        }
        validFrames += 1
      }
    }

    // 평균 계산
    if validFrames > 0 {
      for i in 0 ..< 12 {
        chromaSum[i] /= Float(validFrames)
      }
    }

    // 로그 스케일 적용 (인간의 청각 특성 반영)
    for i in 0 ..< 12 {
      chromaSum[i] = log(1 + chromaSum[i] * 10)
    }

    return normalizeVector(chromaSum)
  }

  // MARK: - FFT 수행
  private func performFFT(_ frame: [Float]) -> [Float] {
    let n = frame.count
    let log2n = vDSP_Length(log2(Float(n)))

    guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
      return Array(repeating: 0, count: n / 2)
    }

    defer { vDSP_destroy_fftsetup(fftSetup) }

    var realPart = frame
    var imagPart = Array(repeating: Float(0), count: n)

    realPart.withUnsafeMutableBufferPointer { realPtr in
      imagPart.withUnsafeMutableBufferPointer { imagPtr in
        var complexBuffer = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
        vDSP_fft_zip(fftSetup, &complexBuffer, 1, log2n, FFTDirection(FFT_FORWARD))
      }
    }

    // 크기 계산 - complexBuffer 변수를 재사용
    var magnitudes = Array(repeating: Float(0), count: n / 2)
    realPart.withUnsafeMutableBufferPointer { realPtr in
      imagPart.withUnsafeMutableBufferPointer { imagPtr in
        var complexBuffer = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
        vDSP_zvmags(&complexBuffer, 1, &magnitudes, 1, vDSP_Length(n / 2))
      }
    }

    return magnitudes
  }

  // MARK: - 스펙트럼을 크로마로 변환 (개선된 버전)
  private func spectrumToChroma(_ spectrum: [Float], sampleRate: Float) -> [Float] {
    var chroma = Array(repeating: Float(0), count: 12)
    let binCount = spectrum.count
    let nyquist = sampleRate / 2.0

    // 기타 주파수 범위에 특화된 가중치
    for bin in 1 ..< binCount {
      let freq = Float(bin) * nyquist / Float(binCount)

      // 기타 주파수 범위 (82.4Hz ~ 1318.5Hz) + 배음 고려
      if freq >= 80, freq <= 4000 {
        // A4 = 440Hz 기준으로 MIDI 노트 계산
        let noteNum = 12.0 * log2(freq / 440.0) + 69.0
        let chromaClass = Int(noteNum.rounded()) % 12
        let chromaClassPositive = chromaClass >= 0 ? chromaClass : chromaClass + 12

        if chromaClassPositive >= 0, chromaClassPositive < 12 {
          // 주파수 범위별 가중치 적용
          var weight: Float = 1.0

          // 기본 주파수 범위 (높은 가중치)
          if freq >= 82, freq <= 1320 {
            weight = 2.0
          }
          // 2차 배음 범위 (중간 가중치)
          else if freq >= 164, freq <= 2640 {
            weight = 1.5
          }
          // 3차 배음 범위 (낮은 가중치)
          else if freq >= 246, freq <= 3960 {
            weight = 1.2
          }

          // 기타 특성 주파수 강조
          let guitarFreqs: [Float] = [82.41, 110.00, 146.83, 196.00, 246.94, 329.63] // E2, A2, D3, G3, B3, E4
          for guitarFreq in guitarFreqs {
            if abs(freq - guitarFreq) < 5.0 {
              weight *= 1.5
            }
          }

          chroma[chromaClassPositive] += spectrum[bin] * weight
        }
      }
    }

    // 적응적 정규화 (상대적 강도 보존)
    let maxValue = chroma.max() ?? 0
    if maxValue > 0 {
      for i in 0 ..< 12 {
        chroma[i] = chroma[i] / maxValue
      }
    }

    return chroma
  }

  // MARK: - 벡터 정규화
  private func normalizeVector(_ vector: [Float]) -> [Float] {
    let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
    return norm > 0 ? vector.map { $0 / norm } : vector
  }

  // MARK: - 코드 매칭 (개선된 버전)
  private func matchChord(chromaFeatures: [Float]) -> ChordResult {
    var matches: [(chord: String, confidence: Float)] = []

    for (chordName, template) in chordTemplates {
      let normalizedTemplate = normalizeVector(template)

      // 다중 유사도 메트릭 계산
      let cosineSimilarity = dotProduct(chromaFeatures, normalizedTemplate)
      let euclideanDistance = sqrt(zip(chromaFeatures, normalizedTemplate)
        .map { pow($0 - $1, 2) }.reduce(0, +))
      let normalizedEuclidean = max(0, 1.0 - euclideanDistance / sqrt(2.0))

      // 가중 평균으로 최종 신뢰도 계산
      let confidence = (cosineSimilarity * 0.7 + normalizedEuclidean * 0.3)

      matches.append((chord: chordName, confidence: confidence))
    }

    // 신뢰도 순으로 정렬
    matches.sort { $0.confidence > $1.confidence }

    // 임계값 적용 (너무 낮은 신뢰도는 Unknown으로 처리)
    let bestMatch = matches.first ?? (chord: "Unknown", confidence: 0.0)
    let finalChord = bestMatch.confidence > 0.3 ? bestMatch.chord : "Unknown"

    return ChordResult(
      chord: finalChord,
      confidence: bestMatch.confidence,
      allMatches: matches
    )
  }

  // MARK: - 내적 계산
  private func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count else { return 0 }
    var result: Float = 0
    vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))
    return result
  }

  // MARK: - 실시간 녹음 및 감지 (개선된 버전)
  func startRealTimeDetection(completion: @escaping (ChordResult) -> Void) {
    do {
      // 오디오 세션 설정
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
      try audioSession.setActive(true)
    } catch {
      print("오디오 세션 설정 실패: \(error)")
    }

    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    // 더 큰 버퍼 크기로 안정성 향상
    inputNode.installTap(onBus: 0, bufferSize: 8192, format: recordingFormat) { [weak self] buffer, _ in
      guard let self = self,
            let channelData = buffer.floatChannelData?[0] else { return }

      let frameLength = Int(buffer.frameLength)
      let audioData = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

      // 신호 강도 체크 (너무 조용한 신호 필터링)
      let rms = sqrt(audioData.map { $0 * $0 }.reduce(0, +) / Float(audioData.count))

      if rms > 0.001 { // 최소 신호 강도 임계값
        let result = self.detectChord(from: audioData, sampleRate: Float(recordingFormat.sampleRate))

        DispatchQueue.main.async {
          completion(result)
        }
      }
    }

    do {
      try audioEngine.start()
      isRecording = true
      print("실시간 감지 시작 (개선된 버전)")
    } catch {
      print("오디오 엔진 시작 실패: \(error)")
    }
  }

  func stopRealTimeDetection() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    isRecording = false
    print("실시간 감지 중지")
  }
}
