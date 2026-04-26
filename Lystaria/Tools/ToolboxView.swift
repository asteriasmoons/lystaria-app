//
//  ToolboxView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import SwiftUI
import UIKit
import AVFoundation

struct ToolboxView: View {
    @State private var isBreathing = false
    @State private var phase: BreathingPhase = .ready
    @State private var scale: CGFloat = 0.82
    @State private var glowOpacity: Double = 0.18
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var thoughtToBurn = ""
    @State private var burnTextVisible = true
    @State private var flameSweepProgress: CGFloat = 0
    @State private var flameVisible = false
    @State private var burnMaskProgress: CGFloat = 0
    @State private var flameTrailProgress: CGFloat = 0
    @State private var ashOffset: CGFloat = 0
    @State private var isBurningThought = false
    @FocusState private var isThoughtEditorFocused: Bool
    private let maxThoughtCharacters = 120

    // Meditation timer
    @State private var meditationDuration: Int = 300 // seconds
    @State private var meditationRemaining: Int = 300
    @State private var meditationRunning: Bool = false
    @State private var meditationFinished: Bool = false
    @State private var meditationTask: Task<Void, Never>? = nil
    @State private var meditationShowCustomPicker: Bool = false
    @State private var meditationCustomMinutes: Int = 5
    @State private var meditationCustomSeconds: Int = 0
    @State private var meditationIsCustom: Bool = false
    private let meditationPresets: [(label: String, seconds: Int)] = [
        ("5 min", 300),
        ("10 min", 600),
        ("15 min", 900),
        ("20 min", 1200)
    ]

    private func triggerSoftHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerLightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerRepeatedBreathingHaptics(count: Int, duration: Double) {
        guard count > 0 else { return }

        // fast pulse taps instead of spreading across the phase
        let interval: Double = 0.08

        Task {
            for index in 0..<count {
                if Task.isCancelled { break }

                await MainActor.run {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.prepare()
                    generator.impactOccurred()
                }

                if index < count - 1 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                    } catch {
                        break
                    }
                }
            }
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissKeyboard()
                }

            ScrollView {
                VStack(spacing: 16) {
                    header

                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)

                    distractionLauncherCard
                    meditationTimerCard
                    breathingCard
                    thoughtBurnCard

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 14)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                TapGesture().onEnded {
                    dismissKeyboard()
                }
            )
        }
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onDisappear {
            stopBreathing()
            resetBurnAnimation()
            stopMeditationTimer()
        }
    }

    private var header: some View {
        HStack {
            GradientTitle(text: "Toolbox", font: .title.bold())
            Spacer()
        }
    }

    private var distractionLauncherCard: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        Image("bubblefill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            .foregroundStyle(.white)

                        GradientTitle(text: "Bubble Distraction", font: .system(size: 20, weight: .bold))
                    }

                    Text("A soothing sensory space with floating bubbles you can tap for soft release, motion, and gentle stimulation when your mind needs a break.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    NavigationLink {
                        BubbleDistractionView()
                    } label: {
                        HStack {
                            Spacer()

                            Text("Open Bubble Space")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            dismissKeyboard()
                            triggerLightHaptic()
                        }
                    )
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color(red: 0.22, green: 0.60, blue: 1.0).opacity(0.07),
                                    Color(red: 0.48, green: 0.26, blue: 1.0).opacity(0.06),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Ellipse()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.56),
                                            Color.white.opacity(0.20),
                                            Color.clear
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 28, height: 16)
                                .blur(radius: 0.25)
                                .offset(x: -16, y: -19)
                        )
                        .background(
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            LColors.accent.opacity(0.12),
                                            Color.blue.opacity(0.10),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 10,
                                        endRadius: 42
                                    )
                                )
                                .blur(radius: 11)
                        )
                        .shadow(color: LColors.accent.opacity(0.08), radius: 8, y: 3)
                        .frame(width: 88, height: 88)
                }
                .frame(width: 104, height: 104)
            }
        }
    }

    private var meditationTimerCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "timer")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Meditation Timer", font: .system(size: 20, weight: .bold))

                    Spacer()

                    if meditationFinished {
                        Text("Complete ✦")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                    }
                }

                Text("Set a silent timer for your meditation session. A gentle sound will chime when time is up.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Countdown ring + time display
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 6)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: meditationRunning || meditationFinished
                            ? CGFloat(meditationRemaining) / CGFloat(meditationDuration)
                            : 1)
                        .stroke(
                            LGradients.blue,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: meditationRemaining)

                    VStack(spacing: 2) {
                        Text(meditationTimeString)
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        if meditationFinished {
                            Text("done")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                // Preset chips — disabled while running
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(meditationPresets, id: \.seconds) { preset in
                            Button {
                                guard !meditationRunning else { return }
                                triggerLightHaptic()
                                meditationDuration = preset.seconds
                                meditationRemaining = preset.seconds
                                meditationFinished = false
                                meditationIsCustom = false
                                meditationShowCustomPicker = false
                            } label: {
                                Text(preset.label)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        !meditationIsCustom && meditationDuration == preset.seconds
                                            ? AnyShapeStyle(LGradients.blue)
                                            : AnyShapeStyle(Color.white.opacity(0.08))
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .opacity(meditationRunning ? 0.45 : 1)
                        }

                        // Custom chip
                        Button {
                            guard !meditationRunning else { return }
                            triggerLightHaptic()
                            withAnimation(.easeInOut(duration: 0.22)) {
                                meditationShowCustomPicker.toggle()
                            }
                            if !meditationShowCustomPicker && meditationIsCustom {
                                // keep custom active but close picker
                            }
                        } label: {
                            Text("Custom")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    meditationIsCustom
                                        ? AnyShapeStyle(LGradients.blue)
                                        : AnyShapeStyle(Color.white.opacity(0.08))
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .opacity(meditationRunning ? 0.45 : 1)
                    }
                }

                // Custom time picker
                if meditationShowCustomPicker {
                    VStack(spacing: 12) {
                        HStack(spacing: 0) {
                            VStack(spacing: 2) {
                                Text("MIN")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)

                                Picker("", selection: $meditationCustomMinutes) {
                                    ForEach(0..<120) { m in
                                        Text("\(m)")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipped()
                            }

                            Text(":")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.top, 14)

                            VStack(spacing: 2) {
                                Text("SEC")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)

                                Picker("", selection: $meditationCustomSeconds) {
                                    ForEach([0, 15, 30, 45], id: \.self) { s in
                                        Text(String(format: "%02d", s))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .tag(s)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 80, height: 100)
                                .clipped()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )

                        Button {
                            triggerLightHaptic()
                            let total = (meditationCustomMinutes * 60) + meditationCustomSeconds
                            guard total > 0 else { return }
                            meditationDuration = total
                            meditationRemaining = total
                            meditationFinished = false
                            meditationIsCustom = true
                            withAnimation(.easeInOut(duration: 0.22)) {
                                meditationShowCustomPicker = false
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Text("Set \(meditationCustomMinutes)m \(meditationCustomSeconds > 0 ? String(format: "%02ds", meditationCustomSeconds) : "")")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(meditationCustomMinutes == 0 && meditationCustomSeconds == 0)
                        .opacity(meditationCustomMinutes == 0 && meditationCustomSeconds == 0 ? 0.45 : 1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Start / Pause / Reset
                HStack(spacing: 10) {
                    Button {
                        triggerLightHaptic()
                        if meditationRunning {
                            pauseMeditationTimer()
                        } else {
                            startMeditationTimer()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(meditationRunning ? "Pause" : (meditationFinished ? "Restart" : "Begin Session"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        triggerLightHaptic()
                        resetMeditationTimer()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var meditationTimeString: String {
        let m = meditationRemaining / 60
        let s = meditationRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startMeditationTimer() {
        if meditationFinished {
            meditationRemaining = meditationDuration
            meditationFinished = false
        }
        guard meditationRemaining > 0 else { return }
        meditationRunning = true

        meditationTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                await MainActor.run {
                    if meditationRemaining > 0 {
                        meditationRemaining -= 1
                    }
                    if meditationRemaining == 0 {
                        meditationRunning = false
                        meditationFinished = true
                        playMeditationCompleteSound()
                        triggerMeditationCompleteHaptic()
                    }
                }
                if meditationRemaining == 0 { break }
            }
        }
    }

    private func pauseMeditationTimer() {
        meditationTask?.cancel()
        meditationTask = nil
        meditationRunning = false
    }

    private func stopMeditationTimer() {
        meditationTask?.cancel()
        meditationTask = nil
        meditationRunning = false
    }

    private func resetMeditationTimer() {
        stopMeditationTimer()
        meditationRemaining = meditationDuration
        meditationFinished = false
        meditationIsCustom = false
        meditationShowCustomPicker = false
    }

    private func playMeditationCompleteSound() {
        // Three ascending sine tones using AVAudioEngine to match the calm aesthetic
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44100
        let toneDuration: Double = 0.9
        let gapDuration: Double = 0.35
        let frequencies: [Double] = [440, 528, 660] // A4, C5ish (healing), E5

        let frameCountPerTone = AVAudioFrameCount(sampleRate * toneDuration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.connect(player, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            // Fall back to system sound if engine fails
            AudioServicesPlaySystemSound(1013)
            return
        }

        for (index, frequency) in frequencies.enumerated() {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCountPerTone) else { continue }
            buffer.frameLength = frameCountPerTone

            let channelData = buffer.floatChannelData![0]
            for frame in 0..<Int(frameCountPerTone) {
                let t = Double(frame) / sampleRate
                // Sine wave with smooth envelope (fade in/out)
                let envelope: Float
                let attack = 0.06
                let release = 0.18
                if t < attack {
                    envelope = Float(t / attack)
                } else if t > toneDuration - release {
                    envelope = Float((toneDuration - t) / release)
                } else {
                    envelope = 1.0
                }
                channelData[frame] = envelope * 0.38 * Float(sin(2 * Double.pi * frequency * t))
            }

            let offsetSamples = AVAudioFramePosition(
                Double(index) * (toneDuration + gapDuration) * sampleRate
            )
            let toneTime = AVAudioTime(sampleTime: offsetSamples, atRate: sampleRate)
            player.scheduleBuffer(buffer, at: toneTime, options: [], completionHandler: nil)
        }

        player.play()

        // Stop engine after all tones have played
        let totalDuration = Double(frequencies.count) * (toneDuration + gapDuration) + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            engine.stop()
        }
    }

    private func triggerMeditationCompleteHaptic() {
        // Three soft pulses to mirror the three tones
        let delays: [Double] = [0, 0.5, 1.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                let gen = UINotificationFeedbackGenerator()
                gen.prepare()
                gen.notificationOccurred(.success)
            }
        }
    }

    private var breathingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Image("balancefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Breathing Timer", font: .system(size: 20, weight: .bold))

                    Spacer()
                }

                Text("A gentle guided breathing space for grounding your body and softening your nervous system.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 230, height: 230)

                    Circle()
                        .fill(LGradients.blue.opacity(glowOpacity))
                        .blur(radius: 22)
                        .frame(width: 180, height: 180)
                        .scaleEffect(scale)

                    Circle()
                        .fill(LGradients.blue)
                        .frame(width: 150, height: 150)
                        .scaleEffect(scale)
                        .overlay(
                            Circle()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                        .shadow(color: LColors.accent.opacity(0.28), radius: 18, y: 8)

                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                phaseChips

                HStack(spacing: 10) {
                    Button {
                        if isBreathing {
                            triggerLightHaptic()
                            stopBreathing()
                        } else {
                            triggerLightHaptic()
                            startBreathing()
                        }
                    } label: {
                        HStack {
                            Spacer()

                            Text(isBreathing ? "Stop Session" : "Start Breathing")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        triggerLightHaptic()
                        resetBreathing()
                    } label: {
                        HStack {
                            Spacer()

                            Text("Reset")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var thoughtBurnCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Image("flamefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Burn It Away", font: .system(size: 20, weight: .bold))

                    Spacer()
                }

                Text("Type out a thought you want to release, then let it dissolve into the fire.")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .frame(height: 146)

                        GeometryReader { geometry in
                            let cardWidth = geometry.size.width
                            let flameWidth: CGFloat = 132
                            let flameHeight: CGFloat = 56
                            let flameTravelWidth = max(cardWidth - flameWidth, 1)
                            let flameX = (flameWidth / 2) + (flameTravelWidth * flameSweepProgress)

                            ZStack {
                                Text(thoughtToBurn.isEmpty ? "Your thought appears here" : thoughtToBurn)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(thoughtToBurn.isEmpty ? LColors.textSecondary : .white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                                    .mask(
                                        GeometryReader { textGeometry in
                                            let textWidth = textGeometry.size.width
                                            let revealWidth = max(textWidth - (textWidth * flameTrailProgress), 0)

                                            ZStack(alignment: .leading) {
                                                Rectangle()
                                                    .fill(Color.white)
                                                    .frame(width: revealWidth)
                                            }
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        }
                                    )
                                    .offset(y: ashOffset)
                                    .opacity(burnTextVisible ? 1 : 0)

                                if flameVisible && !thoughtToBurn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    SingleFlameShape()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 0.22, green: 0.60, blue: 1.0),
                                                    Color(red: 0.44, green: 0.26, blue: 1.0),
                                                    LColors.accent,
                                                    Color(red: 0.19, green: 0.06, blue: 0.50)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: flameWidth, height: flameHeight)
                                        .overlay(
                                            SingleFlameInnerShape()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.white.opacity(0.20),
                                                            Color(red: 0.55, green: 0.78, blue: 1.0).opacity(0.22),
                                                            Color.clear
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 62, height: 26)
                                                .offset(x: -14, y: -1)
                                        )
                                        .background(
                                            SingleFlameShape()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            LColors.accent.opacity(0.34),
                                                            Color.blue.opacity(0.24),
                                                            Color.clear
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: flameWidth * 0.92, height: flameHeight * 0.82)
                                                .blur(radius: 14)
                                        )
                                        .shadow(color: LColors.accent.opacity(0.28), radius: 10, y: 0)
                                        .position(x: flameX, y: geometry.size.height / 2)
                                        .transition(.opacity)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .frame(height: 146)
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )

                        TextEditor(
                            text: Binding(
                                get: { thoughtToBurn },
                                set: { newValue in
                                    thoughtToBurn = String(newValue.prefix(maxThoughtCharacters))
                                }
                            )
                        )
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .foregroundStyle(.white)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(minHeight: 110)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 10)
                            .focused($isThoughtEditorFocused)

                        if thoughtToBurn.isEmpty {
                            Text("Type a negative thought you want to release")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }

                        VStack {
                            Spacer()

                            HStack {
                                Spacer()

                                Text("\(thoughtToBurn.count)/\(maxThoughtCharacters)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                    }
                    .frame(minHeight: 110)
                    .padding(.bottom, 6)

                    HStack(spacing: 10) {
                        Button {
                            burnThought()
                        } label: {
                            HStack {
                                Spacer()

                                Text(isBurningThought ? "Burning..." : "Burn")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(thoughtToBurn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBurningThought)
                        .opacity(thoughtToBurn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                        Button {
                            thoughtToBurn = ""
                            resetBurnAnimation()
                        } label: {
                            HStack {
                                Spacer()

                                Text("Clear")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var phaseChips: some View {
        HStack(spacing: 8) {
            phaseChip(title: "Inhale 4", active: phase == .inhale)
            phaseChip(title: "Hold 4", active: phase == .hold)
            phaseChip(title: "Exhale 6", active: phase == .exhale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseChip(title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                active
                ? AnyShapeStyle(LGradients.blue)
                : AnyShapeStyle(Color.white.opacity(0.08))
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(LColors.glassBorder, lineWidth: 1)
            )
    }

    private func burnThought() {
        let trimmedThought = thoughtToBurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedThought.isEmpty, !isBurningThought else { return }

        thoughtToBurn = trimmedThought
        dismissKeyboard()
        isBurningThought = true
        burnTextVisible = true
        ashOffset = 0
        flameSweepProgress = 0
        burnMaskProgress = 0
        flameTrailProgress = 0

        withAnimation(.easeOut(duration: 0.12)) {
            flameVisible = true
        }

        withAnimation(.linear(duration: 2.15)) {
            flameSweepProgress = 1
            flameTrailProgress = 1
            burnMaskProgress = 1
        }

        withAnimation(.easeIn(duration: 0.22).delay(1.95)) {
            ashOffset = 6
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeOut(duration: 0.12)) {
                flameVisible = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.35) {
            thoughtToBurn = ""
            isBurningThought = false
            resetBurnAnimation()
        }
    }

    private func resetBurnAnimation() {
        burnTextVisible = true
        flameSweepProgress = 0
        flameVisible = false
        burnMaskProgress = 0
        flameTrailProgress = 0
        ashOffset = 0
        isBurningThought = false
    }

    private func startBreathing() {
        stopBreathing()
        isBreathing = true

        timerTask = Task {
            while !Task.isCancelled {
                await runPhase(.inhale, duration: 4, targetScale: 1.08, targetGlow: 0.32)
                if Task.isCancelled { break }

                await runPhase(.hold, duration: 4, targetScale: 1.08, targetGlow: 0.28)
                if Task.isCancelled { break }

                await runPhase(.exhale, duration: 6, targetScale: 0.82, targetGlow: 0.18)
            }
        }
    }

    private func stopBreathing() {
        timerTask?.cancel()
        timerTask = nil
        isBreathing = false
        phase = .ready

        withAnimation(.easeInOut(duration: 0.6)) {
            scale = 0.82
            glowOpacity = 0.18
        }
    }

    private func resetBreathing() {
        stopBreathing()
    }

    private func dismissKeyboard() {
        isThoughtEditorFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @MainActor
    private func runPhase(
        _ newPhase: BreathingPhase,
        duration: Double,
        targetScale: CGFloat,
        targetGlow: Double
    ) async {
        phase = newPhase
        switch newPhase {
        case .inhale:
            triggerRepeatedBreathingHaptics(count: 8, duration: duration)
        case .hold:
            triggerRepeatedBreathingHaptics(count: 1, duration: duration)
        case .exhale:
            triggerRepeatedBreathingHaptics(count: 12, duration: duration)
        case .ready:
            break
        }

        withAnimation(.easeInOut(duration: duration)) {
            scale = targetScale
            glowOpacity = targetGlow
        }

        do {
            try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        } catch { }
    }
}

private enum BreathingPhase: Equatable {
    case ready
    case inhale
    case hold
    case exhale
}


private struct SingleFlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let midY = height / 2

        path.move(to: CGPoint(x: width * 0.02, y: midY))
        path.addCurve(
            to: CGPoint(x: width * 0.18, y: height * 0.14),
            control1: CGPoint(x: width * 0.05, y: height * 0.20),
            control2: CGPoint(x: width * 0.10, y: height * -0.06)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.34, y: height * 0.32),
            control1: CGPoint(x: width * 0.24, y: height * 0.26),
            control2: CGPoint(x: width * 0.28, y: height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.54, y: height * 0.06),
            control1: CGPoint(x: width * 0.40, y: height * 0.08),
            control2: CGPoint(x: width * 0.46, y: height * -0.10)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.72, y: height * 0.28),
            control1: CGPoint(x: width * 0.60, y: height * 0.20),
            control2: CGPoint(x: width * 0.66, y: height * 0.10)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.94, y: height * 0.18),
            control1: CGPoint(x: width * 0.80, y: height * 0.12),
            control2: CGPoint(x: width * 0.88, y: height * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: width, y: midY),
            control1: CGPoint(x: width * 0.98, y: height * 0.28),
            control2: CGPoint(x: width, y: height * 0.36)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.92, y: height * 0.82),
            control1: CGPoint(x: width, y: height * 0.66),
            control2: CGPoint(x: width * 0.98, y: height * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.72, y: height * 0.70),
            control1: CGPoint(x: width * 0.88, y: height * 1.00),
            control2: CGPoint(x: width * 0.80, y: height * 0.84)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.50, y: height * 0.94),
            control1: CGPoint(x: width * 0.66, y: height * 0.90),
            control2: CGPoint(x: width * 0.58, y: height * 1.08)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.32, y: height * 0.68),
            control1: CGPoint(x: width * 0.44, y: height * 0.82),
            control2: CGPoint(x: width * 0.38, y: height * 0.88)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.14, y: height * 0.86),
            control1: CGPoint(x: width * 0.26, y: height * 0.92),
            control2: CGPoint(x: width * 0.20, y: height * 1.02)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.02, y: midY),
            control1: CGPoint(x: width * 0.08, y: height * 0.74),
            control2: CGPoint(x: width * 0.04, y: height * 0.68)
        )

        return path
    }
}

private struct SingleFlameInnerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let midY = height / 2

        path.move(to: CGPoint(x: width * 0.06, y: midY))
        path.addCurve(
            to: CGPoint(x: width * 0.24, y: height * 0.24),
            control1: CGPoint(x: width * 0.10, y: height * 0.22),
            control2: CGPoint(x: width * 0.16, y: height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.52, y: height * 0.18),
            control1: CGPoint(x: width * 0.32, y: height * 0.10),
            control2: CGPoint(x: width * 0.42, y: height * 0.04)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.70, y: midY),
            control1: CGPoint(x: width * 0.60, y: height * 0.28),
            control2: CGPoint(x: width * 0.66, y: height * 0.30)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.48, y: height * 0.74),
            control1: CGPoint(x: width * 0.66, y: height * 0.70),
            control2: CGPoint(x: width * 0.58, y: height * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.24, y: height * 0.62),
            control1: CGPoint(x: width * 0.40, y: height * 0.82),
            control2: CGPoint(x: width * 0.32, y: height * 0.78)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.06, y: midY),
            control1: CGPoint(x: width * 0.14, y: height * 0.54),
            control2: CGPoint(x: width * 0.10, y: height * 0.44)
        )

        return path
    }
}

#Preview {
    NavigationStack {
        ToolboxView()
            .preferredColorScheme(.dark)
    }
}
