import re, json

def clean(s):
    return s.strip()

def is_table(l): return l.strip().startswith('|')
def is_hr(l): return l.strip().startswith('---')

def parse_content_lines(lines):
    blocks=[]; i=0; n=len(lines)
    while i<n:
        line=lines[i]; s=line.strip()
        if is_hr(line) or s=='': i+=1; continue
        if s.startswith('## '):
            blocks.append({"type":"h2","text":clean(s[3:])}); i+=1; continue
        if s.startswith('### '):
            blocks.append({"type":"h4","text":clean(s[4:])}); i+=1; continue
        if s.startswith('#### '):
            blocks.append({"type":"h4","text":clean(s[5:])}); i+=1; continue
        if is_table(line):
            tbl=[]
            while i<n and is_table(lines[i]):
                row=[c.strip() for c in lines[i].strip().strip('|').split('|')]
                if all(re.fullmatch(r':?-{2,}:?',c) for c in row): i+=1; continue
                tbl.append(row); i+=1
            if tbl: blocks.append({"type":"table","rows":tbl})
            continue
        if s.startswith('- ') or (s.startswith('* ') and not s.startswith('**')):
            items=[]
            while i<n:
                ls=lines[i].strip()
                if ls.startswith('- '):
                    items.append(clean(ls[2:])); i+=1
                elif ls.startswith('* ') and not ls.startswith('**'):
                    items.append(clean(ls[2:])); i+=1
                else: break
            if items: blocks.append({"type":"bullets","items":items})
            continue
        if re.match(r'^\d+[\.\)]\s', s):
            items=[]
            while i<n:
                m=re.match(r'^(\d+)[\.\)]\s*(.*)$', lines[i].strip())
                if m: items.append(clean(m.group(2))); i+=1
                else: break
            if items: blocks.append({"type":"bullets","items":items})
            continue
        para=[]
        while i<n and lines[i].strip()!='' and not is_hr(lines[i]):
            ls=lines[i].strip()
            if ls.startswith(('## ','### ','#### ')) or is_table(lines[i]) or ls.startswith('- ') or re.match(r'^\d+[\.\)]\s',ls):
                break
            para.append(clean(ls)); i+=1
        if para: blocks.append({"type":"p","text":" ".join(para)})
    return blocks

def split_lessons(md_text):
    lines=md_text.splitlines(); lessons=[]; cur=None
    for l in lines:
        if re.match(r'^# Lesson\s+\d+', l.strip()):
            if cur is not None: lessons.append(cur)
            cur={"title":l.strip(),"topic":"","lines":[]}
        else:
            if cur is not None:
                if l.strip().startswith('## Grammar'):
                    cur["topic"]=l.strip()
                else: cur["lines"].append(l)
    if cur is not None: lessons.append(cur)
    return lessons

def split_pages(lesson_lines):
    pages={"simple":[],"master":[],"practice":[]}
    cur=None
    for l in lesson_lines:
        s=l.strip()
        if s.startswith('## صفحه ۱'): cur="simple"; continue
        if s.startswith('## صفحه ۲'): cur="master"; continue
        if s.startswith('## صفحه ۳'): cur="practice"; continue
        if s.startswith('## 🔑 پاسخ') or s.startswith('## پاسخ'): cur=None; continue
        if cur is not None: pages[cur].append(l)
    return pages

def parse_option_line(s):
    opts=[]
    pat = re.compile(r'\b([a-d])\)\s*(.*?)(?=\s+[a-d]\)\s*|$)', re.S)
    for m in pat.finditer(s):
        opts.append(m.group(2).strip())
    return opts

def build_mc(items_raw, answers):
    items=[]
    for num,ilines in items_raw:
        q=clean(ilines[0]); opts=[]
        for ln in ilines[1:]:
            opts += parse_option_line(ln)
        if not opts:
            opts = parse_option_line(ilines[0])
            mm=re.split(r'\s+[a-d]\)', ilines[0])
            q=mm[0].strip()
        ans=answers.get(num); ans_idx=-1
        mapping={'a':0,'b':1,'c':2,'d':3}
        if ans: ans_idx=mapping.get(ans.strip().lower(),-1)
        items.append({"question":q,"options":opts,"answer":ans_idx})
    return {"type":"multiple_choice","instruction":"Choose the best answer.","items":items}

def build_fill(items_raw, answers, instruction):
    items=[]
    for num,ilines in items_raw:
        text=clean(" ".join(ilines))
        ans=answers.get(num)
        items.append({"text":text,"answer":ans if ans else ""})
    return {"type":"fill_blank","instruction":instruction,"items":items}

def build_tf(items_raw, answers):
    items=[]
    for num,ilines in items_raw:
        text=clean(ilines[0]); ans=answers.get(num)
        ans_bool = True if ans and ans.strip().lower().startswith(('t','ص')) else False
        items.append({"text":text,"answer":ans_bool})
    return {"type":"true_false","instruction":"True or False?","items":items}

def build_transformation(items_raw, answers):
    items=[]
    for num,ilines in items_raw:
        task=""; text=""
        for ln in ilines:
            ls=clean(ln)
            if ls.startswith('→'): continue
            if ls.startswith('*') and ls.endswith('*'): text=ls.strip('*')
            elif not task: task=ls
        ans=answers.get(num,"")
        items.append({"task":task if task else "Rewrite the sentence.","text":text,"answer":ans})
    return {"type":"transformation","instruction":"Rewrite the sentence as instructed.","items":items}

def build_open(items_raw):
    items=[]
    for num,ilines in items_raw:
        items.append({"text":clean(ilines[0])})
    return {"type":"open_ended","instruction":"Write your answer.","items":items}

def build_error_correction(items_raw, answers):
    items=[]
    for num,ilines in items_raw:
        text=clean(ilines[0]).split('→')[0].strip()
        ans=answers.get(num,"")
        items.append({"text":text,"answer":ans})
    return {"type":"error_correction","instruction":"Find the mistake and correct it.","items":items}

def build_matching(rows, answers):
    if rows and rows[0] and rows[0][0].strip().lower().startswith('column'):
        rows=rows[1:]
    items=[]; lefts=[]; rights=[]
    for r in rows:
        if len(r)>=2:
            lefts.append(clean(r[0])); rights.append(clean(r[1]))
    for i,l in enumerate(lefts):
        items.append({"text":l,"options":rights,"answer":rights[i]})
    return {"type":"matching","instruction":"Match column A with column B.","items":items}

def build_cloze(passage_lines):
    passage=" ".join(clean(l) for l in passage_lines if not is_hr(l))
    blanks=re.findall(r'\*\*(.*?)\*\*', passage)
    items=[]
    for optstr in blanks:
        opts=[o.strip() for o in optstr.split('/')]
        items.append({"question":"Choose the correct word:","options":opts,"answer":0})
    cleanpass=re.sub(r'\*\*','',passage)
    return {"type":"multiple_choice","instruction":"Read the paragraph and choose the correct word.","passage":cleanpass,"items":items}


# ---------------- answer key parsing ----------------
def parse_practice_answer_key(lines):
    """Parse the practice answer key section into {part_num: {item_num: answer}}."""
    result={}
    cur_part=None
    for l in lines:
        s=l.strip()
        m=re.match(r'\*\*Part\s+(\d+)\s*:\*\*(.*)', s)
        if m:
            cur_part=int(m.group(1))
            result.setdefault(cur_part,{})
            rest=m.group(2).strip()
            if rest:
                _parse_key_items(result[cur_part], rest)
            continue
        # continuation lines for multiline parts (e.g. Part 4)
        if cur_part is not None and re.match(r'^\d+\)', s):
            _parse_key_items(result[cur_part], s)
    return result

def _parse_key_items(d, text):
    # format: "1-b, 2-b" or "1) many 2) much" or "1) sentence..."
    # split by commas for letter style, or by "n)" for text style
    if re.search(r'\d+\s*[-–]\s*[a-dA-D]', text):
        for m in re.finditer(r'(\d+)\s*[-–]\s*([a-dA-D])', text):
            d[int(m.group(1))]=m.group(2)
    else:
        # text style: 1) answer 2) answer ...
        for m in re.finditer(r'(\d+)\)\s*(.*?)(?=\s+\d+\)\s|$)', text):
            d[int(m.group(1))]=m.group(2).strip()
            # also catch "1) many" at end
        # handle single-item or comma-separated without trailing
        for m in re.finditer(r'(\d+)\)\s*([^0-9]+?)(?:,|$)', text):
            if int(m.group(1)) not in d:
                d[int(m.group(1))]=m.group(2).strip()

# ---------------- practice part parsing ----------------
def split_numbered_items(lines):
    """Split lines into numbered items: list of (num, [lines])."""
    items=[]; cur=None
    for l in lines:
        s=l.strip()
        if s=='': continue
        m=re.match(r'^(\d+)[\.\)]\s*(.*)$', s)
        if m:
            if cur is not None: items.append(cur)
            cur=(int(m.group(1)), [m.group(2)])
        else:
            if cur is not None:
                cur[1].append(s)
            else:
                # preamble line before first item
                pass
    if cur is not None: items.append(cur)
    return items

def build_practice_exercises(practice_lines, answer_key):
    """practice_lines: full practice page lines (without answer key).
    Returns list of blocks (h4 headers + exercise blocks)."""
    blocks=[]
    i=0; n=len(practice_lines)
    part_title=None
    part_type=None
    # collect per-part raw lines
    parts=[]  # (title, [lines])
    cur=None
    for l in practice_lines:
        s=l.strip()
        if s.startswith('### Part'):
            if cur is not None: parts.append(cur)
            cur=(s, [])
        else:
            if cur is not None:
                cur[1].append(l)
    if cur is not None: parts.append(cur)

    for pnum,(title,plines) in enumerate(parts, start=1):
        blocks.append({"type":"h4","text":title})
        # clean preamble lines (name/date etc.)
        body=[]
        for l in plines:
            s=l.strip()
            if s.startswith('**') and 'نام و نام خانوادگی' in s: continue
            body.append(l)
        ans = answer_key.get(pnum, {})
        # detect type from title
        tlow=title.lower()
        items_raw=split_numbered_items(body)
        if 'multiple choice' in tlow:
            blocks.append(build_mc(items_raw, ans))
        elif 'fill in the blank' in tlow or 'measure word' in tlow or 'choose the correct' in tlow and 'reading' not in tlow:
            # strip the (opt/opt) hints? keep them in text
            blocks.append(build_fill(items_raw, ans, title.split('—')[-1].strip().split('(')[0].strip() or "Fill in the blank."))
        elif 'rewrite' in tlow or 'transform' in tlow:
            blocks.append(build_transformation(items_raw, ans))
        elif 'matching' in tlow:
            rows=[]
            j=0
            # find the table
            for l in body:
                if is_table(l):
                    rows.append([c.strip() for c in l.strip().strip('|').split('|')])
            blocks.append(build_matching(rows, ans))
        elif 'reading' in tlow or 'short writing' in tlow or 'writing' in tlow:
            # reading paragraph with **a/b** or writing
            if 'writing' in tlow:
                blocks.append(build_open(items_raw))
            else:
                # reading passage: find paragraph lines before numbered items
                para_lines=[]
                for l in body:
                    s=l.strip()
                    if re.match(r'^\d+[\.\)]', s): break
                    if s and not is_hr(l) and not s.startswith('**'):
                        para_lines.append(l)
                if para_lines:
                    blocks.append(build_cloze(para_lines))
        else:
            # fallback: render as content
            blocks.extend(parse_content_lines(body))
    return blocks

# ---------------- assemble lesson ----------------
BOOKS_META={
    2: {
        1: {"accent":"#059669","icon":"🧮"},
        2: {"accent":"#DB2777","icon":"✅"},
        3: {"accent":"#CA8A04","icon":"🔀"},
    },
    3: {
        1: {"accent":"#EA580C","icon":"🌍"},
        2: {"accent":"#0891B2","icon":"🔍"},
        3: {"accent":"#16A34A","icon":"⚡"},
    },
}

def convert_md(md_path, book_num):
    txt=open(md_path,encoding='utf-8').read()
    lessons_md=split_lessons(txt)
    out_lessons=[]
    for li,L in enumerate(lessons_md):
        num=li+1
        pages=split_pages(L["lines"])
        meta=BOOKS_META.get(book_num,{}).get(num,{"accent":"#2563EB","icon":"📐"})
        # ---- SIMPLE page ----
        simple_lines=pages["simple"]
        wb_marker=next((i for i,l in enumerate(simple_lines) if l.strip().startswith('## ✍️')), None)
        if wb_marker is None:
            simple_content=simple_lines; wb_content=[]
        else:
            simple_content=simple_lines[:wb_marker]; wb_content=simple_lines[wb_marker:]
        simple_blocks=parse_content_lines(simple_content)
        if wb_content:
            simple_blocks += [{"type":"h2","text":"تمرین‌های کتاب"}] + parse_content_lines(wb_content)
        # ---- MASTER page ----
        master_lines=pages["master"]
        sup_marker=next((i for i,l in enumerate(master_lines) if l.strip().startswith('## 📝')), None)
        if sup_marker is None:
            master_content=master_lines; sup_content=[]
        else:
            master_content=master_lines[:sup_marker]; sup_content=master_lines[sup_marker:]
        master_blocks=parse_content_lines(master_content)
        master_blocks += _build_supplementary(sup_content)
        # ---- PRACTICE / EXAM page ----
        practice_lines=pages["practice"]
        key_marker=next((i for i,l in enumerate(practice_lines) if l.strip().startswith('## 🔑') or l.strip().startswith('## پاسخ')), None)
        if key_marker is None:
            pbody=practice_lines; keylines=[]
        else:
            pbody=practice_lines[:key_marker]; keylines=practice_lines[key_marker:]
        answer_key=parse_practice_answer_key(keylines)
        clean_body=[l for l in pbody if 'نام و نام خانوادگی' not in l]
        exam_blocks=[{"type":"h2","text":"امتحان"}]
        if clean_body:
            exam_blocks += build_practice_exercises(clean_body, answer_key)
        topic=L["topic"].replace('## Grammar:','').strip() if L["topic"] else ""
        out_lessons.append({
            "number":num,
            "title": L["title"].replace('# Lesson','').strip(),
            "topic": topic,
            "accent": meta["accent"],
            "icon": meta["icon"],
            "simple_blocks": simple_blocks,
            "master_blocks": master_blocks,
            "exam_exercises": exam_blocks,
        })
    return {"lessons": out_lessons}
def _build_supplementary(sup_content):
    out=[]
    if not sup_content:
        return out
    out.append({"type":"h2","text":"تمرین‌های تکمیلی"})
    secs=[]; cur=None
    for l in sup_content:
        s=l.strip()
        if s.startswith('### '):
            if cur is not None: secs.append(cur)
            cur=(s,[])
        else:
            if cur is not None: cur[1].append(l)
    if cur is not None: secs.append(cur)
    for title,seclines in secs:
        tlow=title.lower()
        ans={}
        key_idx=next((i for i,l in enumerate(seclines) if 'پاسخ‌نامه' in l or 'پاسخنامه' in l), None)
        body=seclines[:key_idx] if key_idx is not None else seclines
        if key_idx is not None:
            _parse_key_items(ans, seclines[key_idx])
        items_raw=split_numbered_items(body)
        if 'multiple choice' in tlow or 'چهارگزینه' in tlow:
            out.append(build_mc(items_raw, ans))
        elif 'true' in tlow or 'درست' in tlow:
            if ans: out.append(build_tf(items_raw, ans))
            else: out.extend(parse_content_lines(seclines))
        elif 'error' in tlow or 'اصلاح' in tlow:
            if ans: out.append(build_error_correction(items_raw, ans))
            else: out.extend(parse_content_lines(seclines))
        elif 'transform' in tlow or 'تبدیل' in tlow:
            out.append(build_transformation(items_raw, ans))
        elif 'open' in tlow or 'خودتان' in tlow:
            out.append(build_open(items_raw))
        else:
            out.extend(parse_content_lines(seclines))
    return out

if __name__=='__main__':
    import sys
    md=sys.argv[1]; book=int(sys.argv[2]); out=sys.argv[3]
    data=convert_md(md, book)
    json.dump(data, open(out,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    for l in data["lessons"]:
        print(l["number"], "|", l["topic"], "| simple", len(l["simple_blocks"]), "master", len(l["master_blocks"]), "exam", len(l["exam_exercises"]))
    print("WROTE", out)
# ==================== FIXES (override earlier definitions) ====================

def split_pages(lesson_lines):
    pages={"simple":[],"master":[],"practice":[],"answer_key":[]}
    cur=None
    for l in lesson_lines:
        s=l.strip()
        if s.startswith('## صفحه ۱'): cur="simple"; continue
        if s.startswith('## صفحه ۲'): cur="master"; continue
        if s.startswith('## صفحه ۳'): cur="practice"; continue
        if s.startswith('## 🔑 پاسخ') or s.startswith('## پاسخ'): cur="answer_key"; continue
        if cur is not None: pages[cur].append(l)
    return pages

def _clean_title(title):
    s=title.strip()
    for p in ('### ','## ','#### '):
        if s.startswith(p): s=s[len(p):]
    return s

def _parse_key_items(d, text):
    if re.search(r'\d+\s*[-–]\s*[a-hA-H]', text):
        for m in re.finditer(r'(\d+)\s*[-–]\s*([a-hA-H])', text):
            d[int(m.group(1))]=m.group(2)
        return
    if re.search(r'\d+\)', text):
        for m in re.finditer(r'(\d+)\)\s*(.*?)(?=\s+\d+\)\s|$)', text):
            d[int(m.group(1))]=m.group(2).strip()
        # trailing single item
        for m in re.finditer(r'(\d+)\)\s*([^0-9]+?)\s*$', text):
            if int(m.group(1)) not in d:
                d[int(m.group(1))]=m.group(2).strip()
        return
    # plain comma-separated list -> assign sequentially
    parts=[p.strip() for p in text.split(',') if p.strip()]
    for i,p in enumerate(parts, start=1):
        d[i]=p

def build_matching(rows, answers):
    rows=[r for r in rows if not all(re.fullmatch(r':?-{2,}:?',c.strip()) for c in r)]
    if rows and rows[0] and rows[0][0].strip().lower().startswith('column'):
        rows=rows[1:]
    items=[]; lefts=[]; rights=[]
    for r in rows:
        if len(r)>=2:
            lefts.append(clean(r[0])); rights.append(clean(r[1]))
    letter_to_idx={'a':0,'b':1,'c':2,'d':3,'e':4,'f':5,'g':6}
    for i,l in enumerate(lefts):
        ans_letter=answers.get(i+1)
        ai=letter_to_idx.get(str(ans_letter).lower(), i)
        ai=min(ai, len(rights)-1)
        items.append({"text":l,"options":rights,"answer":rights[ai] if 0<=ai<len(rights) else (rights[i] if rights else "")})
    return {"type":"matching","instruction":"Match column A with column B.","items":items}

def build_cloze(passage_lines, ans):
    passage=" ".join(clean(l) for l in passage_lines if not is_hr(l))
    # drop preamble instruction lines
    passage=re.sub(r'^Read the paragraph[^.]*\.\s*','',passage)
    blanks=re.findall(r'\*\*(.*?)\*\*', passage)
    items=[]
    for bi,optstr in enumerate(blanks):
        opts=[o.strip() for o in optstr.split('/')]
        idx=0
        key_ans=ans.get(bi+1)
        if key_ans:
            for k,o in enumerate(opts):
                if o.lower()==str(key_ans).strip().lower(): idx=k; break
        items.append({"question":"Choose the correct word:","options":opts,"answer":idx})
    cleanpass=re.sub(r'\*\*','',passage)
    return {"type":"multiple_choice","instruction":"Read the paragraph and choose the correct word.","passage":cleanpass,"items":items}

def _clean_instruction(title):
    # e.g. "Part 2 — Fill in the Blanks with much / many / a little / a few (۱۵ نمره — هر جای خالی ۳ نمره)"
    t=title.split('(')[0].strip()
    t=re.sub(r'^\s*Part\s+\d+\s*[-–—]\s*','',t).strip()
    return t or "Fill in the blank."

def build_practice_exercises(practice_lines, answer_key):
    blocks=[]
    parts=[]; cur=None
    for l in practice_lines:
        s=l.strip()
        if s.startswith('### Part'):
            if cur is not None: parts.append(cur)
            cur=(s,[])
        else:
            if cur is not None: cur[1].append(l)
    if cur is not None: parts.append(cur)
    for pnum,(title,plines) in enumerate(parts, start=1):
        t=_clean_title(title)
        blocks.append({"type":"h4","text":t})
        body=[l for l in plines if 'نام و نام خانوادگی' not in l]
        ans=answer_key.get(pnum, {})
        tlow=title.lower()
        items_raw=split_numbered_items(body)
        if 'multiple choice' in tlow:
            blocks.append(build_mc(items_raw, ans))
        elif 'reading' in tlow:
            para_lines=[]
            for l in body:
                s=l.strip()
                if re.match(r'^\d+[\.\)]', s): break
                if s and not is_hr(l): para_lines.append(l)
            blocks.append(build_cloze(para_lines, ans))
        elif 'matching' in tlow:
            rows=[]
            for l in body:
                if is_table(l):
                    rows.append([c.strip() for c in l.strip().strip('|').split('|')])
            blocks.append(build_matching(rows, ans))
        elif 'writing' in tlow:
            if items_raw:
                blocks.append(build_open(items_raw))
            else:
                prose=" ".join(clean(l) for l in body if l.strip() and not is_hr(l))
                blocks.append({"type":"open_ended","instruction":prose or "Write your answer.","items":[{"text":prose or "Write your answer."}]})
        elif 'rewrite' in tlow or 'transform' in tlow:
            blocks.append(build_transformation(items_raw, ans))
        else:
            # fill-blank style
            blocks.append(build_fill(items_raw, ans, _clean_instruction(t)))
    return blocks

def convert_md(md_path, book_num):
    txt=open(md_path,encoding='utf-8').read()
    lessons_md=split_lessons(txt)
    out_lessons=[]
    for li,L in enumerate(lessons_md):
        num=li+1
        pages=split_pages(L["lines"])
        meta=BOOKS_META.get(book_num,{}).get(num,{"accent":"#2563EB","icon":"📐"})
        simple_lines=pages["simple"]
        wb_marker=next((i for i,l in enumerate(simple_lines) if l.strip().startswith('## ✍️')), None)
        if wb_marker is None:
            simple_content=simple_lines; wb_content=[]
        else:
            simple_content=simple_lines[:wb_marker]; wb_content=simple_lines[wb_marker:]
        simple_blocks=parse_content_lines(simple_content)
        if wb_content:
            simple_blocks += [{"type":"h2","text":"تمرین‌های کتاب"}] + parse_content_lines(wb_content)
        master_lines=pages["master"]
        sup_marker=next((i for i,l in enumerate(master_lines) if l.strip().startswith('## 📝')), None)
        if sup_marker is None:
            master_content=master_lines; sup_content=[]
        else:
            master_content=master_lines[:sup_marker]; sup_content=master_lines[sup_marker:]
        master_blocks=parse_content_lines(master_content)
        master_blocks += _build_supplementary(sup_content)
        practice_lines=pages["practice"]
        answer_key=parse_practice_answer_key(pages["answer_key"])
        clean_body=[l for l in practice_lines if 'نام و نام خانوادگی' not in l]
        exam_blocks=[{"type":"h2","text":"امتحان"}]
        if clean_body:
            exam_blocks += build_practice_exercises(clean_body, answer_key)
        topic=L["topic"].replace('## Grammar:','').strip() if L["topic"] else ""
        out_lessons.append({
            "number":num,"title":L["title"].replace('# Lesson','').strip(),"topic":topic,
            "accent":meta["accent"],"icon":meta["icon"],
            "simple_blocks":simple_blocks,"master_blocks":master_blocks,"exam_exercises":exam_blocks,
        })
    return {"lessons": out_lessons}

# Re-run main at end so FIXES overrides are bound.
if __name__=='__main__':
    import sys
    md=sys.argv[1]; book=int(sys.argv[2]); out=sys.argv[3]
    data=convert_md(md, book)
    json.dump(data, open(out,'w',encoding='utf-8'), ensure_ascii=False, indent=1)
    for l in data["lessons"]:
        print(l["number"], "|", l["topic"], "| simple", len(l["simple_blocks"]), "master", len(l["master_blocks"]), "exam", len(l["exam_exercises"]))
    print("WROTE", out)
