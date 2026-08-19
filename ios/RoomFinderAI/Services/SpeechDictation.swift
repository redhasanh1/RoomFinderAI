import AVFoundation
import Foundation
import Speech
import SwiftUI

/// Turns speech into text for the chat composer.
///
/// Typing what you want out of a flat is a paragraph of work on a phone
/// keyboard, and it is the first thing anyone has to do here. Talking is
/// faster, and the text lands in the same box so it can still be corrected
/// before sending.
///
/// On-device where the phone supports it, which keeps what someone says about
/// their budget and their circumstances off Apple's servers.
@MainActor
final class SpeechDictation: NSObject, ObservableObject {

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""
    @Published var errorMessage: String?

    private let recogniser = SFSpeechRecognizer(locale: Locale.current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isAvailable: Bool { recogniser?.isAvailable ?? false }

    /// Asks for both permissions, then starts. Two are needed and they are
    /// separate prompts: one to record, one to transcribe.
    func start() async {
        guard !isListening else { return }
        errorMessage = nil
        transcript = ""

        guard await requestPermissions() else {
            errorMessage = "Allow the microphone and speech recognition in Settings to talk instead of typing."
            return
        }
        guard let recogniser, recogniser.isAvailable else {
            errorMessage = "Dictation isn't available right now."
            return
        }

        do {
            try beginSession(with: recogniser)
            isListening = true
        } catch {
            errorMessage = "Couldn't start the microphone."
            stop()
        }
    }

    func stop() {
        guard isListening || engine.isRunning else { return }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isListening = false

        // Hand the microphone back, or other audio in the app stays ducked.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Pieces

    private func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
    }

    private func beginSession(with recogniser: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keeps the audio on the phone when the phone can manage it.
        request.requiresOnDeviceRecognition = recogniser.supportsOnDeviceRecognition
        self.request = request

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                // A final result or a failure both mean this turn is over.
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }
}

/// A microphone that dictates into whatever text it is bound to.
///
/// One control, used by the negotiator chat, the room search and every message
/// thread, so talking works the same everywhere instead of existing in one
/// corner of the app.
struct DictationButton: View {

    @Binding var text: String
    var size: CGFloat = 30
    var isDisabled = false

    @StateObject private var dictation = SpeechDictation()

    var body: some View {
        Button {
            Haptics.impact(.light)
            Task {
                if dictation.isListening {
                    dictation.stop()
                } else {
                    await dictation.start()
                }
            }
        } label: {
            Image(systemName: dictation.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                .font(.system(size: size))
                .foregroundStyle(dictation.isListening
                                 ? AnyShapeStyle(.red)
                                 : AnyShapeStyle(Theme.brand))
                .symbolEffect(.pulse, isActive: dictation.isListening)
        }
        .disabled(isDisabled)
        .accessibilityLabel(dictation.isListening ? "Stop dictation" : "Talk instead of typing")
        .onChange(of: dictation.transcript) { _, spoken in
            guard !spoken.isEmpty else { return }
            text = spoken
        }
        // Never leave the microphone open because someone navigated away.
        .onDisappear { dictation.stop() }
    }
}
