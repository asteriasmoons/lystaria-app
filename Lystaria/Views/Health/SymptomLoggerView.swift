//
//  SymptomLoggerView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/30/26.
//

import SwiftUI
import SwiftData

struct SymptomLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var limits = LimitManager.shared

    @Query(sort: \SymptomLog.date, order: .reverse)
    private var logs: [SymptomLog]

    @State private var showAddPopup = false
    @State private var showDetailPopup = false
    @State private var showDeleteConfirm = false
    @State private var selectedLog: SymptomLog? = nil

    // Add form state
    @State private var selectedSymptoms: [String] = []
    @State private var severity: Int = 0
    @State private var note: String = ""
    @State private var logDate: Date = Date()

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                header

                VStack(alignment: .leading, spacing: 18) {
                    overviewCard

                    if logs.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                            logCard(log)
                                .premiumLocked(!limits.canCreate(.symptomLogsTotal, currentCount: index).allowed)
                        }
                    }

                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }

            if showAddPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddPopup = false
                        }
                    }

                addPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }

            if showDetailPopup {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showDetailPopup = false
                        }
                    }

                detailPopup
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(11)
            }

            deleteConfirm
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Symptom Log", font: .title2.bold())
                Spacer()

                Button {
                    guard limits.canCreate(.symptomLogsTotal, currentCount: logs.count).allowed else { return }
                    resetForm()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showAddPopup = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                            .frame(width: 34, height: 34)

                        Image("wavyplus")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white.opacity(limits.canCreate(.symptomLogsTotal, currentCount: logs.count).allowed ? 1 : 0.4))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 20)
            .padding(.horizontal, LSpacing.pageHorizontal)

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.top, 6)
        }
    }

    // MARK: - Overview card

    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image("scopefill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)

                    GradientTitle(text: "Overview", size: 24)

                    Spacer()
                }

                HStack(spacing: 14) {
                    statBubble(title: "Total", value: logs.count)
                    statBubble(title: "This Week", value: logsThisWeek)
                }
            }
        }
    }

    private var logsThisWeek: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return logs.filter { $0.date >= startOfWeek }.count
    }

    private func statBubble(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.subheadline.weight(.bold))
                .foregroundStyle(LColors.textSecondary)

            Text("\(value)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LColors.glassBorder, lineWidth: 1))
    }

    // MARK: - Log card

    private func logCard(_ log: SymptomLog) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image("medcross")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                                .foregroundStyle(.white)

                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        if log.severity > 0, let label = SymptomLog.severityLabels[log.severity] {
                            cardInfoPill(
                                text: "Severity: \(label)",
                                fill: severityColor(log.severity).opacity(0.18)
                            )
                        }
                    }

                    Spacer()

                    Button {
                        selectedLog = log
                        showDeleteConfirm = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(LGradients.blue)
                                .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                                .frame(width: 34, height: 34)

                            Image("fulltrashfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if !log.symptoms.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(log.symptoms, id: \.self) { symptom in
                            cardInfoPill(text: symptom, fill: Color.white.opacity(0.08))
                        }
                    }
                }

                if !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(log.note)
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedLog = log
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showDetailPopup = true
            }
        }
    }

    private func symptomChip(_ symptom: String) -> some View {
        let selected = selectedSymptoms.contains(symptom)
        return Button {
            if selected {
                selectedSymptoms.removeAll { $0 == symptom }
            } else {
                selectedSymptoms.append(symptom)
            }
        } label: {
            Text(symptom)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? .white : LColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selected)
    }

    private func cardInfoPill(text: String, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LColors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(fill)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 1: return Color(red: 0.03, green: 0.86, blue: 0.99)
        case 2: return Color(red: 0.49, green: 0.90, blue: 0.40)
        case 3: return Color(red: 1.0, green: 0.80, blue: 0.20)
        case 4: return Color(red: 1.0, green: 0.55, blue: 0.20)
        case 5: return Color(red: 1.0, green: 0.25, blue: 0.35)
        default: return Color.white
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 12) {
                Text("No symptoms logged")
                    .foregroundStyle(.white)
                    .font(.headline)

                Text("Tap + to log how you're feeling today.")
                    .foregroundStyle(LColors.textSecondary)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Add popup

    private var addPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showAddPopup = false
                }
            },
            width: 560,
            heightRatio: 0.80,
            header: {
                GradientTitle(text: "Log Symptoms", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    // Date picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("DATE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LColors.textSecondary)

                        DatePicker("", selection: $logDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .colorScheme(.dark)
                            .foregroundStyle(.white)
                            .labelsHidden()
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))

                    // Symptom chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SYMPTOMS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LColors.textSecondary)

                        FlowLayout(spacing: 6) {
                            ForEach(SymptomLog.allSymptoms, id: \.self) { symptom in
                                symptomChip(symptom)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))

                    // Severity
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SEVERITY")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LColors.textSecondary)

                        VStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { level in
                                let selected = severity == level
                                Button {
                                    severity = selected ? 0 : level
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("\(level)")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundStyle(selected ? .white : LColors.textSecondary)
                                            .frame(width: 20, alignment: .center)

                                        Text(SymptomLog.severityLabels[level] ?? "")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(selected ? .white : LColors.textSecondary)

                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(selected ? severityColor(level).opacity(0.30) : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selected ? severityColor(level) : LColors.glassBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selected)
                            }
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NOTE (OPTIONAL)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(LColors.textSecondary)

                        TextField("Add a note...", text: $note, axis: .vertical)
                            .lineLimit(3...5)
                            .textInputAutocapitalization(.sentences)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                HStack(spacing: 12) {
                    LButton(title: "Cancel", style: .secondary) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showAddPopup = false
                        }
                    }

                    LButton(title: "Save", style: .gradient) {
                        saveLog()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    // MARK: - Detail popup

    private var detailPopup: some View {
        LystariaOverlayPopup(
            onClose: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    showDetailPopup = false
                }
            },
            width: 560,
            heightRatio: 0.65,
            header: {
                GradientTitle(text: "Symptom Entry", size: 28)
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    if let log = selectedLog {
                        detailRow(icon: "calendar", title: "Date", value: log.date.formatted(date: .long, time: .shortened))

                        if log.severity > 0 {
                            detailRow(
                                icon: "waveform.path.ecg",
                                title: "Severity",
                                value: "\(log.severity) — \(SymptomLog.severityLabels[log.severity] ?? "")"
                            )
                        }

                        if !log.symptoms.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SYMPTOMS")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(LColors.textSecondary)

                                FlowLayout(spacing: 6) {
                                    ForEach(log.symptoms, id: \.self) { s in
                                        cardInfoPill(text: s, fill: Color.white.opacity(0.08))
                                    }
                                }
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
                        }

                        if !log.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            detailRow(icon: "note.text", title: "Note", value: log.note)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)
            },
            footer: {
                HStack(spacing: 12) {
                    LButton(title: "Delete", style: .secondary) {
                        showDetailPopup = false
                        showDeleteConfirm = true
                    }

                    LButton(title: "Close", style: .gradient) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            showDetailPopup = false
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        )
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(LColors.textSecondary)

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }

            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(LColors.glassBorder, lineWidth: 1))
    }

    // MARK: - Delete confirm

    private var deleteConfirm: some View {
        Color.clear
            .lystariaAlertConfirm(
                isPresented: $showDeleteConfirm,
                title: "Delete Entry",
                message: "Are you sure you want to delete this symptom entry?",
                confirmTitle: "Delete",
                confirmRole: .destructive,
                onConfirm: {
                    if let log = selectedLog {
                        modelContext.delete(log)
                        selectedLog = nil
                    }
                }
            )
    }

    // MARK: - Helpers

    private func resetForm() {
        selectedSymptoms = []
        severity = 0
        note = ""
        logDate = Date()
    }

    private func saveLog() {
        guard !selectedSymptoms.isEmpty else { return }

        let log = SymptomLog(
            symptoms: selectedSymptoms,
            severity: severity,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            date: logDate
        )
        modelContext.insert(log)
        resetForm()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            showAddPopup = false
        }
    }

}

// MARK: - FlowLayout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, x > 0 {
                    y += lineHeight + spacing
                    x = 0
                    lineHeight = 0
                }
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                maxX = max(maxX, x)
            }
            self.size = CGSize(width: maxX, height: y + lineHeight)
        }
    }
}
