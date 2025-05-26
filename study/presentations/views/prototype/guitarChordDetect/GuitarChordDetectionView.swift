//  Copyright © 2025 ADA 4th Challenge3 Team1. All rights reserved.

import SwiftUI

struct GuitarChordDetectionView: View {
  var body: some View {
    BaseView(
      create: { GuitarChordDetectionViewModel() }
    ) { viewModel, state in
      VStack(spacing: 20) {
        // MARK: Toolbar
        Toolbar(title: "Guitar Chord Detection")

        Spacer()

        // MARK: Main Chord Display
        VStack(spacing: 16) {
          Text(state.currentChord)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundColor(chordColor(for: state.confidence))
            .multilineTextAlignment(.center)
            .animation(.easeInOut(duration: 0.3), value: state.currentChord)

          Text("신뢰도: \(Int(state.confidence * 100))%")
            .font(.title2)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemGray6))
            .shadow(radius: 4)
        )

        // MARK: Detection Button
        Button(action: {
          viewModel.toggleDetection()
        }) {
          HStack {
            Image(systemName: state.isDetecting ? "stop.circle.fill" : "play.circle.fill")
              .font(.title2)

            Text(state.isDetecting ? "감지 중지" : "감지 시작")
              .font(.title2)
              .fontWeight(.semibold)
          }
          .foregroundColor(.white)
          .padding(.horizontal, 32)
          .padding(.vertical, 16)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(state.isDetecting ? Color.red : Color.blue)
          )
        }
        .scaleEffect(state.isDetecting ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: state.isDetecting)

        // MARK: All Matches List
        if !state.allMatches.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("감지된 코드들")
              .font(.headline)
              .padding(.horizontal)

            ScrollView {
              LazyVStack(spacing: 4) {
                ForEach(Array(state.allMatches.enumerated()), id: \.offset) { index, match in
                  HStack {
                    Text(match.chord)
                      .font(.system(size: 16, weight: .medium))
                      .foregroundColor(index == 0 ? .primary : .secondary)

                    Spacer()

                    Text("\(Int(match.confidence * 100))%")
                      .font(.system(size: 14))
                      .foregroundColor(.secondary)

                    // Confidence Bar
                    GeometryReader { geometry in
                      RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 4)
                        .overlay(
                          RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(match.confidence), height: 4),
                          alignment: .leading
                        )
                    }
                    .frame(width: 60, height: 4)
                  }
                  .padding(.horizontal)
                  .padding(.vertical, 8)
                  .background(
                    index == 0 ? Color(.systemGray6) : Color.clear
                  )
                }
              }
            }
            .frame(maxHeight: 200)
          }
        }

        Spacer()
      }
    }
  }

  private func chordColor(for confidence: Float) -> Color {
    if confidence > 0.7 {
      return .green
    } else if confidence > 0.4 {
      return .orange
    } else {
      return .red
    }
  }
}

#Preview {
  BasePreview {
    GuitarChordDetectionView()
  }
}
