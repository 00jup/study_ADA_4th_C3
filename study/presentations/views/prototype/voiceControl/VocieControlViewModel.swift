//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.
import AVKit
import CoreML
import Foundation
import SoundAnalysis
import Speech

final class VoiceControlViewModel: BaseViewModel<VocieControlViewState> {
  var player: AVAudioPlayer?
  @Published var isPlaying = false
  @Published var totalTime: TimeInterval = 0.0
  @Published var currentTime: TimeInterval = 0.0
  @Published var isListening = false
  @Published var recognizedText = ""
  @Published var predictedLabel: String = ""
  @Published var confidence: Double = 0.0

  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var isClearingText = false

  private let analysisQueue = DispatchQueue(label: "SoundAnalysisQueue")
  private var analyzer: SNAudioStreamAnalyzer?
  private var resultsObserver: SNResultsObserving?

  var timer: Timer?

  init() {
    super.init(state: .init())
    guard let url = Bundle.main.url(forResource: "runWithIsla", withExtension: "mp3") else { return }
    setupAudio(withURL: url)
    setupSoundAnalyzer()
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
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    recognitionTask?.cancel()
    recognitionTask = nil

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

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
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

    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, time in
      self?.recognitionRequest?.append(buffer)
      self?.analyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
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
      if audioSession.isInputGainSettable {
        try audioSession.setInputGain(1.0)
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

  private func setupSoundAnalyzer() {
    let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
    analyzer = SNAudioStreamAnalyzer(format: inputFormat)
    resultsObserver = SoundResultObserver(viewModel: self)

    guard let model = try? SoundClassify(configuration: MLModelConfiguration()).model,
          let request = try? SNClassifySoundRequest(mlModel: model)
    else {
      print("❌ CoreML 모델 로딩 실패")
      return
    }

    try? analyzer?.add(request, withObserver: resultsObserver!)
  }

  func updatePrediction(_ label: String, confidence: Double) {
    DispatchQueue.main.async {
      self.predictedLabel = label
      self.confidence = confidence
      // 음성 명령 처리
      if confidence > 0.5 { // 신뢰도 임계값
        switch label {
        case "정지":
          if !self.isPlaying {
            self.play()
          }
        case "재생":
          if self.isPlaying {
            self.pause()
          }
        default:
          break
        }
      }
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
