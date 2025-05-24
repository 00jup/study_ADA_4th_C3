//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

import AVKit
import Foundation
import Speech

final class VoiceControlViewModel: BaseViewModel<VocieControlViewState> {
  var player: AVAudioPlayer?
  @Published var isPlaying = false
  @Published var totalTime: TimeInterval = 0.0
  @Published var currentTime: TimeInterval = 0.0
  @Published var isListening = false
  @Published var recognizedText = ""

  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var isClearingText = false

  var timer: Timer?

  init() {
    super.init(state: .init())
    guard let url = Bundle.main.url(forResource: "runWithIsla", withExtension: "mp3") else { return }
    setupAudio(withURL: url)
    requestPermissions()
  }

  deinit {
    stopListening()
  }

  private func requestPermissions() {
    SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
      DispatchQueue.main.async {
        if authStatus == .authorized {
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
              if granted {
                // 권한 허용 후 잠시 대기 후 시작
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                  self?.startListening()
                }
              }
            }
          }
        }
      }
    }
  }

  func startListening() {
    // 이미 실행 중이면 리턴
    guard !audioEngine.isRunning else { return }
    guard !isListening else { return }

    do {
      try startRecording()
      isListening = true
    } catch {
      print("Failed to start recording: \(error)")
      isListening = false
    }
  }

  func stopListening() {
    isListening = false

    // 안전하게 오디오 엔진 정지
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    recognitionTask?.cancel()
    recognitionTask = nil

    // 오디오 세션 복원
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playback, mode: .default, options: [])
      try audioSession.setActive(true)
    } catch {
      print("Error restoring audio session: \(error)")
    }
  }

  private func startRecording() throws {
    recognitionTask?.cancel()
    recognitionTask = nil

    // 오디오 세션 재설정으로 마이크 감도 향상
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])

    // 마이크 입력 최적화
    if audioSession.isInputGainSettable {
      try audioSession.setInputGain(1.0)
    }

    try audioSession.setActive(true)

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    let inputNode = audioEngine.inputNode
    guard let recognitionRequest = recognitionRequest else {
      throw NSError(domain: "SpeechRecognition", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
    }

    recognitionRequest.shouldReportPartialResults = true

    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
      DispatchQueue.main.async {
        if let result = result {
          self?.recognizedText = result.bestTranscription.formattedString
        }

        if error != nil || result?.isFinal == true {
          self?.restartListening()
        }
      }
    }

    // 마이크 입력 포맷 최적화
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    // 더 큰 버퍼 사이즈로 안정성 향상
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
      self?.recognitionRequest?.append(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()
  }

  func clearRecognizedText() {
    recognizedText = ""
  }

  private func restartListening() {
    guard isListening else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      if self.isListening {
        self.stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          self.startListening()
        }
      }
    }
  }

  private func setupAudio(withURL url: URL) {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])

      // 마이크 입력 게인 설정
      if audioSession.isInputGainSettable {
        try audioSession.setInputGain(1.0) // 최대 입력 게인
      }

      try audioSession.setActive(true)

      player = try AVAudioPlayer(contentsOf: url)
      player?.prepareToPlay()
      player?.volume = 1.0
      totalTime = player?.duration ?? 0.0
    } catch {
      print("Error loading audio: \(error)")
    }
  }

  func play() {
    guard let player else { return }
    isPlaying = true
    player.play()
    startTimer()
  }

  func pause() {
    guard let player else { return }
    isPlaying = false
    player.pause()
    stopTimer()
  }

  private func startTimer() {
    stopTimer()
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.updateProgress()
    }
  }

  private func stopTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func updateProgress() {
    guard let player else { return }

    currentTime = player.currentTime

    if !player.isPlaying {
      pause()
      currentTime = 0
    }
  }
}
