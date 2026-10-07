import Foundation

/// The fictional sample life: five months of a person's moments, written to tell a coherent story.
/// Dates are relative to "now" so the journal always feels current. Weekday hints keep Sunday
/// rituals on Sundays.
enum SampleLife {
    struct Entry {
        var key: String
        var daysAgo: Int
        var weekday: Int? = nil   // 1 = Sunday … 7 = Saturday
        var hour: Int
        var minute: Int = 0
        var text: String
        var feeling: Feeling?
        var place: String? = nil
        var kept: Bool = false
        var photos: [SampleScene] = []
        var voice: Voice? = nil
    }

    struct Voice {
        var transcript: String
        var duration: TimeInterval
    }

    struct Person {
        var name: String
        var aliases: [String]
        var note: String
    }

    struct Place {
        var name: String
        var aliases: [String]
        var note: String
    }

    struct ImportantDate {
        var name: String
        var daysFromNow: Int
        var recursYearly: Bool
        var note: String
    }

    struct Collection {
        var title: String
        var summary: String
        var kind: CollectionKind
        var entryKeys: [String]
    }

    struct Chapter {
        var kind: ChapterKind
        var title: String
        var subtitle: String?
        var body: String
        var entryKeys: [String]
        var coverKey: String? = nil
    }

    struct ConversationSeed {
        var title: String
        var daysAgo: Int
        var aboutEntryKey: String? = nil
        var messages: [(role: MessageRole, text: String, refs: [String], suggestions: [String])]
    }

    // MARK: People, places, dates

    static let people: [Person] = [
        Person(name: "Hannah", aliases: ["Han"], note: "Your sister. Lives in Leeds. Calls while you cook."),
        Person(name: "Dad", aliases: ["my dad", "father"], note: "Had a stent fitted in the spring. Walks to the end of the road and back, then two miles."),
        Person(name: "Mum", aliases: ["my mum", "mother"], note: "Grows roses. Tells Dad to let you go at the end of calls."),
        Person(name: "Tom", aliases: [], note: "Old friend. You run together on Saturdays. Moving to Edinburgh in the new year."),
        Person(name: "Maya", aliases: [], note: "From the design team at the new job. Walked you to the coffee machine on your first day.")
    ]

    static let places: [Place] = [
        Place(name: "The harbour", aliases: ["harbour", "harbourside"], note: "The walk you take instead of thinking."),
        Place(name: "The Downs", aliases: ["Downs", "Clifton Downs"], note: "Where the sky is bigger than the week."),
        Place(name: "St Ives", aliases: ["Porthmeor"], note: "Three days alone, on purpose."),
        Place(name: "Mum and Dad's", aliases: ["Shrewsbury", "my parents' house"], note: "Roses, washing-up, Sunday calls."),
        Place(name: "The office", aliases: ["office", "my desk"], note: "The new job. Month three was the hard one.")
    ]

    static let importantDates: [ImportantDate] = [
        ImportantDate(name: "Dad's birthday", daysFromNow: 16, recursYearly: true, note: "Hannah wants a surprise; you want to warn him."),
        ImportantDate(name: "Hannah's birthday", daysFromNow: -82, recursYearly: true, note: ""),
        ImportantDate(name: "First day at the new job", daysFromNow: -131, recursYearly: false, note: "New lanyard, new password, new everyone."),
        ImportantDate(name: "Dad's procedure", daysFromNow: -116, recursYearly: false, note: "A stent. He grumbled about the tea.")
    ]

    // MARK: Entries

    static let entries: [Entry] = [
        Entry(key: "notice", daysAgo: 152, hour: 21, minute: 40, text: "Handed in my notice today. Eight years. Walked out of the building and didn't know what to do with my hands. Everyone was kind, which somehow made it worse. I keep telling people it's the right thing and I think I believe it.", feeling: .low),
        Entry(key: "cantsleep", daysAgo: 149, hour: 23, minute: 50, text: "Can't sleep. Third night. Keep running the conversation with Claire in my head and rewriting my half of it.", feeling: .low),
        Entry(key: "mist", daysAgo: 146, hour: 9, minute: 15, text: "Walked the Downs before anyone was up. Mist on the grass, the kind that makes the city look like it's been lifted. First morning this week I've felt like myself.", feeling: .steady, place: "The Downs", photos: [.downsMorning]),
        Entry(key: "hannahcall", daysAgo: 143, hour: 19, text: "", feeling: .good, voice: Voice(transcript: "Hannah rang while I was cooking. She did the thing where she pretends to ask about my week and then just tells me hers, and I was so glad of it. I'd forgotten how much I like hearing about her chaos. She says I should come up to Leeds before the new job starts. I might.", duration: 24)),
        Entry(key: "train", daysAgo: 139, weekday: 7, hour: 11, minute: 30, text: "On the train to Leeds. Hannah has promised a 'low-key weekend', which from her means at least one spontaneous party. Rain on the window all the way past Birmingham. I don't mind it.", feeling: .good, place: "The train north", photos: [.trainWindow]),
        Entry(key: "kitchenfloor", daysAgo: 138, weekday: 1, hour: 22, minute: 10, text: "Hannah's kitchen at midnight, both of us on the floor with the dog, laughing at nothing. She said 'you look lighter already' and I nearly cried. I've missed her more than I'd let myself notice.", feeling: .bright, place: "Leeds", kept: true),
        Entry(key: "firstday", daysAgo: 131, weekday: 2, hour: 8, minute: 20, text: "First day. New lanyard, new password, new everyone. Sat in a meeting about a product I don't understand yet and nodded like a lunatic. Maya from the design team walked me to the coffee machine and talked me through who's who. Small mercy.", feeling: .low, place: "The office"),
        Entry(key: "behind", daysAgo: 128, hour: 23, minute: 30, text: "Three days in and I'm already behind on something I didn't know existed. Lay awake doing the maths on whether I've made a terrible mistake. The maths doesn't come out.", feeling: .heavy),
        Entry(key: "longway", daysAgo: 127, hour: 18, minute: 5, text: "Left on time for once and walked the long way home, round the harbour. Boats knocking against each other. Didn't solve anything but my shoulders came down from my ears.", feeling: .steady, place: "The harbour", photos: [.harbourDusk]),
        Entry(key: "mayalunch", daysAgo: 123, hour: 13, text: "Lunch with Maya. She's been here two years and says the first month is 'mostly pretending, then suddenly not'. Told me which meetings to ignore. I think she might become a friend.", feeling: .good, place: "The office"),
        Entry(key: "turn", daysAgo: 118, hour: 20, minute: 45, text: "Mum rang. Dad's had 'a bit of a turn' — her words — and they're keeping him in overnight for tests. She said not to come. I'm going.", feeling: .low),
        Entry(key: "corridor", daysAgo: 117, hour: 6, minute: 10, text: "Hospital corridor at six in the morning, the vending machine humming. Dad made a joke about the food. I've never seen him look small before.", feeling: .heavy, place: "Shrewsbury"),
        Entry(key: "stent", daysAgo: 116, hour: 21, text: "", feeling: .low, place: "Shrewsbury", voice: Voice(transcript: "A stent. They said it like it was nothing, and I suppose to them it is. He's grumbling about the tea, which Mum says is the best sign there is. I cried in the car park, which I didn't expect. Driving back tomorrow.", duration: 20)),
        Entry(key: "skybigger", daysAgo: 115, hour: 17, minute: 30, text: "Walked the Downs after work. Needed the sky to be bigger than the week.", feeling: .steady, place: "The Downs"),
        Entry(key: "shipped", daysAgo: 111, hour: 12, minute: 30, text: "First thing I've shipped. Tiny, but mine. Maya left a sticky note on my screen that just said 'told you'.", feeling: .good, place: "The office"),
        Entry(key: "bread1", daysAgo: 108, weekday: 1, hour: 10, text: "Made bread for the first time since the move. Forgot how much I like the waiting part. The flat smelled like somewhere people live.", feeling: .good, photos: [.kitchenTable]),
        Entry(key: "retro", daysAgo: 104, hour: 23, minute: 15, text: "Overthinking the thing I said in the retro. Nobody else will remember it. I will remember it for ten years.", feeling: .low),
        Entry(key: "tomrun1", daysAgo: 103, hour: 7, minute: 40, text: "Ran with Tom for the first time in a year. He was unbearable about his new trainers and it was wonderful. Five slow kilometres along the river. Lungs on fire, head clear.", feeling: .steady),
        Entry(key: "trumpet", daysAgo: 99, hour: 19, minute: 30, text: "Harbour walk, warm enough to sit. A man playing a trumpet badly and sincerely. I love this city most at seven in the evening.", feeling: .good, place: "The harbour", kept: true, photos: [.harbourEvening]),
        Entry(key: "dadcall", daysAgo: 96, weekday: 1, hour: 11, minute: 20, text: "Sunday call with Dad. He's walking to the end of the road and back every day and reports it like a military operation. Bread in the oven while we talked. Mum in the background telling him to let me go.", feeling: .good),
        Entry(key: "badweek", daysAgo: 88, hour: 22, minute: 30, text: "Bad week. Deadline moved, scope didn't. Kept my voice level in the meeting and then sat in the car for twenty minutes. I don't want to be the person who hates their new job by month three.", feeling: .heavy, place: "The office"),
        Entry(key: "kites", daysAgo: 87, hour: 18, minute: 40, text: "Didn't go home. Went up to the Downs and walked until the thinking ran out. Kite surfers in the wind. Shoulders down.", feeling: .steady, place: "The Downs", photos: [.downsEvening]),
        Entry(key: "stillbad", daysAgo: 85, hour: 8, minute: 30, text: "Still bad. Slept, though, which is something.", feeling: .low),
        Entry(key: "walkmeeting", daysAgo: 84, hour: 20, text: "Maya suggested walking instead of a meeting. Did the whole harbour loop with laptops in our bags. Solved the thing in twenty minutes we'd been failing to solve for a week. Should be a rule.", feeling: .steady, place: "The harbour"),
        Entry(key: "parkrun", daysAgo: 80, weekday: 7, hour: 15, text: "Parkrun with Tom, then a pub lunch that lasted until four. He's seeing someone. He went pink telling me. Good for him.", feeling: .good),
        Entry(key: "hannahvisit", daysAgo: 77, weekday: 7, hour: 19, minute: 10, text: "Hannah's visit. She arrived with a bag of Leeds things: a loaf, a plant, a book she's 'definitely finished'. Harbour walk, then dinner at the place with the green door.", feeling: .good, place: "The harbour", kept: true, photos: [.harbourEvening]),
        Entry(key: "pancakes", daysAgo: 76, weekday: 1, hour: 10, minute: 30, text: "Hannah asleep on the sofa under the plant she brought. Made pancakes, badly. The flat has never felt more like a home than with her in it.", feeling: .bright, kept: true, photos: [.kitchenMorning]),
        Entry(key: "quiet", daysAgo: 71, hour: 23, minute: 40, text: "Flat too quiet after Hannah. Bad sleep, three nights now.", feeling: .low),
        Entry(key: "gorge", daysAgo: 70, hour: 18, minute: 30, text: "Walked. Just walked. Downs, then down through the gorge. Felt the quiet go from empty to peaceful somewhere around the bridge.", feeling: .steady, place: "The Downs"),
        Entry(key: "book", daysAgo: 64, hour: 21, minute: 15, text: "Finished the book Hannah 'definitely finished'. She hadn't. The ending is the kind that makes you look at the wall for a bit.", feeling: .steady),
        Entry(key: "presented", daysAgo: 60, hour: 12, text: "Presented the thing. Voice shook for the first minute then stopped. Afterwards the head of product said 'good' in a way that I'm choosing to take as a sentence.", feeling: .good, place: "The office"),
        Entry(key: "booked", daysAgo: 52, hour: 20, minute: 30, text: "Booked three days in St Ives for the bank holiday. Alone, on purpose. I've never done that.", feeling: .steady),
        Entry(key: "stives1", daysAgo: 45, weekday: 7, hour: 16, minute: 30, text: "St Ives. The sea the colour it is in photos you don't believe. Walked from the station straight to the water and stood there with my shoes in my hand like a cliché. Don't care.", feeling: .bright, place: "St Ives", kept: true, photos: [.coastBright]),
        Entry(key: "stives2", daysAgo: 44, weekday: 1, hour: 7, minute: 50, text: "", feeling: .bright, place: "St Ives", kept: true, photos: [.seaMorning], voice: Voice(transcript: "Swam before breakfast. Cold enough to make me shout. Two old women in bobble hats laughing at me from the shallows, and then with me. I can't remember the last time I made a noise like that.", duration: 18)),
        Entry(key: "stives3", daysAgo: 44, weekday: 1, hour: 21, minute: 20, text: "Fish and chips on the harbour wall. Gulls like a protection racket. Wrote three pages in a notebook that I won't show anyone, and that might be the best thing I've written in years.", feeling: .good, place: "St Ives"),
        Entry(key: "stives4", daysAgo: 43, weekday: 2, hour: 11, minute: 10, text: "Last morning. Sat on the rocks at Porthmeor and watched the surfers fail cheerfully. I feel like I've been put back together by someone who read the instructions.", feeling: .good, place: "St Ives", kept: true, photos: [.coastRocks]),
        Entry(key: "sandbag", daysAgo: 40, hour: 8, minute: 45, text: "Back at my desk with sand still in my bag. Found I didn't mind the inbox. Maybe the sea is a setting I can carry.", feeling: .good, place: "The office"),
        Entry(key: "roses", daysAgo: 35, weekday: 1, hour: 12, text: "Cooked for Mum and Dad — properly, at theirs. Dad did the washing-up unasked, which is how he says thank you. He's walking two miles now. Mum showed me her roses with the pride of a general.", feeling: .good, place: "Mum and Dad's", kept: true, photos: [.gardenSummer]),
        Entry(key: "lists", daysAgo: 31, hour: 23, minute: 5, text: "Lying awake making lists for a meeting I'm not even leading.", feeling: .low),
        Entry(key: "insteadof", daysAgo: 30, hour: 18, minute: 20, text: "Harbour again. It's become the thing I do instead of thinking. Not sure that's healthy, but it's better than the ceiling.", feeling: .steady, place: "The harbour"),
        Entry(key: "mayawall", daysAgo: 26, hour: 13, minute: 30, text: "Maya has moved to our floor. We now share a wall and a running commentary. I laughed so hard at something she said that someone from finance came to check.", feeling: .good, place: "The office"),
        Entry(key: "edinburgh", daysAgo: 22, hour: 20, text: "Tom's moving to Edinburgh with Priya in the new year. I'm happy for him, properly. I also went quiet for a second and he noticed. We're going to run every Saturday until then, he says.", feeling: .steady),
        Entry(key: "tomrun2", daysAgo: 18, weekday: 7, hour: 9, minute: 30, text: "Saturday run. Tom talking about Edinburgh flats, me pretending to know what a tenement is. Seven kilometres. My best in years, not that anyone's counting. He was counting.", feeling: .good),
        Entry(key: "rumours", daysAgo: 14, hour: 22, minute: 50, text: "Reorg rumours at work. Everyone's being very normal in a way that isn't.", feeling: .low, place: "The office"),
        Entry(key: "rainwalk", daysAgo: 13, hour: 17, minute: 45, text: "Walked the Downs. Rain started halfway and I didn't turn back. Something about getting properly wet makes the rumours smaller.", feeling: .steady, place: "The Downs", photos: [.downsRain]),
        Entry(key: "bread2", daysAgo: 11, weekday: 1, hour: 10, minute: 15, text: "Bread. Better than last time. The crust actually crackled when I pressed it, like in the videos. Sent Hannah a photo. She replied 'who ARE you'.", feeling: .good, kept: true, photos: [.kitchenTable]),
        Entry(key: "allclear", daysAgo: 9, hour: 19, text: "Dad's six-month check: all clear. He told me by text, three words and a thumbs up, as if it were a parcel delivery. I read it four times.", feeling: .good, kept: true),
        Entry(key: "reorg", daysAgo: 6, hour: 8, text: "Reorg announced. I'm fine. My team's fine. Maya's fine. Spent the whole morning feeling the adrenaline leave.", feeling: .steady, place: "The office"),
        Entry(key: "birthdayplan", daysAgo: 4, weekday: 7, hour: 11, text: "Long call with Hannah about Dad's birthday. She wants a surprise; I want to warn him. We compromised on a surprise he knows about.", feeling: .good),
        Entry(key: "awake", daysAgo: 2, hour: 23, minute: 30, text: "Awake again. Not about anything. Just awake.", feeling: .low),
        Entry(key: "goldwater", daysAgo: 1, hour: 18, minute: 15, text: "Walked the harbour after work. Low sun, the water doing its gold thing. I noticed I was waiting for it to fix me, and then it sort of did.", feeling: .steady, place: "The harbour", photos: [.harbourGold]),
        Entry(key: "backstep", daysAgo: 0, hour: 7, minute: 30, text: "Coffee on the back step before work. Cold enough to see my breath. Nobody needs anything from me for eleven more minutes.", feeling: .good)
    ]

    // MARK: Collections

    static let collections: [Collection] = [
        Collection(title: "Three days in St Ives", summary: "A bank holiday alone, on purpose. The sea the colour it is in photos you don't believe.", kind: .experience, entryKeys: ["booked", "stives1", "stives2", "stives3", "stives4", "sandbag"]),
        Collection(title: "Walking it off", summary: "The thing you do instead of thinking. Seven walks, most of them the day after something hard.", kind: .ritual, entryKeys: ["longway", "skybigger", "kites", "walkmeeting", "gorge", "insteadof", "rainwalk", "goldwater"]),
        Collection(title: "Dad's spring", summary: "A bit of a turn, a stent, a grumble about the tea. Then two miles a day and three words with a thumbs up.", kind: .milestone, entryKeys: ["turn", "corridor", "stent", "dadcall", "roses", "allclear"]),
        Collection(title: "Sunday bread", summary: "The waiting part.", kind: .ritual, entryKeys: ["bread1", "dadcall", "pancakes", "bread2"]),
        Collection(title: "Hannah's visit", summary: "A loaf, a plant, a book she had definitely not finished.", kind: .experience, entryKeys: ["hannahvisit", "pancakes", "quiet"])
    ]

    // MARK: Chapters

    static let chapters: [Chapter] = [
        Chapter(
            kind: .present,
            title: "Who I am now",
            subtitle: "Drawn from the last few weeks",
            body: """
            Five months ago you walked out of a building you'd worked in for eight years and didn't know what to do with your hands. Right now, going by your moments, you know what to do with them: you make bread on Sundays, you run with Tom on Saturdays, and when the week gets heavy you walk the harbour until your shoulders come down.

            Work still takes up space. It appears in more of your moments than anything else, and the heavy ones cluster around it — the deadline that moved, the retro, the reorg. But the shape of it has changed. In the first month you wrote about being behind on things you didn't know existed. Lately you write about sharing a wall with Maya and laughing so hard that finance came to check.

            The people are steady: Hannah, Dad, Mum, Tom, Maya. The places are steady too: the harbour, the Downs, your parents' kitchen, and now St Ives, which you went to alone and came back from "put back together by someone who read the instructions."

            If there's a single thread, it's this: you've learned that you don't have to solve a feeling. You can walk it. You can bake through it. You can let two old women in bobble hats laugh at you until you laugh too.
            """,
            entryKeys: ["backstep", "goldwater", "reorg", "mayawall", "bread2", "allclear"]
        ),
        Chapter(
            kind: .period,
            title: "A Different Kind of Year",
            subtitle: nil,
            body: """
            It started with a resignation and three nights without sleep. You'd handed in your notice after eight years and kept rewriting your half of a conversation with Claire in your head. The first morning you felt like yourself was on the Downs, in mist, before anyone else was up.

            The new job arrived with a lanyard, a password and a meeting you didn't understand. Maya walked you to the coffee machine on the first day — a small mercy you wrote down, which turned out to matter. Within a fortnight you'd shipped something tiny and she'd left a sticky note on your screen that said 'told you'.

            Then Dad. A "bit of a turn", a hospital corridor at six in the morning, a stent that the doctors described as nothing. You cried in the car park, which you didn't expect. The next day you walked the Downs because you needed the sky to be bigger than the week. That sentence — the sky bigger than the week — is the hinge of the whole chapter. You kept walking after that: round the harbour, up through the gorge, in the rain. Seven times the day after something hard.

            By the summer the moments had changed colour. Bread on Sundays. Hannah asleep under the plant she brought. A presentation where your voice shook and then stopped shaking. Three days in St Ives, alone, on purpose. And Dad, walking two miles a day, doing the washing-up unasked, sending three words and a thumbs up: all clear.
            """,
            entryKeys: ["notice", "mist", "firstday", "shipped", "corridor", "skybigger", "bread1", "presented", "stives1", "allclear"],
            coverKey: "kites"
        ),
        Chapter(
            kind: .period,
            title: "Three Days by the Sea",
            subtitle: nil,
            body: """
            You booked it on a Tuesday night, almost as a dare: three days in St Ives for the bank holiday, alone. You'd never done that. The moment you wrote it down felt steady rather than excited, which might be why it worked.

            The first afternoon you walked from the station straight to the water and stood there with your shoes in your hand "like a cliché". The next morning you swam before breakfast, cold enough to shout, and two old women in bobble hats laughed at you from the shallows and then with you. That evening: fish and chips on the harbour wall, gulls like a protection racket, three pages in a notebook you won't show anyone.

            Every moment from those three days is marked good or bright. That hasn't happened anywhere else in your journal. You came home with sand in your bag and found you didn't mind the inbox. "Maybe the sea is a setting I can carry," you wrote. So far, it seems you can.
            """,
            entryKeys: ["booked", "stives1", "stives2", "stives3", "stives4", "sandbag"],
            coverKey: "stives1"
        ),
        Chapter(
            kind: .people,
            title: "People who shaped these months",
            subtitle: nil,
            body: """
            Hannah appears more than anyone. She calls while you cook and pretends to ask about your week. She said "you look lighter already" on her kitchen floor at midnight and you nearly cried. She brought a loaf, a plant and a half-read book, and the flat has never felt more like home than with her asleep on the sofa.

            Dad is the chapter's quiet centre. A man who made a joke about hospital food while looking small for the first time, who grumbled about the tea (the best sign there is), who reports his daily walk like a military operation and says thank you by doing the washing-up. Three words and a thumbs up. You read it four times.

            Maya turned a first day into something survivable and then into a friendship: which meetings to ignore, a sticky note, a walking meeting that solved a week's problem in twenty minutes, a shared wall and a running commentary.

            Tom came back into your weeks with unbearable new trainers and five slow kilometres. He's moving to Edinburgh in the new year. You went quiet for a second and he noticed, and that is the kind of friend he is.
            """,
            entryKeys: ["kitchenfloor", "hannahvisit", "corridor", "allclear", "firstday", "walkmeeting", "tomrun1", "edinburgh"]
        ),
        Chapter(
            kind: .places,
            title: "Places I keep returning to",
            subtitle: nil,
            body: """
            The harbour is where you go instead of thinking. Boats knocking together, a man playing trumpet badly and sincerely, the water doing its gold thing. You've noticed yourself waiting for it to fix you, and then — "it sort of did."

            The Downs are for when you need the sky to be bigger than the week. Mist before anyone's up. Kite surfers in the wind. Rain you didn't turn back from.

            Mum and Dad's is roses and washing-up and being told to let him go at the end of a call. St Ives is the sea the colour it is in photos you don't believe — and the only place where every moment felt bright.
            """,
            entryKeys: ["longway", "trumpet", "goldwater", "mist", "kites", "rainwalk", "roses", "stives1"]
        ),
        Chapter(
            kind: .learned,
            title: "Things I've learned",
            subtitle: "In your own words, mostly",
            body: """
            Walking doesn't solve anything, but shoulders come down from ears.

            The first month of anything is "mostly pretending, then suddenly not."

            Grumbling about the tea is the best sign there is.

            A feeling can go from empty to peaceful somewhere around the bridge, if you keep walking.

            The sea might be a setting you can carry.

            Nobody else will remember the thing you said in the retro.

            Being quiet for a second is allowed, especially when a friend notices.
            """,
            entryKeys: ["longway", "mayalunch", "stent", "gorge", "sandbag", "retro", "edinburgh"]
        ),
        Chapter(
            kind: .remember,
            title: "Moments I want to remember",
            subtitle: "The ones you marked",
            body: "These are the moments you chose to keep. They are the ones that, read together, say most about who you are becoming.",
            entryKeys: ["kitchenfloor", "trumpet", "hannahvisit", "pancakes", "stives1", "stives2", "stives4", "roses", "bread2", "allclear"]
        )
    ]

    // MARK: Conversations

    static let conversations: [ConversationSeed] = [
        ConversationSeed(
            title: "A heavy week",
            daysAgo: 85,
            messages: [
                (.user, "I've had a terrible week.", [], []),
                (.companion, "It sounds like this week has felt heavier than usual. On Tuesday night you wrote that the deadline moved and the scope didn't, and that you sat in the car for twenty minutes afterwards. Do you want to explore what's been making it difficult, or would it help to just get it out of your head first?", ["badweek"], ["Let's explore what's been difficult", "I just need to get it out"]),
                (.user, "I think I'm scared I've made a mistake leaving.", [], []),
                (.companion, "That's a big thing to be carrying while also learning a new job. For what it's worth, the week you started you wrote that you'd 'nodded like a lunatic' — and three weeks later, that you'd shipped your first thing and Maya had left you a note saying 'told you'. The fear and the progress have been happening at the same time. What would you need to see to feel it was the right call?", ["firstday", "shipped"], ["Something small did help", "The heaviest part"])
            ]
        ),
        ConversationSeed(
            title: "About Dad",
            daysAgo: 9,
            aboutEntryKey: "allclear",
            messages: [
                (.companion, "This is from this evening. You wrote: “Dad's six-month check: all clear. He told me by text, three words and a thumbs up, as if it were a parcel delivery.” You marked it as good. Four months ago you wrote that you'd never seen him look small before. What stands out to you about it now?", ["corridor"], ["What was I feeling then?", "Why does this one matter?"]),
                (.user, "That he's stubborn and it saved him.", [], []),
                (.companion, "Then that's worth keeping. The stubbornness is all through your moments about him — the military-operation walks, the washing-up unasked, the grumbling about the tea that Mum said was the best sign there is. You've kept this moment, so it will be here. Is there anything you'd want to say to him that you haven't?", ["dadcall", "roses", "stent"], ["I'd like to write it down", "Not yet"])
            ]
        )
    ]
}
