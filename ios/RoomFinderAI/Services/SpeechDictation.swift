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
    /// Set when the only way forward is the Settings app, so the alert can
    /// offer to open it rather than describing where to go.
    @Published var needsSettings = false

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

    /// Set once a pass has failed in a way that on-device recognition causes,
    /// so the retry asks Apple's servers instead. Dictation being switched off
    /// in Settings takes the on-device recogniser with it, and the failure that
    /// produces looks like a fault in the app rather than a setting on the
    /// phone.
    private var forceServerRecognition = false

    var isAvailable: Bool { recogniser?.isAvailable ?? false }

    /// Asks for both permissions, then starts. Two are needed and they are
    /// separate prompts: one to record, one to transcribe.
    func start() async {
        guard !isListening else { return }
        errorMessage = nil
        needsSettings = false
        transcript = ""
        committed = ""
        forceServerRecognition = false

        // requestPermissions sets its own message, which says which of the two
        // is missing. Replacing it here with one sentence covering both lost
        // exactly the detail the person needed.
        guard await requestPermissions() else { return }
        guard let recogniser else {
            errorMessage = "Dictation isn't available for this language (\(Locale.current.identifier))."
            return
        }
        guard recogniser.isAvailable else {
            // Usually means no network on a device that cannot transcribe
            // on-device, which is worth saying rather than leaving as a shrug.
            needsSettings = true
            errorMessage = "Dictation isn't available on this device yet.\n\nCheck that Settings → General → Keyboard → Enable Dictation is on, and that you have a connection."
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
            // The underlying reason is included on purpose. "Couldn't start the
            // microphone" alone is untestable from the outside: it is the same
            // sentence whether the session was misconfigured, the route was not
            // ready or the engine refused, and someone reporting the fault has
            // nothing to tell you.
            let reason = (error as NSError)
            errorMessage = "Couldn't start the microphone.\n(\(reason.domain) \(reason.code): \(reason.localizedDescription))"
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

    /// Asks for speech and then for the microphone.
    ///
    /// Both are checked before being asked for. iOS only ever shows each prompt
    /// once: after a refusal — or a prompt dismissed by a swipe — the request
    /// returns "denied" immediately and nothing appears on screen. Asking again
    /// therefore looks exactly like a button that does nothing, which is what
    /// it looked like, because the refusal was reported into a message the app
    /// never displayed.
    private func requestPermissions() async -> Bool {
        needsSettings = false

        var speech = SFSpeechRecognizer.authorizationStatus()
        if speech == .notDetermined {
            speech = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
        }
        guard speech == .authorized else {
            needsSettings = (speech == .denied || speech == .restricted)
            errorMessage = needsSettings
                ? "Speech Recognition is turned off for RoomFinderAI. Turn it on in Settings to talk instead of typing."
                : "Speech Recognition wasn't allowed."
            return false
        }

        let record = AVAudioApplication.shared.recordPermission
        if record == .granted { return true }
        guard record == .undetermined else {
            needsSettings = true
            errorMessage = "The Microphone is turned off for RoomFinderAI. Turn it on in Settings to talk instead of typing."
            return false
        }

        // A beat between the two system alerts. Presenting the second while the
        // first is still going away drops it, and the microphone prompt never
        // appears at all.
        try? await Task.sleep(for: .milliseconds(400))

        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        if !granted {
            needsSettings = true
            errorMessage = "The Microphone wasn't allowed. Turn it on in Settings to talk instead of typing."
        }
        return granted
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
        request.requiresOnDeviceRecognition =
            recogniser.supportsOnDeviceRecognition && !forceServerRecognition
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
                    let problem = error as NSError

                    // Cancelling a task on the way out surfaces here too, and
                    // is not something to report to anyone.
                    let cancelled = problem.code == 203 || problem.code == 216 || problem.code == 301
                    if cancelled { self.stop(); return }

                    // 201 and 1101/1107 all mean the on-device recogniser could
                    // not be used — most often because Dictation itself is
                    // switched off in Settings, which also removes the local
                    // speech assets. Apple's servers can still do it, so that
                    // is tried once before giving up.
                    let onDeviceUnavailable = problem.domain == "kAFAssistantErrorDomain"
                        && [201, 1101, 1107].contains(problem.code)

                    if onDeviceUnavailable, !self.forceServerRecognition,
                       let recogniser = self.recogniser {
                        self.forceServerRecognition = true
                        self.task = nil
                        self.request = nil
                        do {
                            try self.startTask(with: recogniser)
                            return
                        } catch {
                            // Falls through to the message below.
                        }
                    }

                    if onDeviceUnavailable {
                        // Settings has no public link to the Keyboard page, so
                        // the button can only open Settings itself and the way
                        // from there has to be spelled out.
                        self.needsSettings = true
                        self.errorMessage = "Dictation is turned off on this device.\n\nIn Settings, go to General → Keyboard and turn on Enable Dictation."
                    } else {
                        self.errorMessage = "Dictation stopped.\n(\(problem.domain) \(problem.code): \(problem.localizedDescription))"
                    }
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
        // Every one of these failures used to be silent: the microphone was set
        // to report a reason and nothing ever displayed it, so a dictation that
        // could not start looked like a button that flickered and did nothing.
        .alert("Dictation",
               isPresented: Binding(get: { dictation.errorMessage != nil },
                                    set: { if !$0 { dictation.errorMessage = nil } })) {
            if dictation.needsSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(dictation.errorMessage ?? "")
        }
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
