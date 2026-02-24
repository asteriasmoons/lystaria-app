//
//  OnboardingOverlay.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/10/26.
//


import SwiftUI


struct OnboardingOverlay: View {

    @EnvironmentObject var manager: OnboardingManager
    var anchors: [String: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in

            if manager.isShowing,
               let step = manager.currentStep,
               let anchor = anchors[step.targetID] {

                let frame = proxy[anchor]

                ZStack {

                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()

                        // Cut a clear circular hole in the dim overlay so the
                        // targeted icon stays fully visible instead of being
                        // covered by a white haze.
                        Circle()
                            .fill(Color.black)
                            .frame(
                                width: max(frame.width, frame.height) + 28,
                                height: max(frame.width, frame.height) + 28
                            )
                            .position(x: frame.midX, y: frame.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()

                    highlight(frame)

                    tooltip(frame: frame, step: step, containerSize: proxy.size)
                }
                .animation(.easeInOut, value: manager.currentStepIndex)
            }
        }
    }

    func highlight(_ frame: CGRect) -> some View {
        ZStack {
            // A soft translucent glow around the clear cutout so the target
            // feels highlighted without covering the icon itself.
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 10)
                .frame(
                    width: max(frame.width, frame.height) + 34,
                    height: max(frame.width, frame.height) + 34
                )
                .blur(radius: 10)

            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 20)
                .frame(
                    width: max(frame.width, frame.height) + 46,
                    height: max(frame.width, frame.height) + 46
                )
                .blur(radius: 18)
        }
        .position(x: frame.midX, y: frame.midY)
        .allowsHitTesting(false)
    }

    func tooltip(frame: CGRect, step: OnboardingStep, containerSize: CGSize) -> some View {

        // Estimated tooltip metrics used to decide whether the bubble
        // should appear above or below the highlighted icon.
        //
        // We keep these values simple and predictable so the onboarding
        // feels stable instead of jumping around unpredictably.
        let estimatedBubbleHeight: CGFloat = 140
        let verticalGap: CGFloat = 26
        let edgePadding: CGFloat = 20

        // Available space around the target icon.
        let spaceAbove = frame.minY
        let spaceBelow = containerSize.height - frame.maxY

        // Decide where the tooltip should go.
        //
        // Rule:
        // - Prefer below if there is enough room.
        // - Otherwise flip above.
        // - If neither side has ideal room, choose the side with more space.
        let showBelow: Bool = {
            if spaceBelow >= estimatedBubbleHeight + verticalGap + edgePadding {
                return true
            }

            if spaceAbove >= estimatedBubbleHeight + verticalGap + edgePadding {
                return false
            }

            return spaceBelow >= spaceAbove
        }()

        // Clamp the tooltip horizontally so it does not run off-screen.
        let bubbleWidth: CGFloat = 260
        let halfBubbleWidth = bubbleWidth / 2
        let clampedX = min(
            max(frame.midX, halfBubbleWidth + edgePadding),
            containerSize.width - halfBubbleWidth - edgePadding
        )

        // Position the tooltip either above or below the highlighted icon.
        let bubbleY = showBelow
            ? min(frame.maxY + verticalGap + estimatedBubbleHeight / 2,
                  containerSize.height - estimatedBubbleHeight / 2 - edgePadding)
            : max(frame.minY - verticalGap - estimatedBubbleHeight / 2,
                  estimatedBubbleHeight / 2 + edgePadding)

        return VStack(spacing: 0) {

            // When the tooltip is above the icon, the arrow should sit
            // underneath the bubble and point downward toward the target.
            if !showBelow {
                bubbleContent(step: step, width: bubbleWidth)

                TooltipArrow()
                    .fill(.ultraThinMaterial)
                    .frame(width: 22, height: 12)
                    .rotationEffect(.degrees(180))
                    .offset(x: arrowOffset(frame: frame, bubbleCenterX: clampedX, bubbleWidth: bubbleWidth))
            }

            // When the tooltip is below the icon, the arrow should sit
            // above the bubble and point upward toward the target.
            if showBelow {
                TooltipArrow()
                    .fill(.ultraThinMaterial)
                    .frame(width: 22, height: 12)
                    .offset(x: arrowOffset(frame: frame, bubbleCenterX: clampedX, bubbleWidth: bubbleWidth))

                bubbleContent(step: step, width: bubbleWidth)
            }
        }
        .position(x: clampedX, y: bubbleY)
    }

    func bubbleContent(step: OnboardingStep, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(step.title)
                .font(.headline)

            Text(step.message)
                .font(.subheadline)

            HStack(spacing: 10) {

                Button {
                    manager.dismiss()
                } label: {
                    Text("Dismiss")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 128/255, green: 0/255, blue: 254/255),
                                            Color(red: 0/255, green: 219/255, blue: 255/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    manager.next()
                } label: {
                    Text("Next")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 128/255, green: 0/255, blue: 254/255),
                                            Color(red: 0/255, green: 219/255, blue: 255/255)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding()
        .frame(width: width)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func arrowOffset(frame: CGRect, bubbleCenterX: CGFloat, bubbleWidth: CGFloat) -> CGFloat {

        // Keep the arrow visually aimed at the highlighted icon,
        // but prevent it from sliding too close to the bubble edges.
        let rawOffset = frame.midX - bubbleCenterX
        let maxOffset = (bubbleWidth / 2) - 26
        return min(max(rawOffset, -maxOffset), maxOffset)
    }
}

struct TooltipArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
