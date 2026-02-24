//
//  WelcomeView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/11/26.
//

import SwiftUI

struct WelcomePage: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
}

struct WelcomeFlowView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var currentPage = 0
    @State private var transitionEdge: Edge = .trailing
    
    private let pages: [WelcomePage] = [
        WelcomePage(
            title: "Welcome to Lystaria",
            description: "Lystaria is your personal space for reflection, growth, and daily rhythm. Capture thoughts, track your moods, build habits, and organize your life in one place.",
            imageName: "homefill"
        ),
        WelcomePage(
            title: "Capture your thoughts",
            description: "Create journal books and write freely using rich text editing. Organize entries with tags, generate daily prompts for inspiration, and easily copy passages with haptic feedback.",
            imageName: "notesfill"
        ),
        WelcomePage(
            title: "Emotions & Consistency",
            description: "Log your moods along with daily activities and optional notes. As you log more entries, Lystaria reveals insights about your most common moods and emotional patterns. Track habits and monitor your progress over time. Habit cards make it easy to log activity and view statistics that help reinforce daily momentum.",
            imageName: "facefill"
        ),
        WelcomePage(
            title: "Stay organized",
            description: "Create reminders and calendar events with flexible scheduling. Use recurring reminders, multiple alert times, and powerful event tracking to stay on top of important moments.",
            imageName: "bellfill"
        ),
        WelcomePage(
            title: "Grow through reading",
            description: "Track your reading streak, manage book lists, rate books, and generate summaries or recommendations whenever you need inspiration.",
            imageName: "bookopen"
        )
    ]
    
    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()
                .overlay(
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                )
            
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                
                HStack(spacing: 10) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(
                                index == currentPage
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 3/255, green: 219/255, blue: 252/255),
                                        Color(red: 125/255, green: 25/255, blue: 247/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color(red: 3/255, green: 219/255, blue: 252/255).opacity(0.35),
                                        Color(red: 125/255, green: 25/255, blue: 247/255).opacity(0.35)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: index == currentPage ? 24 : 10, height: 10)
                            .animation(.easeInOut(duration: 0.25), value: currentPage)
                    }
                }
                .padding(.bottom, 36)
                
                ZStack {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        if index == currentPage {
                            VStack(spacing: 24) {
                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.12))
                                        .frame(width: 110, height: 110)
                                        .overlay(
                                            Circle()
                                                .stroke(.white.opacity(0.18), lineWidth: 1)
                                        )
                                    
                                    Image(page.imageName)
                                        .renderingMode(.template)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 58, height: 58)
                                        .foregroundColor(.white)
                                }
                                .padding(.top, 10)
                                
                                VStack(spacing: 14) {
                                    Text(page.title)
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                    
                                    Text(page.description)
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                        .padding(.horizontal, 8)
                                }
                            }
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: transitionEdge).combined(with: .opacity),
                                    removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing).combined(with: .opacity)
                                )
                            )
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                Spacer()
                
                HStack(spacing: 14) {
                    Button(action: goBack) {
                        Text("Back")
                            .font(.headline)
                            .foregroundColor(.white.opacity(currentPage == 0 ? 0.45 : 1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 3/255, green: 219/255, blue: 252/255),
                                        Color(red: 125/255, green: 25/255, blue: 247/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .opacity(currentPage == 0 ? 0.35 : 1)
                            )
                            .clipShape(Capsule())
                    }
                    .disabled(currentPage == 0)
                    
                    Button(action: goNext) {
                        Text(currentPage == pages.count - 1 ? "Enter Lystaria" : "Next")
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 3/255, green: 219/255, blue: 252/255),
                                        Color(red: 125/255, green: 25/255, blue: 247/255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }
    
    private func goNext() {
        if currentPage < pages.count - 1 {
            transitionEdge = .trailing
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage += 1
            }
        } else {
            hasSeenWelcome = true
        }
    }
    
    private func goBack() {
        guard currentPage > 0 else { return }
        
        transitionEdge = .leading
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPage -= 1
        }
    }
}
