# -*- coding: utf-8 -*-
"""Translate English CCQs (concept-checking questions) in the grammar
lesson JSON files to Farsi.

Applies an exact-match mapping to every multiple_choice "question" field
and every true_false "statement" field in data/grammar/vision*_lesson*.json.
Pure English practice sentences (fill-in-the-blank usage items) are
deliberately NOT in the mapping and stay English. Quoted English example
sentences inside translated items are preserved.
"""
import json
import glob
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

M = {
    # ---- vision1_lesson1 ----
    "Wh + subject + will + base verb":
        "ساختار سوال: Wh + فاعل + will + فعل ساده",
    # ---- vision1_lesson2 ----
    "In the sentence 'Robert's father is a very tall man', the word 'tall' is a noun.":
        "در جمله‌ی «Robert's father is a very tall man»، کلمه‌ی «tall» اسم است.",
    "'as taller as' is a correct English structure.":
        "«as taller as» ساختار درستی در انگلیسی است.",
    "'His grandfather is as old as my grandfather' means the two grandfathers have the same age.":
        "جمله‌ی «His grandfather is as old as my grandfather» یعنی این دو پدربزرگ هم‌سن هستند.",
    "'older than' is used to compare two things.":
        "«older than» برای مقایسه‌ی دو چیز استفاده می‌شود.",
    "'the tallest' is used when comparing only two things.":
        "«the tallest» وقتی استفاده می‌شود که فقط دو چیز را مقایسه می‌کنیم.",
    "'expensivest' is a correct English word.":
        "«expensivest» یک کلمه‌ی درست در انگلیسی است.",
    "'gooder' is a correct English word.":
        "«gooder» یک کلمه‌ی درست در انگلیسی است.",
    # ---- vision1_lesson3 ----
    "'They was working' is a correct sentence.":
        "جمله‌ی «They was working» درست است.",
    "'Reza was not doing an experiment' means Reza was doing nothing at all.":
        "جمله‌ی «Reza was not doing an experiment» یعنی رضا اصلاً هیچ کاری انجام نمی‌داد.",
    "'weren't' is used with 'he' and 'she'.":
        "«weren't» با «he» و «she» استفاده می‌شود.",
    "'Yes, they was.' is a correct short answer.":
        "«Yes, they was.» یک پاسخ کوتاه درست است.",
    "Questions in past progressive start with Was or Were.":
        "سوالات گذشته استمراری با Was یا Were شروع می‌شوند.",
    "In 'Newton was sitting under a tree when an apple hit his head', the word 'hit' is in past progressive.":
        "در جمله‌ی «Newton was sitting under a tree when an apple hit his head»، فعل «hit» گذشته استمراری است.",
    "In 'Newton was sitting under a tree when an apple hit his head', both verbs are in past progressive.":
        "در جمله‌ی «Newton was sitting under a tree when an apple hit his head»، هر دو فعل گذشته استمراری هستند.",
    "'themselves' is used for a plural subject like 'the scientists'.":
        "«themselves» برای فاعل جمع مثل «the scientists» استفاده می‌شود.",
    "'drink' is an action verb.":
        "«drink» یک فعل عملی است.",
    "'feel' in 'She feels happy' shows an action.":
        "«feel» در جمله‌ی «She feels happy» یک عمل را نشان می‌دهد.",
    "Action verbs can be used in both simple and continuous forms.":
        "افعال عملی هم در حالت ساده و هم در حالت استمراری استفاده می‌شوند.",
    "'I am knowing the answer' is a correct sentence.":
        "جمله‌ی «I am knowing the answer» درست است.",
    "State verbs are usually not used in continuous form.":
        "افعال حالتی معمولاً در حالت استمراری استفاده نمی‌شوند.",
    "'Newton was sitting under a tree when an apple hit his head' shows a background action interrupted by a sudden one.":
        "جمله‌ی «Newton was sitting under a tree when an apple hit his head» یک عمل پس‌زمینه‌ای را نشان می‌دهد که با یک عمل ناگهانی قطع شده است.",
    "'I am knowing the answer' is correct.":
        "جمله‌ی «I am knowing the answer» درست است.",
    # ---- vision1_lesson4 ----
    "'May I sit down?' is used to ask for permission.":
        "«May I sit down?» برای درخواست اجازه استفاده می‌شود.",
    "'can' is used to talk about ability.":
        "«can» برای صحبت درباره‌ی توانایی استفاده می‌شود.",
    "'should' shows a stronger obligation than 'must'.":
        "«should» الزام قوی‌تری از «must» نشان می‌دهد.",
    "'must' shows a stronger obligation than 'should'.":
        "«must» الزام قوی‌تری از «should» نشان می‌دهد.",
    "'must not' means something is forbidden.":
        "«must not» یعنی انجام کاری ممنوع است.",
    "'may not' is used to say something is not allowed.":
        "«may not» برای گفتن اینکه کاری مجاز نیست استفاده می‌شود.",
    "'Should your friend help you?' is asking about ability.":
        "جمله‌ی «Should your friend help you?» درباره‌ی توانایی سوال می‌کند.",
    "'Must we drive fast?' asks about obligation.":
        "جمله‌ی «Must we drive fast?» درباره‌ی الزام سوال می‌کند.",
    "'on Friday' is correct.":
        "«on Friday» درست است.",
    "'at' is used with days of the week like Friday.":
        "«at» با روزهای هفته مثل جمعه (Friday) استفاده می‌شود.",
    "'in front of' means 'beside'.":
        "«in front of» یعنی «کنار».",
    "'on the table' means the object is inside the table.":
        "«on the table» یعنی شیء داخل میز است.",
    "The adverb of 'good' is 'goodly'.":
        "قیدِ کلمه‌ی «good»، «goodly» است.",
    "'fast' has the same form for both adjective and adverb.":
        "«fast» برای صفت و قید به یک شکل استفاده می‌شود.",
    # ---- vision2_lesson1 ----
    "'a books' is correct.":
        "«a books» درست است.",
    "Countable nouns have both singular and plural forms.":
        "اسم‌های قابل‌شمارش هم شکل مفرد دارند و هم شکل جمع.",
    "'an information' is correct.":
        "«an information» درست است.",
    "'informations' is a correct plural word.":
        "«informations» یک جمع درست است.",
    "'rice' is a countable noun.":
        "«rice» یک اسم قابل‌شمارش است.",
    "'much' is used with uncountable nouns.":
        "«much» با اسم‌های غیرقابل‌شمارش استفاده می‌شود.",
    "'many' is used with countable plural nouns.":
        "«many» با اسم‌های قابل‌شمارشِ جمع استفاده می‌شود.",
    "'a lot of' can be used with both countable and uncountable nouns.":
        "«a lot of» هم با اسم‌های قابل‌شمارش و هم غیرقابل‌شمارش استفاده می‌شود.",
    "'some' can be used with uncountable nouns like 'water'.":
        "«some» با اسم‌های غیرقابل‌شمارش مثل «water» استفاده می‌شود.",
    "'a few' is used with countable nouns and 'a little' with uncountable nouns.":
        "«a few» با اسم‌های قابل‌شمارش و «a little» با اسم‌های غیرقابل‌شمارش استفاده می‌شود.",
    "'a loaf of bread' means one whole bread.":
        "«a loaf of bread» یعنی یک نان کامل.",
    "Every simple sentence must have at least a subject and a verb.":
        "هر جمله‌ی ساده حداقل باید فاعل و فعل داشته باشد.",
    "In 'Ali is a smart student', there is no object.":
        "در جمله‌ی «Ali is a smart student»، مفعول وجود ندارد.",
    "A simple sentence can also have additional information like time or place.":
        "جمله‌ی ساده می‌تواند اطلاعات اضافه‌ای مثل زمان یا مکان هم داشته باشد.",
    # ---- vision2_lesson2 ----
    "'They has finished their homework' is correct.":
        "جمله‌ی «They has finished their homework» درست است.",
    "'has' is used with 'she'.":
        "«has» با «she» استفاده می‌شود.",
    "'yet' usually comes at the end of a negative present perfect sentence.":
        "«yet» معمولاً در انتهای جمله‌ی منفی ماضی نقلی می‌آید.",
    "'haven't' is the short form of 'have not'.":
        "«haven't» شکل کوتاه‌شده‌ی «have not» است.",
    "'ever' usually comes right after the subject in present perfect questions.":
        "«ever» در سوالات ماضی نقلی معمولاً بلافاصله بعد از فاعل می‌آید.",
    "'Has Mr. Ahmadi produce that movie?' is grammatically correct.":
        "جمله‌ی «Has Mr. Ahmadi produce that movie?» از نظر گرامری درست است.",
    "'yet' is usually used in affirmative sentences.":
        "«yet» معمولاً در جملات مثبت استفاده می‌شود.",
    "'ever' is mostly used in questions with present perfect.":
        "«ever» بیشتر در سوالات ماضی نقلی استفاده می‌شود.",
    "'wake up' means 'to fall asleep'.":
        "«wake up» یعنی «به خواب رفتن».",
    "'call back' means to call someone again later.":
        "«call back» یعنی بعداً دوباره با کسی تماس بگیریم.",
    "'Cycling and jogging is my favorite sports' is correct.":
        "جمله‌ی «Cycling and jogging is my favorite sports» درست است.",
    "A single gerund subject takes a singular verb.":
        "فاعل gerund مفرد، فعل مفرد می‌گیرد.",
    "After prepositions like 'about' or 'for', we use a gerund.":
        "بعد از حروف اضافه‌ای مثل «about» یا «for»، از gerund استفاده می‌کنیم.",
    # ---- vision2_lesson3 ----
    "'If my friends will come, I will become happy' is correct.":
        "جمله‌ی «If my friends will come, I will become happy» درست است.",
    "The verb after 'if' is always in the simple present in Conditional Type I.":
        "در شرطی نوع اول، فعل بعد از «if» همیشه زمان حال ساده است.",
    "A comma is needed when the result clause comes first, like 'I'll phone you if I have time'.":
        "وقتی جمله‌ی نتیجه اول بیاید، ویرگول لازم است؛ مثل «I'll phone you if I have time».",
    "'If you study hard you will pass the exams' needs a comma after 'hard'.":
        "جمله‌ی «If you study hard you will pass the exams» بعد از «hard» به ویرگول نیاز دارد.",
    "'You will hurt yourself, if you jump into the river' has correct comma usage.":
        "در جمله‌ی «You will hurt yourself, if you jump into the river» استفاده از ویرگول درست است.",
    "Both orders (if-clause first or result-clause first) have the same meaning.":
        "هر دو ترتیب (اول جمله‌ی شرط یا اول جمله‌ی نتیجه) معنای یکسانی دارند.",
    "'surprised' can describe how a person feels.":
        "«surprised» می‌تواند احساس یک شخص را توصیف کند.",
    "'I'm tired of watching television' shows a feeling.":
        "جمله‌ی «I'm tired of watching television» یک احساس را نشان می‌دهد.",
    "'interested' is usually followed by 'in'.":
        "«interested» معمولاً با «in» ادامه پیدا می‌کند.",
    "'I ran fast to catch the bus' uses an infinitive.":
        "جمله‌ی «I ran fast to catch the bus» از مصدر استفاده می‌کند.",
    "'to not make noise' is the correct order.":
        "ترتیب «to not make noise» درست است.",
    "'not to' always comes before the base verb in a negative infinitive.":
        "در مصدر منفی، «not to» همیشه قبل از شکل ساده‌ی فعل می‌آید.",
    "'I was amazed to hear the news' uses an infinitive after an adjective.":
        "جمله‌ی «I was amazed to hear the news» بعد از صفت از مصدر استفاده می‌کند.",
    "Adjectives like 'happy', 'sad', and 'glad' can be followed by an infinitive.":
        "صفت‌هایی مثل «happy»، «sad» و «glad» می‌توانند با مصدر ادامه پیدا کنند.",
    # ---- vision3_lesson1 ----
    "In passive voice, the subject of the active sentence becomes the new subject of the passive sentence.":
        "در حالت مجهول، فاعلِ جمله‌ی معلوم، فاعلِ جدیدِ جمله‌ی مجهول می‌شود.",
    "'The window were broken' is correct.":
        "جمله‌ی «The window were broken» درست است.",
    "'The cars has been fixed' is correct.":
        "جمله‌ی «The cars has been fixed» درست است.",
    "'by' must always be used in a passive sentence.":
        "در جمله‌ی مجهول همیشه باید از «by» استفاده شود.",
    "A negative statement takes a negative tag question.":
        "جمله‌ی منفی، سوال تعقیبی (tag) منفی می‌گیرد.",
    "If the main sentence has no auxiliary verb, we use do/does/did in the tag.":
        "اگر جمله‌ی اصلی فعل کمکی نداشته باشد، در سوال تعقیبی از do/does/did استفاده می‌کنیم.",
    "A comma is used before and/but/or/so when combining two sentences.":
        "وقتی دو جمله را با and/but/or/so ترکیب می‌کنیم، قبل از آن‌ها ویرگول می‌گذاریم.",
    # ---- vision3_lesson2 ----
    "Which word introduces a relative clause about a person as the subject?":
        "کدام کلمه جمله‌ی وصفی درباره‌ی یک شخص در نقش فاعل را شروع می‌کند؟",
    "'who' can be used for people in relative clauses.":
        "«who» در جملات وصفی برای افراد استفاده می‌شود.",
    "'who' can be used to describe an object like a book or a car.":
        "«who» می‌تواند برای توصیف شیءای مثل کتاب یا ماشین استفاده شود.",
    "'whom' is more formal than 'who' when referring to the object of a relative clause.":
        "«whom» برای اشاره به مفعولِ جمله‌ی وصفی، رسمی‌تر از «who» است.",
    "In 'The woman who(m) you met yesterday is coming to dinner', what is the role of 'the woman' in the relative clause?":
        "در جمله‌ی «The woman who(m) you met yesterday is coming to dinner»، نقش «the woman» در جمله‌ی وصفی چیست؟",
    "In everyday spoken English, 'who' is often used instead of 'whom'.":
        "در انگلیسی محاوره‌ای روزمره، معمولاً به‌جای «whom» از «who» استفاده می‌شود.",
    "'which' can be used for people.":
        "«which» می‌تواند برای افراد استفاده شود.",
    "'that' can be used for both people and things in relative clauses.":
        "«that» در جملات وصفی هم برای افراد و هم برای اشیا استفاده می‌شود.",
    "Conditional Type II is used to talk about real, current facts.":
        "شرطی نوع دوم برای صحبت درباره‌ی واقعیت‌های واقعی و فعلی استفاده می‌شود.",
    "'If I have more time, I would learn French' is grammatically correct.":
        "جمله‌ی «If I have more time, I would learn French» از نظر گرامری درست است.",
    "'If I was you' is the standard form in Conditional Type II.":
        "«If I was you» شکل استاندارد در شرطی نوع دوم است.",
    # ---- vision3_lesson3 ----
    "In passive with modals, the structure is modal + be + past participle.":
        "در حالت مجهول با فعل‌های کمکی، ساختار به صورت: فعل کمکی + be + قسمت سوم فعل است.",
    "'The traffic rules must obeyed' is grammatically correct.":
        "جمله‌ی «The traffic rules must obeyed» از نظر گرامری درست است.",
    "'may' is used to show certainty, not possibility.":
        "«may» برای نشان دادن قطعیت استفاده می‌شود، نه احتمال.",
    "Past perfect is used for an action that happened before another action in the past.":
        "ماضی بعید برای عملی استفاده می‌شود که قبل از عمل دیگری در گذشته اتفاق افتاده است.",
    "'She has never seen a bear before' is the correct past perfect form.":
        "«She has never seen a bear before» شکل درست ماضی بعید است.",
    "After 'before', the action that happened first is usually in the past perfect.":
        "بعد از «before»، معمولاً عملی که زودتر اتفاق افتاده در ماضی بعید می‌آید.",
    "'already' emphasizes that something had happened before another point in the past.":
        "«already» تأکید می‌کند که کاری قبل از نقطه‌ای در گذشته اتفاق افتاده بود.",
    # ---- multiple_choice meta questions ----
    "Which sentence is passive?":
        "کدام جمله مجهول است؟",
    "Which sentence is in past passive?":
        "کدام جمله در حالت مجهولِ گذشته است؟",
    "Which is the correct passive present perfect form for 'They have fixed the cars'?":
        "شکل درستِ مجهولِ ماضی نقلی برای جمله‌ی «They have fixed the cars» کدام است؟",
    "Which sentence does NOT need to mention 'by'?":
        "کدام جمله نیازی به ذکر «by» ندارد؟",
    "Choose the correct relative pronoun: 'This is the book ___ I bought yesterday.'":
        "ضمیر وصفی درست را انتخاب کن: «This is the book ___ I bought yesterday.»",
    "Which word can replace both 'who' and 'which' in a relative clause?":
        "کدام کلمه می‌تواند هم جایگزین «who» و هم «which» در جمله‌ی وصفی باشد؟",
    "Choose the correct Conditional Type II sentence.":
        "جمله‌ی درستِ شرطی نوع دوم را انتخاب کن.",
    "Which sentence uses passive voice with a modal correctly?":
        "کدام جمله حالت مجهول را با فعل کمکی به‌درستی استفاده کرده؟",
    "Which sentence is in the past perfect tense?":
        "کدام جمله در زمان ماضی بعید است؟",
    "Choose the correct sentence.":
        "کدام جمله درست است؟",
}

changed = 0

files = sorted(glob.glob(os.path.join(ROOT, "data", "grammar", "vision*_lesson*.json")))
for f in files:
    with open(f, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    count_before = changed

    def walk(node):
        global changed
        if isinstance(node, dict):
            for key in ("question", "statement"):
                v = node.get(key)
                if isinstance(v, str) and v in M:
                    node[key] = M[v]
                    changed += 1
            for v in node.values():
                walk(v)
        elif isinstance(node, list):
            for v in node:
                walk(v)

    walk(data)
    with open(f, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent="\t")
        fh.write("\n")
    n = changed - count_before
    print(os.path.basename(f), "->", n, "items translated")

print("TOTAL translated:", changed)
