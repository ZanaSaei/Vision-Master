# Adds Persian ("fa") translations to English example bullets/cells across the
# V1/V2/V3 grammar JSON files. A bullet/cell becomes a dict {"en","fa"}.
import json, re

# Translation map: exact English string -> Persian translation.
# (Curated set. Add more keys to extend coverage.)
TR = {
    # ---- V1 Lesson 1 - Future simple ----
    "Alice and Kate will go to the library tomorrow.":
        "آلیس و کیت فردا به کتابخانه خواهند رفت.",
    "Ted will fly to Australia next Monday.":
        "تد دوشنبهٔ آینده به استرالیا پرواز خواهد کرد.",
    "The children will not play in the yard.":
        "بچه‌ها در حیاط بازی نخواهند کرد.",
    "I won't be here tomorrow.":
        "من فردا اینجا نخواهم بود.",
    "Will our family buy a new car next year?":
        "آیا خانوادهٔ ما سال آینده ماشین جدیدی خواهد خرید؟",
    "Will Reza have an exam on Monday?":
        "آیا رضا دوشنبه امتحان خواهد داشت؟",
    "The tourists will visit Shiraz next summer.":
        "گردشگران تابستان آینده از شیراز دیدن خواهند کرد.",
    "Who will visit Shiraz next summer?":
        "چه کسی تابستان آینده از شیراز دیدن خواهد کرد؟",
    "When will the tourists visit Shiraz?":
        "کی گردشگران از شیراز دیدن خواهند کرد؟",
    "Where will the tourists visit next summer?":
        "گردشگران تابستان آینده کجا را خواهند دید؟",
    "What will the tourists do next summer?":
        "گردشگران تابستان آینده چه خواهند کرد؟",
    "They are going to buy a house soon. They have enough money.":
        "آن‌ها به‌زودی خانه‌ای خواهند خرید. آن‌ها پول کافی دارند.",
    "Look at the sky! It's going to rain.":
        "به آسمان نگاه کن! قرار است باران ببارد.",
    "Alice is free tonight. She's going to read some poems.":
        "آلیس امشب آزاد است. او قصد دارد چند شعر بخواند.",
    "Reza is not going to watch TV tonight. The program is very boring.":
        "رضا امشب قصد ندارد تلویزیون تماشا کند. برنامه خیلی کسل‌کننده است.",
    "We are not going to destroy nature. We take care of wildlife.":
        "ما قصد نداریم طبیعت را نابود کنیم. ما از حیات‌وحش مراقبت می‌کنیم.",
    # ---- V1 Lesson 1 table examples ----
    "We will save nature.":
        "ما طبیعت را نجات خواهیم داد.",
    "They will not (won't) destroy the forest.":
        "آن‌ها جنگل را نابود نخواهند کرد.",
    "Will you protect the animals?":
        "آیا شما از حیوانات محافظت خواهید کرد؟",
}

def has_fa(s): return any(0x0600<=ord(c)<=0x06FF for c in s)
def is_eng(s): return bool(re.search(r'[a-zA-Z]{2,}',s)) and not has_fa(s)

def translate_item(item):
    if isinstance(item, dict):
        en=item.get("en",""); fa=item.get("fa","")
        if fa=="" and en in TR:
            item["fa"]=TR[en]
        return item
    if isinstance(item, str) and item in TR:
        return {"en": item, "fa": TR[item]}
    return item

def process(fn):
    d=json.load(open('data/'+fn,encoding='utf-8'))
    added=0
    for l in d['lessons']:
        for pg in ['simple_blocks','master_blocks','exam_exercises']:
            for b in l[pg]:
                if b['type']=='bullets':
                    items=b.get('items',[])
                    for i in range(len(items)):
                        if isinstance(items[i], str) and items[i] in TR:
                            items[i]=translate_item(items[i]); added+=1
                        elif isinstance(items[i], dict):
                            translate_item(items[i])
                elif b['type']=='table':
                    for row in b.get('rows',[]):
                        for i in range(len(row)):
                            if isinstance(row[i], str) and row[i] in TR:
                                row[i]=translate_item(row[i]); added+=1
    json.dump(d, open('data/'+fn,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    print(fn, 'translations applied:', added)

for f in ['V1_Grammar_All_Lessons.json','V2_Grammar_All_Lessons.json','V3_Grammar_All_Lessons.json']:
    process(f)
