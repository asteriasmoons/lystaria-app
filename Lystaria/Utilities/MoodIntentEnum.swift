//
//  MoodIntentEnum.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/12/26.
//

import AppIntents

enum MoodIntentValue: String, CaseIterable, AppEnum {
    case happy, content, inspired, productive, loved, grateful, optimistic, confident, motivated, proud
    case energized, hopeful, playful, satisfied
    case okay, neutral, reflective, distracted, confused, calm, thoughtful, mellow, settled
    case indifferent, reserved, detached, apathetic, composed
    case sad, irritated, disappointed, angry, insecure, overwhelmed, stressed, scared, lonely, discouraged
    case drained, frustrated, restless, defeated

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Mood"

    static var caseDisplayRepresentations: [MoodIntentValue: DisplayRepresentation] = [
        .happy: "Happy",
        .content: "Content",
        .inspired: "Inspired",
        .productive: "Productive",
        .loved: "Loved",
        .grateful: "Grateful",
        .optimistic: "Optimistic",
        .confident: "Confident",
        .motivated: "Motivated",
        .proud: "Proud",
        .energized: "Energized",
        .hopeful: "Hopeful",
        .playful: "Playful",
        .satisfied: "Satisfied",
        .okay: "Okay",
        .neutral: "Neutral",
        .reflective: "Reflective",
        .distracted: "Distracted",
        .confused: "Confused",
        .calm: "Calm",
        .thoughtful: "Thoughtful",
        .mellow: "Mellow",
        .settled: "Settled",
        .indifferent: "Indifferent",
        .reserved: "Reserved",
        .detached: "Detached",
        .apathetic: "Apathetic",
        .composed: "Composed",
        .sad: "Sad",
        .irritated: "Irritated",
        .disappointed: "Disappointed",
        .angry: "Angry",
        .insecure: "Insecure",
        .overwhelmed: "Overwhelmed",
        .stressed: "Stressed",
        .scared: "Scared",
        .lonely: "Lonely",
        .discouraged: "Discouraged",
        .drained: "Drained",
        .frustrated: "Frustrated",
        .restless: "Restless",
        .defeated: "Defeated"
    ]
}

enum MoodActivityIntentValue: String, CaseIterable, AppEnum {
    case friends, family, community, dating
    case hobby, creative, work, education, reading
    case hygiene, fitness, health
    case selfCare = "self-care"
    case mindfulness
    case chores, errands, shopping, baking
    case pets, nature
    case journaling, spirituality, religion
    case entertainment
    case socialMedia = "social-media"
    case tech

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Activity"

    static var caseDisplayRepresentations: [MoodActivityIntentValue: DisplayRepresentation] = [
        .friends: "Friends",
        .family: "Family",
        .community: "Community",
        .dating: "Dating",
        .hobby: "Hobby",
        .creative: "Creative",
        .work: "Work",
        .education: "Education",
        .reading: "Reading",
        .hygiene: "Hygiene",
        .fitness: "Fitness",
        .health: "Health",
        .selfCare: "Self Care",
        .mindfulness: "Mindfulness",
        .chores: "Chores",
        .errands: "Errands",
        .shopping: "Shopping",
        .baking: "Baking",
        .pets: "Pets",
        .nature: "Nature",
        .journaling: "Journaling",
        .spirituality: "Spirituality",
        .religion: "Religion",
        .entertainment: "Entertainment",
        .socialMedia: "Social Media",
        .tech: "Tech"
    ]
}
