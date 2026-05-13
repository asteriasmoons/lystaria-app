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
    var settings: UserSettings
    @State private var currentPage = 0
    @State private var transitionEdge: Edge = .trailing
    
    private let pages: [WelcomePage] = [
        WelcomePage(
            title: "Welcome to Lystaria",
            description: "Lystaria is your personal space for reflection, growth, and daily rhythm. Capture thoughts, track your moods, build habits, and organize your life — all in one place.",
            imageName: "homefill"
        ),
        WelcomePage(
            title: "Journal",
            description: "Write freely inside beautifully crafted journal books. Use block-based rich text editing, photo blocks, @mentions, and AI-generated prompts and analysis to inspire deeper reflection. Every entry is yours alone.",
            imageName: "lockheartjournal"
        ),
        WelcomePage(
            title: "Reading",
            description: "Build your reading life from the ground up. Track your streak, manage your book lists, log reading sessions with a built-in timer, set monthly and yearly goals, and get AI-powered summaries and recommendations. Sprint solo or read together with buddy reading rooms.",
            imageName: "flatbook"
        ),
        WelcomePage(
            title: "Calendar",
            description: "Keep track of every moment that matters. Create events with flexible scheduling, sync with Apple Calendar, share events with others, and view your days in a beautiful hour-by-hour layout.",
            imageName: "calhearts"
        ),
        WelcomePage(
            title: "Reminders",
            description: "Never miss what matters. Set recurring reminders with multiple alert times, snooze, complete, or skip them from your notifications, and get a clear overview of everything upcoming — all from a clean time-block view.",
            imageName: "bellfill"
        ),
        WelcomePage(
            title: "Health",
            description: "Stay connected to your body. Track your steps, water intake, sleep, exercise, and health metrics — all synced with HealthKit. Your wellness data lives alongside the rest of your life.",
            imageName: "healthfill"
        ),
        WelcomePage(
            title: "Documents",
            description: "Write beyond your journal. Create documents and notes with rich block editing, inline properties, tables, and code blocks. Organize everything into books and folders that make sense to you.",
            imageName: "linescard"
        ),
        WelcomePage(
            title: "Self Care Points",
            description: "Turn your daily habits into something to celebrate. Earn points for logging moods, completing habits, reading, and more. Watch your consistency build into something real.",
            imageName: "levelup"
        ),
        WelcomePage(
            title: "Spirituality",
            description: "Begin each day with intention. Pull a daily tarot or Lenormand card, read your horoscope, and set a daily intention to ground yourself before the day begins. Lystaria honors every dimension of who you are.",
            imageName: "fillcards"
        ),
        WelcomePage(
            title: "Mood & Habits",
            description: "Log your moods along with daily activities and optional notes. As you log more entries, Lystaria reveals insights about your most common moods and emotional patterns. Track habits and monitor your progress over time — habit cards make it easy to log activity and view statistics that reinforce daily momentum.",
            imageName: "deadeyes"
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
            settings.hasSeenWelcome = true
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
