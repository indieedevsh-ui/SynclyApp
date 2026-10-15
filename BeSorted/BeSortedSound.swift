//
//  BeSortedSound.swift
//  BeSorted
//

import AVFoundation
import AudioToolbox
import SwiftUI
import UIKit

@MainActor
enum BeSortedSound {
    enum Kind: Hashable {
        /// Zakładki (Moje projekty / Plan / Ustawienia oraz zakładki w projekcie).
        case tab
        /// Zwykłe przyciski UI (toolbar, glass, akcje).
        case regular
        /// Przyciski AI (sparkles).
        case ai
        /// Kafelki projektów i zadań — minimalistyczny „szklany” dźwięk.
        case tile
        /// Tick podczas „czytania” tekstu przez AI.
        case aiRead
        /// Dodanie zadania do projektu (ręcznie / zatwierdzenie propozycji AI).
        case taskAdd
        /// Dodanie zadania do Aktualnego Planu (AI / priorytet).
        case planAdd
        /// Smart Assistant Info — umiejętność dostępna (ptaszek).
        case skillYes
        /// Smart Assistant Info — umiejętność niedostępna (x).
        case skillNo
    }

    private static var players: [Kind: AVAudioPlayer] = [:]
    private static var aiReadSystemSound: SystemSoundID = 0
    private static var didConfigureSession = false
    private static var lastPlayAt: [Kind: Date] = [:]

    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpact = UIImpactFeedbackGenerator(style: .medium)

    static func play(_ kind: Kind) {
        configureSessionIfNeeded()

        let now = Date()
        let minGap: TimeInterval
        switch kind {
        case .aiRead: minGap = 0.028
        case .skillYes, .skillNo: minGap = 0.055
        case .taskAdd, .planAdd: minGap = 0.08
        default: minGap = 0.045
        }
        if let last = lastPlayAt[kind], now.timeIntervalSince(last) < minGap {
            return
        }
        lastPlayAt[kind] = now

        playHaptic(for: kind)

        if kind == .aiRead {
            playAIReadTick()
            return
        }

        // Odnów sesję przed zwykłymi dźwiękami — model AI potrafi ją przejąć.
        reactivateSessionIfNeeded()

        let player = players[kind] ?? makePlayer(for: kind)
        players[kind] = player
        player.currentTime = 0
        _ = player.play()
    }

    /// Natychmiast kończy odtwarzanie wskazanych dźwięków (np. sekwencja ✓/✗ w Informacjach).
    static func stop(_ kinds: Kind...) {
        for kind in kinds {
            players[kind]?.stop()
            players[kind]?.currentTime = 0
            lastPlayAt[kind] = nil
        }
    }

    /// SystemSound lepiej przechodzi przez równoległą sesję Foundation Models niż AVAudioPlayer.
    private static func playAIReadTick() {
        ensureAIReadSystemSound()
        if aiReadSystemSound != 0 {
            AudioServicesPlaySystemSound(aiReadSystemSound)
            return
        }
        reactivateSessionIfNeeded()
        let player = players[.aiRead] ?? makePlayer(for: .aiRead)
        players[.aiRead] = player
        player.volume = 0.4
        player.currentTime = 0
        _ = player.play()
    }

    private static func ensureAIReadSystemSound() {
        guard aiReadSystemSound == 0 else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("besorted-ai-read-soft-v3.wav")
        let data = wavData(for: .aiRead)
        do {
            try data.write(to: url, options: .atomic)
            var soundID: SystemSoundID = 0
            let status = AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
            if status == kAudioServicesNoError {
                aiReadSystemSound = soundID
            }
        } catch {
            // Zostanie fallback AVAudioPlayer.
        }
    }

    private static func playHaptic(for kind: Kind) {
        switch kind {
        case .regular:
            lightImpact.prepare()
            lightImpact.impactOccurred(intensity: 0.7)
        case .tab, .ai, .taskAdd, .planAdd:
            mediumImpact.prepare()
            mediumImpact.impactOccurred(intensity: kind == .planAdd || kind == .taskAdd ? 0.75 : 0.85)
        case .skillYes:
            lightImpact.prepare()
            lightImpact.impactOccurred(intensity: 0.45)
        case .skillNo:
            lightImpact.prepare()
            lightImpact.impactOccurred(intensity: 0.32)
        case .tile, .aiRead:
            break
        }
    }

    private static func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        lightImpact.prepare()
        mediumImpact.prepare()
        reactivateSessionIfNeeded()
        ensureAIReadSystemSound()
    }

    private static func reactivateSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        // `.playback` + mix — ticki słychać także gdy równolegle działa sesja modelu AI.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private static func makePlayer(for kind: Kind) -> AVAudioPlayer {
        let data = wavData(for: kind)
        if let player = try? AVAudioPlayer(data: data) {
            player.prepareToPlay()
            switch kind {
            case .ai: player.volume = 0.7
            case .tile: player.volume = 0.62
            case .aiRead: player.volume = 0.4
            case .taskAdd, .planAdd: player.volume = 0.78
            case .skillYes: player.volume = 0.48
            case .skillNo: player.volume = 0.42
            default: player.volume = 0.82
            }
            return player
        }
        let silent = synthesize(
            style: .mechanical,
            frequency: 440,
            duration: 0.01,
            volume: 0
        )
        // `synthesize` generuje WAV przez nas samych, więc dekoder praktycznie nie
        // zawiedzie — ale `try!` zamieniłby taki wyjątek w crash aplikacji.
        // Cisza zamiast crashu: dźwięk jest dodatkiem, nie funkcją krytyczną.
        if let fallback = try? AVAudioPlayer(data: silent) {
            fallback.prepareToPlay()
            fallback.volume = 0
            return fallback
        }
        if let existing = players[.regular] {
            return existing
        }
        // Ostateczność: `AVAudioPlayer(data:)` na pustych danych nie zawodzi.
        // Bez tego `?` zamieniłby pojedynczy błąd w ciche zamilkanie obsługi dźwięku.
        return (try? AVAudioPlayer(data: Data())) ?? AVAudioPlayer()
    }

    private static func wavData(for kind: Kind) -> Data {
        switch kind {
        case .regular:
            return synthesize(
                style: .mechanical,
                frequency: 780,
                duration: 0.028,
                volume: 0.62,
                noiseBurst: 0.55,
                metallicPartial: 2.75
            )
        case .tab:
            return synthesize(
                style: .mechanical,
                frequency: 1180,
                duration: 0.032,
                volume: 0.7,
                noiseBurst: 0.65,
                metallicPartial: 3.2
            )
        case .ai:
            return synthesize(
                style: .fluid,
                frequency: 740,
                duration: 0.14,
                volume: 0.42,
                chirpTo: 980
            )
        case .tile:
            return synthesize(
                style: .glass,
                frequency: 1640,
                duration: 0.16,
                volume: 0.38,
                chirpTo: 2100
            )
        case .aiRead:
            // Delikatny, spokojny „oddech” tonu — bez ostrego kliku.
            return synthesize(
                style: .readTick,
                frequency: 780,
                duration: 0.055,
                volume: 0.28,
                noiseBurst: 0
            )
        case .taskAdd:
            // Krótki, pozytywny „plink” — zadanie w projekcie.
            return synthesize(
                style: .confirm,
                frequency: 880,
                duration: 0.12,
                volume: 0.55,
                chirpTo: 1320
            )
        case .planAdd:
            // Nieco pełniejszy, szklany confirm — wejście do Aktualnego Planu.
            return synthesize(
                style: .confirm,
                frequency: 720,
                duration: 0.15,
                volume: 0.58,
                chirpTo: 1180
            )
        case .skillYes:
            // Lekki, przyjemny „pip” w górę — ptaszek.
            return synthesize(
                style: .confirm,
                frequency: 980,
                duration: 0.09,
                volume: 0.36,
                chirpTo: 1380
            )
        case .skillNo:
            // Miękki, krótki ton w dół — x (bez ostrego kliku).
            return synthesize(
                style: .fluid,
                frequency: 520,
                duration: 0.1,
                volume: 0.3,
                chirpTo: 360
            )
        }
    }

    private enum SynthStyle {
        case mechanical
        case fluid
        case glass
        case readTick
        case confirm
    }

    /// Minimalny WAV (PCM 16-bit mono 44.1 kHz) generowany w runtime.
    private static func synthesize(
        style: SynthStyle,
        frequency: Double,
        duration: Double,
        volume: Double,
        noiseBurst: Double = 0,
        metallicPartial: Double = 2.5,
        chirpTo: Double? = nil
    ) -> Data {
        let sampleRate = 44_100.0
        let sampleCount = max(1, Int(duration * sampleRate))
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(max(sampleCount - 1, 1))
            let sample: Double

            switch style {
            case .mechanical:
                let attack = min(1.0, progress / 0.012)
                let envelope = attack * exp(-progress * 42.0)
                let freq = frequency
                let phase = 2 * Double.pi * freq * t
                let square = phase.truncatingRemainder(dividingBy: 2 * Double.pi) < Double.pi ? 1.0 : -1.0
                let saw = 2.0 * ((freq * t).truncatingRemainder(dividingBy: 1.0)) - 1.0
                let metallic = sin(2 * Double.pi * freq * metallicPartial * t)
                let noiseWindow = progress < 0.07 ? (1.0 - progress / 0.07) : 0.0
                let noise = noiseBurst * Double.random(in: -1...1) * noiseWindow
                sample = (0.38 * square + 0.28 * saw + 0.22 * metallic + noise) * envelope * volume

            case .fluid:
                let attack = smoothstep(progress / 0.12)
                let release = smoothstep(1.0 - progress)
                let envelope = attack * release
                let freq: Double
                if let chirpTo {
                    let glide = smoothstep(progress)
                    freq = frequency + (chirpTo - frequency) * glide
                } else {
                    freq = frequency
                }
                let fundamental = sin(2 * Double.pi * freq * t)
                let softOver = 0.16 * sin(2 * Double.pi * freq * 1.5 * t)
                sample = (fundamental + softOver) * envelope * volume

            case .glass:
                let attack = min(1.0, progress / 0.018)
                let envelope = attack * exp(-progress * 9.5)
                let base = frequency
                let bright = chirpTo ?? (frequency * 1.28)
                let ring1 = sin(2 * Double.pi * base * t)
                let ring2 = 0.42 * sin(2 * Double.pi * bright * t)
                let ring3 = 0.18 * sin(2 * Double.pi * base * 2.15 * t)
                let shimmer = 0.1 * sin(2 * Double.pi * (base * 2.71) * t) * exp(-progress * 14.0)
                sample = (ring1 + ring2 + ring3 + shimmer) * envelope * volume

            case .readTick:
                // Miękki sinus, wolniejszy atak i dłuższe wybrzmienie — spokojne tło czytania.
                let attack = softstep(progress / 0.28)
                let release = exp(-progress * 11.0)
                let envelope = attack * release
                let tone = sin(2 * Double.pi * frequency * t)
                let softOver = 0.1 * sin(2 * Double.pi * frequency * 1.4 * t)
                sample = (tone + softOver) * envelope * volume

            case .confirm:
                // Dwa miękkie tony w górę — „dodano”.
                let attack = smoothstep(progress / 0.06)
                let release = smoothstep(1.0 - progress)
                let envelope = attack * release
                let glide = smoothstep(min(1.0, progress / 0.55))
                let freq = frequency + ((chirpTo ?? frequency * 1.4) - frequency) * glide
                let fundamental = sin(2 * Double.pi * freq * t)
                let glassPartial = 0.22 * sin(2 * Double.pi * freq * 2.02 * t)
                sample = (fundamental + glassPartial) * envelope * volume
            }

            let clipped = max(-1.0, min(1.0, sample))
            samples.append(Int16(clipped * Double(Int16.max)))
        }

        return pcm16MonoWAV(samples: samples, sampleRate: sampleRate)
    }

    private static func softstep(_ x: Double) -> Double {
        // Delikatniejszy niż klasyczny smoothstep — wolniejszy atak.
        let t = max(0.0, min(1.0, x))
        return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
    }

    private static func smoothstep(_ x: Double) -> Double {
        let t = max(0.0, min(1.0, x))
        return t * t * (3.0 - 2.0 * t)
    }

    private static func pcm16MonoWAV(samples: [Int16], sampleRate: Double) -> Data {
        let dataSize = samples.count * 2
        var data = Data()
        data.reserveCapacity(44 + dataSize)

        func appendASCII(_ string: String) {
            data.append(contentsOf: string.utf8)
        }
        func appendUInt16(_ value: UInt16) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        func appendUInt32(_ value: UInt32) {
            var v = value.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }

        appendASCII("RIFF")
        appendUInt32(UInt32(36 + dataSize))
        appendASCII("WAVE")
        appendASCII("fmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(sampleRate * 2))
        appendUInt16(2)
        appendUInt16(16)
        appendASCII("data")
        appendUInt32(UInt32(dataSize))

        for sample in samples {
            var v = sample.littleEndian
            withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
        }
        return data
    }
}

// MARK: - Button styles / modifiers

struct BeSortedPlainButtonStyle: ButtonStyle {
    var sound: BeSortedSound.Kind = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Cała ramka / spacer w labelu ma być klikalna, nie tylko ikona/tekst.
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.88 : 1)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    BeSortedSound.play(sound)
                }
            }
    }
}

extension View {
    /// Dźwięk + haptyka przy tapnięciu (np. na `.glass` / `.glassProminent`).
    func besortedClick(_ kind: BeSortedSound.Kind) -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                BeSortedSound.play(kind)
            }
        )
    }
}
