import AVFoundation
import UIKit

enum WorkoutTimerCueSettings {
    static let soundEnabledKey = "workout.timer.sound.enabled"
    static let hapticsEnabledKey = "workout.timer.haptics.enabled"

    static var isSoundEnabled: Bool {
        UserDefaults.standard.object(forKey: soundEnabledKey) == nil
            || UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    static var isHapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: hapticsEnabledKey) == nil
            || UserDefaults.standard.bool(forKey: hapticsEnabledKey)
    }
}

/// A lightweight cue player for an on-screen workout timer. Tones are generated
/// in memory, use the ambient audio category, and therefore do not interrupt
/// music or podcasts playing during a workout.
@MainActor
final class WorkoutTimerCuePlayer {
    static let shared = WorkoutTimerCuePlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    private init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func countdownTick() {
        if WorkoutTimerCueSettings.isSoundEnabled {
            playTone(frequency: 880, duration: 0.075, volume: 0.22)
        }
        if WorkoutTimerCueSettings.isHapticsEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    func phaseCompleted() {
        if WorkoutTimerCueSettings.isSoundEnabled {
            playTone(frequency: 1_320, duration: 0.22, volume: 0.32)
        }
        if WorkoutTimerCueSettings.isHapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private func playTone(frequency: Double, duration: Double, volume: Float) {
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return }

        buffer.frameLength = frameCount
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            // A short fade prevents clicks at the start and end of the cue.
            let progress = Double(frame) / Double(max(Int(frameCount) - 1, 1))
            let envelope = min(progress / 0.12, (1 - progress) / 0.18, 1)
            samples[frame] = Float(sin(2 * Double.pi * frequency * time))
                * volume
                * Float(max(envelope, 0))
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            if engine.isRunning == false {
                try engine.start()
            }
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // A timer must continue even when audio is unavailable (for example,
            // during an active phone call). Haptics remain an independent cue.
        }
    }
}
