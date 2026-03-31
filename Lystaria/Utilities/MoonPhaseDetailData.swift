//
//  MoonPhaseDetailData.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/29/26.
//

import Foundation

struct MoonPhaseDetail {
    let phaseName: String
    let vibe: String
    let description: String
    let rituals: [String]
    let bestFor: [String]
}

enum MoonPhaseDetailData {
    static let all: [MoonPhaseDetail] = [
        MoonPhaseDetail(
            phaseName: "New Moon",
            vibe: "Quiet beginnings in the dark, where intention takes its first breath.",
            description: "The New Moon is a sacred void—an empty canvas where possibility hums beneath the surface. Emotionally, it can feel like a reset, a soft exhale after everything that was. Spiritually, this is where you plant seeds not just of goals, but of identity—who you are becoming before the world sees it.",
            rituals: [
                "Write your intentions and place them under a candle or pillow overnight",
                "Take a cleansing shower or bath and visualize old energy dissolving away"
            ],
            bestFor: [
                "Manifestation magick",
                "Setting intentions and new beginnings"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "Waxing Crescent",
            vibe: "Hope rising, like a spark catching flame.",
            description: "This phase carries momentum—small but powerful. Emotionally, it’s that fragile belief that maybe things can work out. Spiritually, you’re nurturing what you started, feeding your intentions with attention, effort, and quiet trust.",
            rituals: [
                "Speak your intentions out loud each morning like affirmations",
                "Light a candle daily to “grow” your desire energetically"
            ],
            bestFor: [
                "Attraction and drawing things in",
                "Building confidence and motivation"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "First Quarter",
            vibe: "Tension meets action—prove it to yourself.",
            description: "This is the push phase. Emotionally, it can feel challenging—like resistance or doubt creeping in—but that’s part of the alchemy. Spiritually, you’re being asked to act, to meet your intention halfway. This is where willpower becomes magick.",
            rituals: [
                "Do one bold action toward your goal, even if it scares you",
                "Write down obstacles and burn the paper to release them"
            ],
            bestFor: [
                "Courage and decision-making",
                "Breaking through blocks"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "Waxing Gibbous",
            vibe: "Refinement, focus, and quiet power building.",
            description: "You’re almost there, but not quite—and that’s intentional. Emotionally, this phase brings awareness to what needs tweaking. Spiritually, it’s about refinement, devotion, and trusting the process enough to adjust without giving up.",
            rituals: [
                "Journal what’s working vs. what needs to shift",
                "Clean or organize your space to align with your goal"
            ],
            bestFor: [
                "Fine-tuning manifestations",
                "Strengthening discipline and consistency"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "Full Moon",
            vibe: "Illumination, intensity, and emotional truth rising to the surface.",
            description: "The Full Moon is peak energy—everything is seen, everything is felt. Emotionally, it can be overwhelming or euphoric. Spiritually, it’s a mirror, revealing what’s aligned and what’s not. This is culmination, clarity, and powerful release.",
            rituals: [
                "Charge your tools or crystals under moonlight",
                "Write what you’re releasing and safely burn or tear it"
            ],
            bestFor: [
                "Release and banishing",
                "Divination and psychic work"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "Waning Gibbous",
            vibe: "Gratitude softens the intensity—harvest and reflect.",
            description: "After the peak comes integration. Emotionally, this phase feels like coming down, understanding what everything meant. Spiritually, it’s about gratitude and wisdom—recognizing what you’ve gained and honoring your growth.",
            rituals: [
                "Write a gratitude list for what has manifested or shifted",
                "Share knowledge, advice, or kindness with someone else"
            ],
            bestFor: [
                "Gratitude and appreciation magick",
                "Wisdom and teaching"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "Last Quarter",
            vibe: "Let go, even if it’s uncomfortable.",
            description: "This is the release of what no longer fits. Emotionally, it can feel like shedding skin—necessary, but not always easy. Spiritually, it’s a clearing phase, breaking attachments and making space for the next cycle.",
            rituals: [
                "Declutter a space or remove something that feels heavy",
                "Perform a cord-cutting or release visualization"
            ],
            bestFor: [
                "Banishing and protection",
                "Breaking habits or cycles"
            ]
        ),

        MoonPhaseDetail(
            phaseName: "Waning Crescent",
            vibe: "Deep rest, surrender, and sacred stillness.",
            description: "This is the exhale before rebirth. Emotionally, it’s quiet, introspective, sometimes even heavy—but in a healing way. Spiritually, this is a liminal space between worlds, where rest is not laziness, but preparation for transformation.",
            rituals: [
                "Meditate or sit in silence with no expectations",
                "Take a “do nothing” day and honor your energy"
            ],
            bestFor: [
                "Shadow work and healing",
                "Rest, restoration, and spiritual connection"
            ]
        )
    ]

    static func detail(for phaseName: String) -> MoonPhaseDetail? {
        all.first {
            $0.phaseName.lowercased() == normalizedPhaseName(phaseName).lowercased()
        }
    }

    private static func normalizedPhaseName(_ phaseName: String) -> String {
        switch phaseName.lowercased() {
        case "balsamic moon":
            return "Waning Crescent"
        default:
            return phaseName
        }
    }
}
