//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

import SwiftUI

struct VoiceControlView: View {
  var body: some View {
    BaseView(
      create: { VoiceControlViewModel() }
    ) { viewModel, _ in
      VStack {
        Toolbar(title: "VoiceControl")

        VStack {
          HStack {
            Button {
              if viewModel.isPlaying {
                viewModel.pause()
              } else {
                viewModel.play()
              }
            } label: {
              Image(systemName: viewModel.isPlaying ? "pause.circle" : "play.circle")
                .font(.largeTitle)
            } // Button

            Slider(value: Binding(
              get: { viewModel.currentTime },
              set: { newValue in viewModel.currentTime = newValue }
            ), in: 0 ... viewModel.totalTime) { editing in
              if editing {
                if viewModel.isPlaying {
                  viewModel.pause()
                }
              } else {
                viewModel.player?.currentTime = viewModel.currentTime
                viewModel.play()
              }
            } // Slider
          } // HStack

          HStack {
            Text("\(formatTime(viewModel.currentTime))")
            Spacer()
            Text("\(formatTime(viewModel.totalTime))")
          } // HStack
        } // VStack
        .animation(.linear(duration: 0.1), value: viewModel.currentTime)
        .padding()

        Spacer()

        // 음성 인식 UI 추가
        VStack {
          Button {
            if viewModel.isListening {
              viewModel.stopListening()
            } else {
              viewModel.startListening()
            }
          } label: {
            Image(systemName: viewModel.isListening ? "mic.fill" : "mic")
              .font(.largeTitle)
              .foregroundColor(viewModel.isListening ? .red : .blue)
              .padding()

            Spacer()

            Button {
              print("Clear button pressed - Before: isListening = \(viewModel.isListening)")
              viewModel.clearRecognizedText()
              print("Clear button pressed - After: isListening = \(viewModel.isListening)")
            } label: {
              Image(systemName: "trash")
                .font(.title2)
                .foregroundColor(.red)
            }
            .disabled(viewModel.recognizedText.isEmpty)
            .padding()
          } // Button

          ScrollView {
            Text(viewModel.recognizedText.isEmpty ? "음성을 인식 중..." : viewModel.recognizedText)
              .padding()
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.gray.opacity(0.1))
              .cornerRadius(8)
          } // ScrollView
          .frame(height: 150)
        } // VStack
        .padding()

        Spacer()
      } // VStack
    } // BaseView
  }

  private func formatTime(_ time: TimeInterval) -> String {
    let seconds = Int(time) % 60
    let minutes = Int(time) / 60
    return String(format: "%02d:%02d", minutes, seconds)
  }
}

#Preview {
  BasePreview {
    VoiceControlView()
  } // BasePreview
}
