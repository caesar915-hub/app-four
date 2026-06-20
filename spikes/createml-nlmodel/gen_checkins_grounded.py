#!/usr/bin/env python3
"""
gen_checkins_grounded.py — Replaces corpus_v2/checkins.json with a larger, vocabulary-
grounded synthetic corpus (300 check-ins vs the prior 90).

Vocabulary is adapted from real ADHD community sources found via web search 2026-06-19:
  1. adultingadhd.substack.com/p/have-the-meds-kicked-in-yet
  2. chaospalace.substack.com/p/last-week-bad-brain-days
  3. nikema.substack.com/p/my-brain-on-stimulants
  4. adhdmademedoit.substack.com/p/when-adhd-gives-you-brain-drain
  5. noenthuda.substack.com/p/working-on-scattered-days
  6. toolatesmart.substack.com/p/sorry-no-post-today
  7. mindmate.org.uk/adhd-starting-meds/
  8. latetomyownparty.substack.com/p/post-medication-things-i-now-celebrate
  9. adhdos.substack.com/p/how-to-survive-an-adhd-no-good-terrible

Sentences are adapted/paraphrased (not copied verbatim) to create natural first-person
voice-journal style training data. The structural generator (correlated states, temporal
pairs, negations, hypotheticals) is unchanged from gen_checkins.py.

Output: corpus_v2/ (same location, same format — feeds directly into collapse_and_split.py)
  python gen_checkins_grounded.py
"""

import json
import random
from pathlib import Path
from collections import Counter

OUT = Path(__file__).resolve().parent / "corpus_v2"
OUT.mkdir(exist_ok=True)
RNG = random.Random(20260619)  # different seed from gen_checkins.py

# ─────────────────────────────────────────────────────────────────────────────
# GROUNDED VOCABULARY BANKS
# All adapted from real ADHD community sources (see docstring above).
# Labels use the same 5-level space as gen_checkins.py; collapse_and_split.py
# maps these to 3 levels (low+flat→low, steady, alert+charged→alert, etc.).
# ─────────────────────────────────────────────────────────────────────────────

MOOD = {
    "low": [
        "feeling really low today",
        "everything is kind of weighing on me right now",
        "my mood is just all over the place",
        "felt flat and kind of hopeless for most of the day",
        "bit depressed honestly, nothing really lifted it",
        "really hard to stay positive today",
        "felt kind of gray all day, like nothing landed",
        "i just didn't feel good at all",
        "feeling down, more than usual",
        "the inner critic was loud today, just couldn't shake it",
        "spent a chunk of the day feeling bad about myself",
        "things feel heavy right now",
        "felt really disconnected from everything",
        "mood was rough from the moment i woke up",
        "nothing could lift me out of the funk",
        "feel kind of empty today",
        "more irritable than sad but definitely not okay",
        "really bad mood, snapped at people i didn't mean to",
        "felt like everything is hopeless, brain's broken kind of feeling",
        "couldn't access any positivity, just darkness",
        "that spiral of i didn't do enough today hit hard",
        "felt invisible and a bit useless today",
        "the guilt is overwhelming when the brain fog lifts",
        "mood tanked in the afternoon and didn't recover",
        "irritable and reactive, not a great version of me today",
        "couldn't shake this feeling of dread all day",
        "the emotional dysregulation was real today, crying at random things",
        "rejection sensitivity is through the roof today",
        "felt like a failure for most of the day",
        "can't stop catastrophising about everything",
        "feeling really fragile today, overstimulated and overwhelmed",
        "my mood is crashing hard, definitely the med rebound",
        "anxious and low at the same time, unpleasant combo",
        "beating myself up for not doing more today",
        "really struggling emotionally, everything feels too much",
        "the shame spiral kicked in around 3pm",
        "felt deeply unmotivated and a bit hopeless",
        "hard to care about anything today",
        "mood has been dark, can't really explain it",
        "struggling with feeling like i'm failing at everything",
    ],
    "flat": [
        "just felt kind of flat today, not sad but not good either",
        "kind of blah, nothing sparked",
        "emotionally muted today, not in a bad way just nothing there",
        "pretty neutral, couldn't really feel much",
        "meh kind of day emotionally",
        "went through the motions, nothing really clicked",
        "not sad but not happy, just existing",
        "a bit numb if i'm honest",
        "flat as a pancake today, mood-wise",
        "couldn't access much emotion today",
        "just going through the motions",
        "kind of gray and detached but not suffering",
        "emotionally kind of offline today",
        "nothing particularly good or bad, just neutral",
        "the muted feeling again, not sad just not really here",
        "going through the day on autopilot",
        "a bit dissociated but not in a distressing way",
        "nothing landing emotionally, positive or negative",
        "flat affect day, which is fine, just noticeable",
        "running in maintenance mode emotionally",
        "low-key today, nothing wrong but nothing right",
        "emotionally very quiet, like the signal is off",
        "just kind of there today, no strong feelings either way",
    ],
    "okay": [
        "mood is okay, nothing to write home about",
        "i'm okay, not great but managing",
        "not the best day emotionally but not terrible either",
        "muddling through, mood is fine",
        "pretty neutral today, which is actually fine",
        "can't complain, mood is decent",
        "average kind of day emotionally",
        "mood has been stable, which is something",
        "not up not down, just sort of okay",
        "feeling reasonably okay, considering",
        "doing alright, mood is steady enough",
        "things feel manageable today",
        "not great but not spiraling, i'll take it",
        "somewhere in the middle, which is honestly a win",
        "mood has been pretty solid actually",
        "emotionally even today, which i appreciate",
        "not complaining, things are okay",
        "middling day, mood nothing remarkable",
        "holding steady emotionally",
        "okay is actually good for me right now",
        "mood is fine, stable, no major wobbles",
        "things feel okay today, not forcing it",
        "coping well enough, mood on the okay side",
        "content enough, nothing great but nothing bad",
        "decent emotional day, stayed regulated",
    ],
    "good": [
        "actually felt happy today, which was nice",
        "genuinely in a pretty good mood",
        "felt upbeat for most of the day",
        "things feel okay in a real way, not forced",
        "surprised by how positive i've been",
        "good mood, not sure why but i'll take it",
        "feeling pretty optimistic today",
        "enjoyed myself today more than i expected",
        "mood has been good, things clicked",
        "felt light today, in a good way",
        "in a better headspace than i've been in a while",
        "genuinely like being me today, which is new",
        "had a good day and actually noticed it was good, which is rare",
        "things just felt right today",
        "positive and engaged, rare combo",
        "genuinely happy this afternoon, it snuck up on me",
        "walked into rooms with purpose and intention today",
        "felt like myself today, which is worth noting",
        "the good mood carried through the whole day",
        "energised and positive, good combination",
        "mood lifted after lunch and stayed up",
        "motivated and optimistic, not in a manic way, just good",
        "felt connected to what i was doing today",
        "laughed a lot today, which is a good sign",
        "felt proud of myself today, that doesn't happen often",
        "really enjoyed today, properly",
        "things clicking and mood matching",
        "feeling content and present",
        "genuinely a good day, not just coping",
    ],
    "great": [
        "best mood i've had in a while",
        "genuinely joyful today, actually giggled for a minute at something small",
        "feel amazing, everything just clicked emotionally",
        "so happy today, nothing could bring me down",
        "mood is brilliant, one of those rare good days",
        "couldn't stop smiling, everything felt right",
        "felt like myself, fully, for the first time in weeks",
        "euphoric almost, best day in a long time",
        "on top of the world today, rare feeling",
        "mood is exceptional, one of those days i want to remember",
        "happy from the moment i woke up, not sure why but accepting it",
        "genuinely thriving today, not just coping",
        "mood is as good as it gets, thoroughly enjoying this",
        "buzzing with positive energy, the good kind",
    ],
}

ENERGY = {
    "sluggish": [
        "barely got out of bed this morning",
        "running on fumes all day",
        "like my body was made of cement",
        "couldn't get going, just dragging myself through",
        "the lowest energy i've had in ages",
        "felt like i was moving through mud all day",
        "zero motivation to do anything physical",
        "just couldn't summon any energy at all",
        "my body refused to cooperate from the start",
        "barely functional today energy-wise",
        "completely depleted, no reserves left",
        "had nothing left in me",
        "zero in the tank today",
        "physically exhausted, couldn't do the most basic things",
        "even getting dressed felt like too much",
        "hit the mattress and couldn't move",
        "my energy was at absolute zero",
        "couldn't even make it to my desk until noon",
        "everything required more effort than i had",
        "the fatigue was bone-deep today",
        "crashed before noon and couldn't recover",
        "all i could do was exist today",
        "even thinking felt like too much effort",
        "energy completely bottomed out",
    ],
    "tired": [
        "pretty tired today",
        "wiped out by 2pm",
        "dead tired, barely keeping my eyes open",
        "no energy left by the afternoon",
        "exhausted before the day even started",
        "nausea and fatigue got me today",
        "my body didn't want to move this morning",
        "running low, needed a nap badly",
        "tired from the moment i woke up",
        "hit a wall around lunchtime and never recovered",
        "been incredibly fidgety but can't turn it into actual energy",
        "ironic that i'm so tired because i've been so fidgety",
        "feel awful, tired and kind of gross",
        "energy crashed hard in the afternoon",
        "medication wearing off hit my energy hard",
        "tired despite sleeping okay, which is annoying",
        "heavy-eyed all morning",
        "by 5:30 i was dead tired",
        "executive function spoons ran out by noon",
        "couldn't convert the restlessness into actual work energy",
        "running low on energy, propped up by coffee",
        "the afternoon crash was brutal today",
        "could really use a nap but can't take one",
        "my energy disappeared after lunch",
        "low energy today, everything took more effort",
        "fatigue setting in earlier than usual",
        "flagging a lot today, hard to push through",
        "started okay but fell off a cliff energy-wise",
        "the med rebound is hitting my energy hard",
        "need to lie down but have too much to do",
        "body refusing to cooperate today",
        "drained, everything is taking too long",
        "sluggish compared to yesterday",
        "low energy but not zero, just tired",
        "not great energy but pushing through",
        "tired today, the sleep debt is catching up",
    ],
    "steady": [
        "energy has been okay today",
        "not crashing at least, steady enough",
        "managed to get through the day without a major slump",
        "holding up alright energy-wise",
        "nothing remarkable but consistent",
        "consistent energy, which i'll take",
        "not great not terrible, just steady",
        "energy held up enough to get things done",
        "felt even-keeled all day",
        "got through without the usual afternoon crash, good day",
        "energy has been decent, no complaints",
        "maintained through the afternoon which is unusual",
        "energy was reliable today",
        "carried through without a dip, unusual for me",
        "solid energy, no big peaks or troughs",
        "energy stayed consistent which i'm pleased about",
        "didn't crash, which is a win",
        "felt okay all day, not amazing but stable",
        "energy held reasonably well",
        "the meds kept things level today",
        "no major dips, that's good",
        "sustainable energy throughout",
        "steady as it goes today energy-wise",
        "balanced energy, got stuff done",
    ],
    "alert": [
        "feeling pretty awake and ready today",
        "good energy, better than yesterday",
        "meds gave me a nice steady boost",
        "alert from the start, which is unusual for me",
        "felt eager to start the day",
        "energy was there when i needed it",
        "had enough in me to push through",
        "been active and alert all morning",
        "felt really eager to take on tasks",
        "good energy levels today, actually got going",
        "woke up feeling surprisingly ready",
        "well-rested and ready, a nice change",
        "productive energy today, no jitters just solid",
        "felt on and switched-on all morning",
        "alert and focused for once",
        "had a lot of good energy to work with",
        "energy was high and channeled well",
        "i was actually working, things were getting done",
        "felt capable and energised today",
        "good morning energy that actually lasted",
        "battery felt charged today",
        "hit the ground running this morning",
        "energy levels well above baseline today",
        "felt properly ready for the day",
    ],
    "charged": [
        "feel a buzz in my body today, almost too much",
        "high energy today, maybe a bit too wired",
        "really eager to take on everything today",
        "my meds and coffee created a perfect combo this morning",
        "feel charged up and ready to go",
        "almost restless with energy, hard to channel it",
        "feel like i could run a marathon",
        "the most awake i've felt in months",
        "brain activated itself and i entered hyperfocus mode",
        "genuinely buzzing this morning",
        "electric kind of energy today, almost overwhelming",
        "couldn't stop moving, in a good way",
        "energy through the roof, need to pace myself",
        "wired in the best possible way",
        "everything felt fast and exciting",
        "i feel a buzz in my body, not uncomfortable but a lot",
        "on fire today, everything happening at pace",
        "surging with energy, rare feeling",
        "too much maybe, but i'll take it over the alternative",
    ],
}

FOCUS = {
    "foggy": [
        "brain fog all day, couldn't think straight",
        "couldn't retain anything, memory was shot",
        "kept reading the same sentence over and over",
        "brain did not want to cooperate at all today",
        "walking around feeling lost and anxious",
        "my brain has a really hard time focusing today",
        "executive functions just didn't show up",
        "couldn't keep a thought in my head",
        "processing things in real time was impossible",
        "feel absent-minded and spacey",
        "five minutes felt like just a collection of syllables",
        "no cognitive capacity today, just fog",
        "couldn't figure out how i wanted to structure my day",
        "tasks that usually feel easy were impenetrable",
        "nothing is getting retained, i keep walking into rooms not knowing why i'm there",
        "the brain fog whilst doing work killed all my productivity",
        "bad brain day, can't hold onto anything",
        "low on dopamine and executive function just didn't show up at all",
        "my brain is terrible at processing things in real time today",
        "completely blanked on things i know i know",
        "couldn't start anything because i couldn't hold the steps in my head",
        "working memory is absolutely empty today",
        "words escaping me constantly today",
        "the mental static is bad today",
        "can't get traction on anything, brain won't engage",
        "feel like my brain is wading through thick air",
        "losing things in real time, train of thought just gone",
        "couldn't find words in meetings today, embarrassing",
        "total cognitive blur, nothing is landing",
        "executive function has left the building",
        "felt cognitively offline for most of the day",
    ],
    "distracted": [
        "kept checking my phone instead of working",
        "zoning out constantly, couldn't stay on task",
        "scattered all day, nothing stuck",
        "my attention kept jumping around",
        "couldn't stay in one task for more than a few minutes",
        "high adhd day, absolutely all over the place",
        "distracted by absolutely everything",
        "had twitter open the whole time i was trying to work",
        "i kept zoning out on calls",
        "couldn't finish a single thing, just kept starting new ones",
        "concentration was completely gone",
        "switched tasks like a dozen times without finishing any",
        "so scattered i didn't even know where to start",
        "ended the day having done about 5 percent of what i planned",
        "kept going off on tangents and losing the thread",
        "heeby-jeebies all day but couldn't turn it into work",
        "racing thoughts made it impossible to settle on anything",
        "impulse-controlled by distraction all day",
        "started fifteen things, finished zero",
        "youtube rabbit hole ate three hours",
        "scrolling instead of working, classic",
        "couldn't make myself sit still and focus",
        "kept getting up to do something else every ten minutes",
        "meetings were hard, kept tuning out",
        "my attention was a pinball machine today",
        "picked up my phone between every sentence",
        "four browser tabs open, nothing productive",
        "interruptions killed whatever momentum i had",
        "hyperfocus on the wrong thing for two hours",
        "got interested in something tangential and lost the morning",
        "couldn't prioritize, kept ping-ponging between tasks",
        "nothing was sticking, couldn't concentrate",
        "restless and unfocused, couldn't settle",
        "brain all over the place today, very scattered",
    ],
    "present": [
        "focused enough to get through the day",
        "concentration held for the important stuff",
        "following along okay, nothing slipping",
        "things are clicking at a reasonable pace",
        "present enough, managed to complete things",
        "not sharp but definitely functional",
        "managed to stay on track for the most part",
        "held it together focus-wise",
        "focus was there when i needed it",
        "got through my tasks without too much trouble",
        "doing okay cognitively, brain cooperating",
        "on task more than off today, which is a win",
        "concentration was acceptable today",
        "focus held enough to be productive",
        "present and following along, tasks getting done",
        "nothing spectacular but competent",
        "brain doing what it's supposed to today",
        "attention well enough managed today",
        "able to see things through today",
        "focus is average but that's fine",
        "managing the workload without too much scatter",
        "reasonably focused, getting things done",
        "concentration okay, not fighting it today",
        "staying on task well enough",
    ],
    "sharp": [
        "really locked in today",
        "focus was excellent, things just clicked",
        "entered some kind of hyperfocus and knocked it all out",
        "completely concentrated, nothing could break it",
        "sat at my desk for hours and the time just flew",
        "my writing was flowing really well today",
        "i was actually working, things were getting done",
        "totally absorbed in what i was doing",
        "focused in a way i haven't been in a while",
        "really sharp today, tasks felt effortless",
        "i walk into rooms and i know why, that's the medication working",
        "everything that usually takes an hour took twenty minutes",
        "the kind of focus where you look up and it's suddenly 3pm",
        "post-medication me got the whole thing done",
        "sat still at a desk for hours without the urge to move",
        "in full problem-solving mode today",
        "focus is crisp, getting through things fast",
        "really dialed in today",
        "attention where i want it when i want it",
        "mental clarity has been exceptional today",
        "thinking feels fast and clear",
        "ideas flowing, making connections quickly",
        "doing my best work today",
        "sharpest i've felt in weeks",
        "everything clicking cognitively",
        "productivity feels effortless today",
        "completely in control of my attention today",
        "deep focus mode, properly into it",
        "brain is cooperating beautifully today",
    ],
    "lockedIn": [
        "hyperfocus mode for a solid few hours",
        "completely in the zone, nothing else existed",
        "couldn't be distracted if i tried",
        "absolute flow state, best i've felt working in ages",
        "deep work session, completely absorbed",
        "locked in all afternoon, didn't look up once",
        "the kind of concentration where you forget to eat",
        "hours disappeared, in the best way",
        "totally lost in the work, best kind of lost",
        "flow state that lasted all morning",
        "brain was absolutely on fire today",
        "couldn't have broken concentration if i tried",
        "the world disappeared for three hours",
        "in the zone in a way i almost never get to",
        "unstoppable focus today, rare and wonderful",
        "everything blocked out except what i was working on",
    ],
}

# ─────────────────────────────────────────────────────────────────────────────
# Negations — semantically mean the opposite of the word used.
# Labeled by the signal level they CONVEY (not the word they negate).
# ─────────────────────────────────────────────────────────────────────────────
NEG_FOCUS = [
    ("i really couldn't focus to save my life", "distracted"),
    ("zero focus today", "foggy"),
    ("my concentration was completely gone", "foggy"),
    ("not focused at all today", "distracted"),
    ("couldn't focus on anything", "distracted"),
    ("i had no focus whatsoever", "foggy"),
    ("nothing was sticking, i just couldn't concentrate", "distracted"),
    ("no ability to concentrate today", "foggy"),
    ("absolutely nothing landed cognitively", "foggy"),
]

NEG_ENERGY = [
    ("had nothing left in me", "sluggish"),
    ("no energy whatsoever", "sluggish"),
    ("not energetic at all today", "tired"),
    ("not a drop of energy left", "tired"),
    ("couldn't drum up any energy", "tired"),
    ("no gas in the tank", "sluggish"),
]

NEG_MOOD = [
    ("just didn't feel good at all", "low"),
    ("not happy today honestly", "low"),
    ("mood was not great, putting it mildly", "flat"),
    ("not in a good place emotionally", "low"),
    ("nothing felt okay today", "low"),
]

# ─────────────────────────────────────────────────────────────────────────────
# Hypothetical / future / conditional sentences — none class for all signals.
# These test the model's ability to NOT fire on future/hope/conditional states.
# ─────────────────────────────────────────────────────────────────────────────
HYPO = [
    "i'll see if i can focus once the meds kick in",
    "hoping to get some focus back tomorrow",
    "let's see if i can concentrate this afternoon",
    "want to try to do some deep work later",
    "going to see if a coffee helps me focus",
    "i hope my brain cooperates tomorrow",
    "maybe i'll be able to focus if i go somewhere quieter",
    "hoping i have energy for the gym later",
    "maybe an early night will fix my energy",
    "if i sleep well tonight i should feel better tomorrow",
    "going to try to recharge over the weekend",
    "let's see if the second cup of coffee helps",
    "hoping tomorrow is better mood-wise",
    "maybe a walk will help my mood this afternoon",
    "if the meds settle i think i'll feel better",
    "hope i wake up in a better headspace",
    "going to try taking it easy this evening",
    "want to get back into a routine this week",
    "planning a proper sleep schedule starting tonight",
    "let's see how the afternoon goes",
    "maybe things will click once i get started",
]

# ─────────────────────────────────────────────────────────────────────────────
# None-class background sentences — medication, sleep, activities, plans.
# These are real ADHD daily life content that carries no signal.
# ─────────────────────────────────────────────────────────────────────────────
MEDS = [
    "took my elvanse 50mg at 8 with breakfast",
    "took my concerta 36mg this morning",
    "took my meds a bit late today, around 10",
    "skipped my medication this morning, drug holiday",
    "did my usual elvanse 50 with food",
    "took vyvanse around 7am",
    "forgot my meds until nearly noon",
    "no meds today, taking a break",
    "took my dose, let's see how it goes",
    "elvanse kicked in around 9 or so",
    "ritalin top-up around 1pm",
    "concerta 54mg today, therapist upped the dose",
    "medication wearing off around 5, as usual",
    "the rebound hit me around 4:30 like clockwork",
    "took it earlier than usual to try to help with morning",
    "elvanse 30mg, starting lower this week",
    "took my meds with a proper breakfast for once",
    "concerta wearing off earlier than i'd like",
    "first day on the new dose",
    "remembered to take my medication on time today",
    "ritalin 10mg this morning",
    "trying concerta 27mg this week",
    "second week on elvanse, still adjusting",
    "missed my dose this morning, noticed immediately",
    "took meds later than usual because of a meeting",
    "elvanse and a big breakfast today",
    "psychiatrist adjusted my concerta to 36mg",
    "two weeks on the new medication, still seeing how it goes",
    "ritalin wearing off by mid afternoon as usual",
    "took my concerta at 7am before breakfast",
    "no drug holiday today, taking meds as normal",
]

SLEEP = [
    "slept about 7 hours last night",
    "barely slept, maybe 4 hours",
    "slept really well, 8 solid hours",
    "had a rough night, kept waking up",
    "went to bed late again, midnight",
    "slept in this morning",
    "decent sleep, woke up naturally",
    "only got 5 hours, restless all night",
    "couldn't get to sleep until 2am",
    "crashed hard and slept 9 hours",
    "up until midnight, brain wouldn't stop",
    "went to bed early for once, managed to sleep",
    "insomnia hit bad last night",
    "restless night, kept waking up anxious",
    "slept okay but woke up feeling unrefreshed",
    "the medication made it hard to sleep last night",
    "not getting much sleep and it's catching up with me",
    "best sleep i've had in weeks",
    "slept through my alarm, which never happens",
    "woke up at 3am and couldn't get back to sleep",
    "maybe 6 hours, not terrible but not great",
    "went to bed at 11, woke up at 5, so 6 hours",
    "slept badly, racing thoughts kept me up",
    "solid 8 hours for once, feel the difference",
    "late night, probably only 5 hours",
    "sleep was fragmented, lots of waking",
    "dropped off fast but woke early",
    "the worst night i've had in a while, maybe 3 hours",
    "slept in after a late night",
    "9 hours but still feel exhausted",
]

ACTIVITY = [
    "went for a walk after lunch",
    "had back to back meetings all morning",
    "did some laundry and tidied up",
    "long commute today, stuck in traffic",
    "had a call with my therapist",
    "made a proper dinner for once",
    "spent the morning answering emails",
    "went to the gym",
    "did the grocery shop",
    "worked from home today",
    "had coffee with a friend",
    "finished that report finally",
    "spent the afternoon on admin",
    "had a review meeting",
    "took a long lunch break",
    "called my sister for the first time in weeks",
    "did some meal prep for the week",
    "went to the pharmacy",
    "had a dentist appointment",
    "worked through lunch",
    "had a difficult conversation with my manager",
    "did a workout at home",
    "walked the dog for an hour",
    "spent way too long on reddit",
    "ended up on my phone for most of the evening",
    "all i wanted to do was lay on the couch and scroll",
    "got some sun this afternoon which helped",
    "spent time with the kids after school",
    "video call with my mum",
    "had lunch with a colleague",
    "finally sorted out some paperwork",
    "watched too much tv last night",
    "tried to read but couldn't concentrate",
    "did some stretching which helped a bit",
    "got outside for 20 minutes",
    "had to cancel plans because of how i was feeling",
    "social event in the evening, draining but okay",
    "cooked something proper for once instead of toast",
    "long day at the office",
    "spent the day mostly in my head",
    "did the bare minimum and called it done",
    "had a productive morning call with my coach",
    "took a break to walk around the block",
    "didn't leave the house today",
    "grocery delivery arrived, that's as productive as it got",
]

PLAN = [
    "going to try and sleep earlier tonight",
    "hope tomorrow's a better one",
    "i'll see if i can focus once the meds kick in",
    "planning to take it easy this weekend",
    "want to get back into a routine",
    "going to do a deep work session later",
    "let's see how the afternoon goes",
    "i should really hydrate more",
    "going to try the body double thing tomorrow",
    "might try a different time for my meds next week",
    "planning to reach out to my psychiatrist about the dose",
    "i need to figure out a better bedtime routine",
    "want to try journaling in the morning",
    "going to do a proper wind-down tonight",
    "need to get back to the gym this week",
    "going to try caffeine later rather than earlier",
    "want to prep my tasks the night before",
    "see if an earlier alarm helps with the morning fog",
    "going to try working from a coffee shop tomorrow",
    "planning to block my schedule better next week",
]

FILLER = [
    "okay so", "yeah", "honestly", "i mean", "let me think",
    "right so", "today", "so yeah", "anyway", "alright",
]

# ─────────────────────────────────────────────────────────────────────────────
# Temporal-recency sentences (hardcoded pairs — earlier state + current state).
# The pair structure means both sentences are included; gold uses the LAST one.
# ─────────────────────────────────────────────────────────────────────────────
TEMP_ENERGY_GOOD_THEN_BAD = [
    "i had decent energy this morning.",
    "had a great start to the day energy-wise.",
    "felt alert up until about 2pm.",
    "had energy when the meds were at their peak.",
]

TEMP_FOCUS_GOOD_THEN_BAD = [
    "i was able to focus this morning.",
    "sharp in the first half of the day.",
    "focus was solid after taking my meds.",
    "locked in this morning.",
]

TEMP_ENERGY_BAD_THEN_GOOD = [
    "started the day exhausted.",
    "was completely wiped when i woke up.",
    "no energy at all until the meds kicked in.",
]

TEMP_FOCUS_BAD_THEN_GOOD = [
    "couldn't focus at all this morning.",
    "scattered until lunchtime.",
    "brain fog all morning.",
]

# Realistic level distributions (weights) — mid common, extremes rare
W_MOOD = {"low": 2, "flat": 2, "okay": 4, "good": 4, "great": 1}
W_ENERGY = {"sluggish": 1, "tired": 4, "steady": 4, "alert": 2, "charged": 1}
W_FOCUS = {"foggy": 2, "distracted": 4, "present": 4, "sharp": 2, "lockedIn": 1}


def weighted(rng, weights):
    keys = list(weights)
    ws = [weights[k] for k in keys]
    return rng.choices(keys, ws)[0]


def pick(rng, bank):
    return rng.choice(bank)


def cap(text):
    """Capitalise first char."""
    return text[0].upper() + text[1:] if text else text


def gen_note(rng, day_idx):
    """One realistic check-in with correlated states, temporal pairs, negations."""
    sleep_poor = rng.random() < 0.35

    # energy correlated with sleep quality
    if sleep_poor:
        energy_lvl = weighted(rng, {"sluggish": 3, "tired": 4, "steady": 2, "alert": 1, "charged": 0})
    else:
        energy_lvl = weighted(rng, W_ENERGY)

    # focus correlated with energy
    if energy_lvl in ("sluggish", "tired"):
        focus_lvl = weighted(rng, {"foggy": 3, "distracted": 4, "present": 2, "sharp": 1, "lockedIn": 0})
    else:
        focus_lvl = weighted(rng, W_FOCUS)

    mood_lvl = weighted(rng, W_MOOD)

    # signal omission (~30% chance each)
    has_mood = rng.random() > 0.30
    has_energy = rng.random() > 0.28
    has_focus = rng.random() > 0.30

    sents = []  # list of {text, mood, energy, focus}

    def add(text, m=None, e=None, f=None):
        sents.append({"text": text, "mood": m, "energy": e, "focus": f})

    # optional filler opener (none for all signals)
    if rng.random() < 0.4:
        add(cap(pick(rng, FILLER)) + ".")

    # meds (common — very frequent in real ADHD journaling)
    if rng.random() < 0.6:
        add(cap(pick(rng, MEDS)) + ".")

    # sleep context (sometimes)
    if rng.random() < 0.45:
        add(cap(pick(rng, SLEEP)) + ".")

    # mood sentence
    if has_mood:
        if rng.random() < 0.15 and mood_lvl == "low":
            t, lvl = pick(rng, NEG_MOOD)
            add(cap(t) + ".", m=lvl)
        else:
            add(cap(pick(rng, MOOD[mood_lvl])) + ".", m=mood_lvl)

    # energy (with occasional temporal-recency pair)
    if has_energy:
        use_temp_pair = rng.random() < 0.20
        use_neg = rng.random() < 0.12

        if use_temp_pair and energy_lvl in ("tired", "sluggish"):
            # good earlier → bad now
            add(cap(pick(rng, TEMP_ENERGY_GOOD_THEN_BAD)), e="steady")
            add(cap(pick(rng, ENERGY[energy_lvl])) + ".", e=energy_lvl)
        elif use_temp_pair and energy_lvl in ("alert", "charged"):
            # bad earlier → good now
            add(cap(pick(rng, TEMP_ENERGY_BAD_THEN_GOOD)), e="tired")
            add(cap(pick(rng, ENERGY[energy_lvl])) + ".", e=energy_lvl)
        elif use_neg:
            t, lvl = pick(rng, NEG_ENERGY)
            add(cap(t) + ".", e=lvl)
        else:
            add(cap(pick(rng, ENERGY[energy_lvl])) + ".", e=energy_lvl)

    # focus (with occasional temporal pair and negation)
    if has_focus:
        use_temp_pair = rng.random() < 0.20
        use_neg = rng.random() < 0.15

        if use_temp_pair and focus_lvl in ("distracted", "foggy"):
            # sharp earlier → distracted now
            add(cap(pick(rng, TEMP_FOCUS_GOOD_THEN_BAD)), f="sharp")
            add(cap(pick(rng, FOCUS[focus_lvl])) + ".", f=focus_lvl)
        elif use_temp_pair and focus_lvl in ("sharp", "lockedIn"):
            # distracted earlier → sharp now
            add(cap(pick(rng, TEMP_FOCUS_BAD_THEN_GOOD)), f="distracted")
            add(cap(pick(rng, FOCUS[focus_lvl])) + ".", f=focus_lvl)
        elif use_neg:
            t, lvl = pick(rng, NEG_FOCUS)
            add(cap(t) + ".", f=lvl)
        else:
            add(cap(pick(rng, FOCUS[focus_lvl])) + ".", f=focus_lvl)

    # hypothetical sentence (none class, tests abstention on future/conditional)
    if rng.random() < 0.35:
        add(cap(pick(rng, HYPO)) + ".")

    # activity (common, none class)
    if rng.random() < 0.60:
        add(cap(pick(rng, ACTIVITY)) + ".")

    # plan/closing (sometimes, none class)
    if rng.random() < 0.40:
        add(cap(pick(rng, PLAN)) + ".")

    # note-level gold = LAST stated value per signal (recency = current state)
    gold = {"mood": None, "energy": None, "focus": None}
    for s in sents:
        for k in ("mood", "energy", "focus"):
            if s[k] is not None:
                gold[k] = s[k]

    text = " ".join(s["text"] for s in sents)
    return {"id": f"day{day_idx:03d}", "text": text, "sentences": sents, "gold": gold}


def main():
    notes = []
    day = 0
    target = 600  # 6× the prior 90-entry corpus
    while len(notes) < target:
        day += 1
        if RNG.random() < 0.72:  # realistic ~72% adherence
            notes.append(gen_note(RNG, day))

    (OUT / "checkins.json").write_text(json.dumps(notes, indent=2))
    print(f"Generated {len(notes)} check-ins over {day} days → {OUT}/checkins.json")

    # Also write per-sentence labeled corpora (mood.json / energy.json / focus.json)
    rows = {"mood": [], "energy": [], "focus": []}
    seen = {"mood": set(), "energy": set(), "focus": set()}
    for n in notes:
        for s in n["sentences"]:
            for sig in ("mood", "energy", "focus"):
                label = s[sig] if s[sig] is not None else "none"
                key = s["text"].lower().strip()
                if key in seen[sig]:
                    continue
                seen[sig].add(key)
                rows[sig].append({"text": s["text"], "label": label})

    for sig in ("mood", "energy", "focus"):
        (OUT / f"{sig}.json").write_text(json.dumps(rows[sig], indent=2))
        c = Counter(r["label"] for r in rows[sig])
        nonepct = round(100 * c["none"] / len(rows[sig]))
        print(f"  {sig}: {len(rows[sig])} sentences, none={c['none']} ({nonepct}%)  {dict(c)}")

    print("\n--- 3 sample notes ---")
    for n in notes[:3]:
        print(f"[{n['id']}] gold={n['gold']}")
        print(f"   {n['text']}")


if __name__ == "__main__":
    main()
