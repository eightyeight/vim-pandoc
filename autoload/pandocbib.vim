" autoload/pandocbib.vim
"
" bibliographic completions for vim-pandoc
"
python<<EOF
import vim
import re
from os.path import basename
from operator import itemgetter
import json

bibtex_title_search = re.compile("^\s*[Tt]itle\s*=\s*{(?P<title>\S.*)}.*\n", re.MULTILINE)
bibtex_booktitle_search = re.compile("^\s*[Bb]ooktitle\s*=\s*{(?P<booktitle>\S.*)}.*\n", re.MULTILINE)
bibtex_author_search = re.compile("^\s*[Aa]uthor\s*=\s*{(?P<author>\S.*)}.*\n", re.MULTILINE)
bibtex_editor_search = re.compile("^\s*[Ee]ditor\s*=\s*{(?P<editor>\S.*)}.*\n", re.MULTILINE)
bibtex_crossref_search = re.compile("^\s*[Cc]rossref\s*=\s*{(?P<crossref>\S.*)}.*\n", re.MULTILINE)

def pandoc_get_bibtex_suggestions(text, query):
	global bibtex_title_search
	global bibtex_booktitle_search
	global bibtex_author_search
	global bibtex_editor_search
	global bibtex_crossref_search

	entries = []
	bibtex_id_search = re.compile(".*{\s*(?P<id>" + query + ".*),")

	for entry in [i for i in re.split("\n@", text)]:
		entry_dict = {}
		i1 = bibtex_id_search.match(entry)
		if i1:
			entry_dict["word"] = i1.group("id")

			title = "..."
			author = "..."
			# search for title
			i2 = bibtex_title_search.search(entry)
			if i2:
				title = i2.group("title")
			else:
				i3 = bibtex_booktitle_search.search(entry)
				if i3:
					title = i3.group("title")
			title = title.replace("{", "").replace("}", "")

			# search for author
			i4 = bibtex_author_search.search(entry)
			if i4:
				author = i4.group("author")
			else:
				i5 = bibtex_editor_search.search(entry)
				if i5:
					author = i5.group("editor")
				else:
					i6 = bibtex_crossref_search.search(entry)
					if i6:
						author = "@" + i6.group("crossref")

			entry_dict["menu"] = " - ".join([author, title])
				
			entries.append(entry_dict)
	
	return entries

ris_title_search = re.compile("^(TI|T1|CT|BT|T2|T3)\s*-\s*(?P<title>.*)\n", re.MULTILINE)
ris_author_search = re.compile("^(AU|A1|A2|ED|A3)\s*-\s*(?P<author>.*)\n", re.MULTILINE)

def pandoc_get_ris_suggestions(text, query):
	global ris_title_search
	global ris_author_search

	entries = []

	ris_id_search = re.compile("^ID\s*-\s*(?P<id>" +  query + ".*)\n", re.MULTILINE)

	for entry in re.split("ER\s*-\s*\n", text):
		entry_dict = {}
		i1 = ris_id_search.search(entry)
		if i1:
			entry_dict["word"] = i1.group("id")
			title = "..."
			author = "..."
			i2 = ris_title_search.search(entry)
			if i2:
				title = i2.group("title")
			i3 = ris_author_search.search(entry)
			if i3:
				author = i3.group("author")

			entry_dict["menu"] = " - ".join([author, title])
			entries.append(entry_dict)

	return entries

def pandoc_get_mods_suggestions(text, query):
	return []

def pandoc_get_json_suggestions(text, query):
	entries = []
	data = json.loads(text)
	for entry in data:
		entry_dict = {}
		if all([entry.has_key(k) for k in ["author", "title", "id"]]):
			entry_dict["word"] = str(entry["id"])
			author = entry["author"][0]["family"] + ", " + entry["author"][0]["given"]
			title = entry["title"]
			entry_dict["menu"] = " - ".join([str(author), str(title)])
			entries.append(entry_dict)
	return entries
EOF

function! pandocbib#PandocBibSuggestions(partkey)
python<<EOF
bibs = vim.eval("b:pandoc_bibfiles")
query = vim.eval("a:partkey")

matches = []

for bib in bibs:
	bib_type = basename(bib).split(".")[-1].lower()
	with open(bib) as f:
		text = f.read()

	ids = []
	if bib_type == "mods":
		ids = pandoc_get_mods_suggestions(text, query)
	elif bib_type == "ris":
		ids = pandoc_get_ris_suggestions(text, query)
	elif bib_type == "json":
		ids = pandoc_get_json_suggestions(text, query)
	else:
		ids = pandoc_get_bibtex_suggestions(text, query)

	matches.extend(ids)

matches = sorted(matches, key=itemgetter("word"))
# for now, we remove non ascii characters. TODO: handle that properly
vim.command("return " + re.sub(r'\\x\S{2}', "", str(matches)))
EOF
endfunction