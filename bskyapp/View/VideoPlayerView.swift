import AVKit
import SwiftUI
import UIKit

struct VideoPlayerView: View {
  let video: EmbedVideoViewItem
  @State private var isShowingPlayer = false

  var body: some View {
    ZStack {
      AsyncImage(url: video.thumbnailUrl) { image in
        image
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: 250, maxHeight: 250)
      } placeholder: {
        Rectangle()
          .fill(Color.gray.opacity(0.3))
          .frame(width: 250, height: 140)
      }

      Image(systemName: "play.circle.fill")
        .font(.system(size: 50))
        .foregroundColor(.white)
        .shadow(radius: 5)
    }
    .gesture(
      TapGesture().onEnded {
        isShowingPlayer = true
      }
    )
    .sheet(isPresented: $isShowingPlayer) {
      VideoPlayerSheet(video: video, isPresented: $isShowingPlayer)
    }
  }
}

private struct VideoPlayerSheet: View {
  let video: EmbedVideoViewItem
  @Binding var isPresented: Bool
  @State private var player: AVPlayer?

  var body: some View {
    VStack {
      if let player = player {
        VideoPlayer(player: player)
          .edgesIgnoringSafeArea(.horizontal)
      } else {
        ProgressView()
          .scaleEffect(1.5)
      }

      if let alt = video.alt, !alt.isEmpty {
        Text("alt: \(alt)")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.horizontal)
      }
    }
    .overlay(alignment: .topTrailing) {
      Button(action: {
        player?.pause()
        isPresented = false
      }) {
        Image(systemName: "xmark.circle.fill")
          .font(.largeTitle)
          .foregroundColor(.white)
          .background(Color.black.opacity(0.7))
          .clipShape(Circle())
          .shadow(radius: 5)
      }
      .padding(.trailing, 20)
      .padding(.top, 20)
      .scaleEffect(1.2)
    }
    .onAppear {
      UIApplication.shared.isIdleTimerDisabled = true
      if let url = video.playlistUrl {
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer
        avPlayer.play()
      }
    }
    .onDisappear {
      player?.pause()
      player = nil
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }
}
