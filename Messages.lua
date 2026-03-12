local addonName = ...
---@class MrMythicalAssistant
local MrMythicalAssistant = _G[addonName] or {}
_G[addonName] = MrMythicalAssistant

--- Table containing all available messages for different events
---@type table<string, string[]>
MrMythicalAssistant.messages = {
    PLAYER_DEAD = {
        "Ah. Yes. That mechanic.",
        "Fascinating decision-making, really.",
        "One does not simply ignore swirlies.",
        "Shall we pretend that pull didn't happen?",
        "Gravity is a harsh mistress, isn't it?",
        "A tactical reset, I presume?",
        "Brilliant performance. Truly.",
        "Obviously that was the healers fault, right?",
        "I see you enjoy the floor.",
        "The ground is a great place to lie down and think about your choices."
    },
    CHALLENGE_MODE_START = {
        "Another dungeon? Do try to be entertaining.",
        "A +%s? How ambitious.",
        "Time starts now. Don't disappoint me.",
        "Do try to keep up, darling.",
        "Oh good, cardio."
    },
    CHALLENGE_MODE_START_REPEAT = {
        "%s again. Your commitment to this hallway simulator is noted.",
        "Back into %s for attempt #%s. Ambition or amnesia?",
        "%s, round #%s. I do admire a stubborn adventurer.",
        "Another tour of %s. I'll pretend run #%s is the lucky one.",
        "%s again? Splendid. My monocle fogs at this level of dedication.",
        "Run #%s in %s. At this point you should charge the dungeon rent."
    },
    CHALLENGE_MODE_START_SWITCH_AFTER_REPEAT = {
        "Retiring %s after %s repeats, are we? Very well—%s awaits.",
        "You exhausted %s for %s repeats. Time to offend a fresh dungeon: %s.",
        "From %s (%s repeats) to %s. A dramatic pivot, finally.",
        "Farewell, %s. After %s repeats, we now inconvenience %s.",
        "%s survived your %s-repeat era. Let's see what %s does with you.",
        "New chapter: leaving %s after %s repeats and marching into %s."
    },
    CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN = {
        "Window shopping? You don't have this key.",
        "You opened the slot. Marvelous. Now where is the key?",
        "Planning to insert your imagination? You have no keystone for this dungeon.",
        "Do you enjoy staring at empty sockets?"
    },
    KEY_INSERTED = {
        "The key is set. Do try not to break it.",
        "Are you sure you're ready for this?",
        "A bold choice.",
        "The key is in. No pressure.",
        "Keystone slotted. Let's see if you can handle it."
    },
    TEST_BUTTON = {
        "Do not poke the unicorn.",
        "I am working, can't you see?",
        "Yes, yes, I'm here. Sophisticated as always."
    },
    CHALLENGE_MODE_COMPLETED = {
        "Finally. I was getting bored.",
        "It is done. Adequately.",
        "Not terrible. I've seen worse.",
        "Timed? Barely.",
        "Next time, try to be faster.",
        "Well, you made it. That's something.",
        "Congratulations on your victory. Try not to let it go to your head."
    },
    REPAIR_BILL_SELF = {
        "Repaired for %s. Expensive hobby, isn't it?",
        "Swirlies are not for standing in. That will be %s.",
        "Your armor is made of paper. %s deducted.",
        "%s? I suppose durability is optional for you.",
        "You paid %s to fix your mistakes. How very responsible of you.",
        "The repair bill is %s. I hope it was worth it."
    },
    REPAIR_BILL_GUILD = {
        "%s repair bill? Your guild master must hate you.",
        "Draining the guild bank of %s. How very altruistic.",
        "The guild pays %s for your incompetence. Charming.",
        "%s from the guild funds. Do you enjoy being a liability?",
        "Your guild paid %s to fix your mistakes. How very generous of them.",
        "The repair bill is %s. I hope it was worth it for your guildmates.",
    },
    PLAYER_LEVEL_UP = {
        "Level %s. How thrilling. Do try not to die immediately.",
        "Congratulations on level %s. I expect you'll still stand in fire.",
        "Level %s achieved. Your mediocrity evolves.",
        "You've reached level %s. Marginally less hopeless.",
        "Level %s. One step closer to disappointing people at max level.",
        "Ding! Level %s. Don't let it go to your head.",
        "Level %s obtained. Perhaps now you'll learn to interrupt.",
        "Welcome to level %s. Your competence remains... theoretical.",
        "Level %s. Try not to waste this moment of growth.",
        "Ah, level %s. A fresh opportunity for poor decision-making."
    }
}
