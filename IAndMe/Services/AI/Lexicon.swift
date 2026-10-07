import Foundation

/// Small, readable word lists that drive the local intelligence. These are deliberately plain so the
/// behaviour is predictable and easy to tune. A production AI service would replace most of this.
enum Lexicon {
    static let stopWords: Set<String> = [
        "the", "and", "but", "for", "with", "that", "this", "then", "than", "have", "has", "had", "was", "were", "are", "is", "be", "been",
        "being", "you", "your", "yours", "she", "her", "him", "his", "they", "them", "their", "our", "ours", "its", "it's", "i'm", "i've",
        "i'd", "i'll", "we", "us", "me", "my", "mine", "who", "what", "when", "where", "why", "how", "which", "there", "here", "about",
        "into", "onto", "from", "just", "really", "very", "quite", "some", "any", "all", "not", "did", "do", "does", "doing", "done",
        "get", "got", "getting", "would", "could", "should", "will", "can", "may", "might", "also", "still", "even", "again", "back",
        "out", "over", "under", "after", "before", "today", "tonight", "yesterday", "tomorrow", "morning", "evening", "afternoon",
        "thing", "things", "something", "nothing", "everything", "one", "lot", "lots", "bit", "day", "days", "week", "time", "year",
        "much", "more", "most", "less", "like", "went", "come", "came", "going", "gone", "make", "made", "take", "took", "think",
        "thought", "know", "feel", "felt", "feeling", "feels", "say", "said", "see", "saw", "look", "looked", "want", "wanted", "need",
        "while", "because", "though", "although", "around", "through", "down", "off", "yes", "no", "okay", "ok", "well", "now", "ago",
        "remember", "write", "wrote", "written", "writing", "mention", "mentioned", "find", "show", "last", "first", "tell", "told",
        "ask", "asked", "talk", "talked", "talking", "maybe", "always", "never", "ever", "sometimes", "often", "every", "else",
        "someone", "anyone", "everyone", "anything", "whatever", "myself", "yourself", "same", "different", "little", "big", "small",
        "long", "short", "way", "ways", "kind", "sort", "stuff", "keep", "kept", "keeps", "seem", "seems", "seemed", "actually",
        "probably", "definitely", "honestly", "anymore", "already", "enough", "sure", "right", "wrong", "mean", "means", "meant"
    ]

    static let nameBlocklist: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "january", "february", "march", "april", "may",
        "june", "july", "august", "september", "october", "november", "december", "christmas", "easter", "god", "ok", "okay", "hi",
        "hello", "thanks", "sunday", "summer", "spring", "winter", "autumn", "today", "yesterday", "tomorrow", "new", "work", "mum", "dad",
        "mom", "home", "office"
    ]

    /// Words that legitimately begin a multi-word name even at the start of a sentence.
    static let namePrefixes: Set<String> = ["St", "San", "Santa", "Mount", "Mt", "Lake", "Port", "Fort", "New", "North", "South", "East", "West", "Dr", "Mr", "Mrs", "Ms", "Lord", "Lady", "Aunt", "Uncle", "Great", "Little", "Old", "Upper", "Lower"]

    static let difficultWords: Set<String> = [
        "terrible", "awful", "hard", "difficult", "tough", "overwhelmed", "overwhelming", "stressed", "stress", "stressful", "anxious",
        "anxiety", "worried", "worry", "worrying", "sad", "sadness", "down", "low", "heavy", "exhausted", "exhausting", "drained",
        "tired", "lonely", "alone", "angry", "frustrated", "frustrating", "upset", "cried", "crying", "tears", "hurt", "grief",
        "grieving", "scared", "afraid", "fear", "panic", "miserable", "hopeless", "lost", "struggling", "struggle", "rough", "bad",
        "worst", "horrible", "dread", "dreading", "numb", "empty", "sleepless", "insomnia", "burnt", "burnout", "failed", "failure",
        "guilty", "guilt", "ashamed", "regret", "argument", "argued", "fight", "sick", "ill", "pain", "nightmare", "mess"
    ]

    static let positiveWords: Set<String> = [
        "good", "great", "lovely", "happy", "glad", "joy", "joyful", "calm", "peaceful", "peace", "proud", "grateful", "gratitude",
        "thankful", "light", "lighter", "bright", "brilliant", "wonderful", "beautiful", "amazing", "excited", "exciting", "warm",
        "content", "relieved", "relief", "hopeful", "hope", "laughed", "laughing", "laugh", "smile", "smiled", "fun", "enjoyed",
        "enjoy", "love", "loved", "kind", "rested", "refreshed", "energised", "alive", "free", "easy", "gentle", "soft", "best",
        "delighted", "cheerful", "better", "sunny", "sunshine", "celebrate", "celebrated", "win", "won", "success", "perfect"
    ]

    static let tiredWords: Set<String> = ["tired", "exhausted", "drained", "sleepless", "insomnia", "knackered", "shattered", "wiped"]

    /// Phrases that suggest the person may be in real distress. The companion steps back and points to people.
    static let crisisPhrases: [String] = [
        "kill myself", "end my life", "end it all", "suicid", "self harm", "self-harm", "hurt myself", "don't want to be here",
        "dont want to be here", "no point living", "no reason to live", "better off dead", "want to die", "wish i was dead"
    ]

    static let captureRequestPhrases: [String] = [
        "write this down", "save this", "keep this", "remember this", "note this", "make a note", "capture this", "add this",
        "turn this into", "record this", "put this in my journal", "write that down"
    ]

    static let patternQuestionPhrases: [String] = [
        "what makes me", "what has been", "what's been", "whats been", "what have i", "what do i keep", "what keeps", "who matters",
        "who do i", "where do i", "what helps", "what pattern", "any pattern", "notice", "noticed", "how have i changed", "have i changed",
        "how am i doing", "how have i been", "what's been difficult", "what has been difficult", "what's been good", "what has been good",
        "what lifts", "what lifted", "what do i write about", "what do i talk about", "what do i think about", "what's on my mind lately",
        "how often", "how many times", "what have i learned", "what have i learnt", "what stands out", "summarise", "summarize", "sum up"
    ]

    static let recallPhrases: [String] = [
        "remember when", "remember the", "last time i", "when did i", "did i write", "did i mention", "did i say", "have i written",
        "have i mentioned", "find the", "look back", "what did i write", "what did i say", "show me", "when was the last"
    ]

    static let greetingPhrases: [String] = ["hello", "hi", "hey", "good morning", "good evening", "good afternoon", "morning", "evening"]
    static let thanksPhrases: [String] = ["thank you", "thanks", "cheers", "appreciate"]
    static let goodbyePhrases: [String] = ["goodbye", "bye", "good night", "goodnight", "see you", "talk later", "that's all", "thats all"]

    /// Themes the memory layer recognises, with the lemmas that signal them.
    static let themes: [(name: String, words: Set<String>)] = [
        ("Work", ["work", "office", "meeting", "deadline", "boss", "manager", "colleague", "project", "presentation", "email", "client", "job", "career", "promotion", "team", "shift", "interview", "workload", "review"]),
        ("Walking", ["walk", "walking", "walked", "stroll", "wander", "hike", "ramble", "steps"]),
        ("Sleep", ["sleep", "slept", "sleeping", "asleep", "awake", "insomnia", "nap", "dream", "dreamt", "dreamed", "rest", "bed", "sleepless"]),
        ("Running", ["run", "running", "ran", "jog", "jogging", "parkrun", "race", "5k", "10k", "pace"]),
        ("Cooking", ["cook", "cooking", "cooked", "bake", "baking", "baked", "bread", "dough", "recipe", "dinner", "soup", "kitchen", "oven", "loaf", "sourdough"]),
        ("Family", ["family", "parents", "mum", "mom", "dad", "mother", "father", "sister", "brother", "grandma", "grandad", "nan", "nephew", "niece", "aunt", "uncle"]),
        ("Friends", ["friend", "friends", "mate", "mates", "pub", "quiz", "catch-up", "catchup", "reunion"]),
        ("Health", ["doctor", "hospital", "appointment", "procedure", "surgery", "heart", "medication", "health", "scan", "recovery", "recovering", "stent", "gp", "nurse", "ward"]),
        ("Reading", ["read", "reading", "book", "novel", "chapter", "library", "pages"]),
        ("Music", ["music", "song", "album", "gig", "concert", "piano", "guitar", "playlist", "record"]),
        ("Garden", ["garden", "gardening", "roses", "allotment", "plant", "plants", "seeds", "soil", "flowers", "tomatoes", "weeding"]),
        ("Weather", ["rain", "raining", "rained", "sunny", "sunshine", "storm", "wind", "windy", "fog", "frost", "snow", "heatwave", "drizzle", "mist", "misty"]),
        ("Money", ["money", "rent", "bills", "salary", "savings", "budget", "mortgage", "afford", "expensive"]),
        ("The sea", ["sea", "beach", "coast", "coastal", "waves", "tide", "harbour", "harbor", "sand", "cliff", "swim", "swimming", "shore"]),
        ("Coffee", ["coffee", "café", "cafe", "espresso", "flat white", "latte"])
    ]

    /// Themes that can plausibly be something a person turns to after a hard day. Work, sleep and
    /// health simply recur; they are not comforts, so they never produce a "relief" observation.
    static let restorativeThemes: Set<String> = ["Walking", "Running", "Cooking", "Reading", "Music", "Garden", "The sea", "Coffee", "Friends", "Family"]

    static func theme(for lemma: String) -> String? {
        themes.first { $0.words.contains(lemma) }?.name
    }
}
