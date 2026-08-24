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

    /// What earlier passes of the recogniser already settled on.
    ///
    /// A recognition task ends for good once it reports a final result, which
    /// it does after a second or two of quiet. Listening carries on across
    /// those endings by starting a fresh task, so this holds the words from the
    /// ones before — otherwise every pause wiped what had been said.
    private var committed = ""

    var isAvailable: Bool { recogniser?.isAvailable ?? false }

    /// Asks for both permissions, then starts. Two are needed and they are
    /// separate prompts: one to record, one to transcribe.
    func start() async {
        guard !isListening else { return }
        errorMessage = nil
        transcript = ""
        committed = ""

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
            // Tear down whatever did start, or the next attempt inherits a
            // half-open engine and fails for a reason that has nothing to do
            // with it.
            teardown()
            errorMessage = "Couldn't start the microphone."
        }
    }

    func stop() {
        guard isListening || engine.isRunning else { return }
        isListening = false
        teardown()
    }

    // MARK: - Pieces

    /// Unwinds the engine, the tap and the session. Safe to call twice, and
    /// safe to call when only half of it ever started.
    private func teardown() {
        if engine.isRunning { engine.stop() }
        // Always, not only when the engine was running: a tap left installed
        // makes the next installTap throw.
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil

        // Hand the microphone back, or other audio in the app stays ducked.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

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
        // .duckOthers used to be passed here alongside .record. Ducking belongs
        // to a category that plays audio, and pairing it with a record-only
        // category made the configuration fail outright on some devices — the
        // microphone then reported that it "couldn't start" for no visible
        // reason. Bluetooth is allowed so a headset is a route rather than a
        // failure.
        try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        try startTask(with: recogniser)
    }

    /// Starts one recognition pass. Called again each time a pass finalises,
    /// for as long as the microphone is meant to be on.
    private func startTask(with recogniser: SFSpeechRecognizer) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keeps the audio on the phone when the phone can manage it.
        request.requiresOnDeviceRecognition = recogniser.supportsOnDeviceRecognition
        self.request = request

        let input = engine.inputNode
        input.removeTap(onBus: 0)

        // The hardware format is only meaningful once the session is active. A
        // route still settling reports zero channels, and installing a tap with
        // that format raises an exception Swift cannot catch — the app simply
        // disappears.
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "SpeechDictation", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "The microphone is not ready."])
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }

        task = recogniser.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let words = result.bestTranscription.formattedString
                    self.transcript = self.committed.isEmpty
                        ? words
                        : self.committed + " " + words
                }

                guard self.isListening else { return }

                if let error {
                    // Cancelling a task on the way out surfaces here too, and
                    // is not something to report to anyone.
                    let code = (error as NSError).code
                    let cancelled = code == 203 || code == 216 || code == 301
                    if !cancelled { self.errorMessage = "Dictation stopped unexpectedly." }
                    self.stop()
                    return
                }

                // A pass ended after a pause. Keep what it settled on and open
                // a new one, so a breath mid-sentence does not end dictation.
                if result?.isFinal == true {
                    self.committed = self.transcript
                    self.task = nil
                    self.request = nil
                    guard let recogniser = self.recogniser, recogniser.isAvailable else { return }
                    do {
                        try self.startTask(with: recogniser)
                    } catch {
                        self.stop()
                    }
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
    /// Whatever was already in the box when the microphone was switched on.
    /// Dictation used to assign straight over it, so speaking wiped a
    /// half-typed message rather than adding to it.
    @State private var textBeforeDictating = ""

    var body: some View {
        Button {
            Haptics.impact(.light)
            Task {
                if dictation.isListening {
                    dictation.stop()
                } else {
                    textBeforeDictating = text
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
            text = textBeforeDictating.isEmpty
                ? spoken
                : textBeforeDictating + " " + spoken
        }
        // Never leave the microphone open because someone navigated away.
        .onDisappear { dictation.stop() }
    }
}
