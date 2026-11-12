# Tools for editing and reviewing the Murmuration pages

- `render_text.py IN.html OUT.txt` renders a page as plain text. Reviewers are given this text and nothing else.
- `edit_lib.py` applies exact-match edits to a page and fails if a match is missing or not unique: `Doc().sub(old, new)`, `.line(unique_substring, new_line)`, `.block(start, end, new)`, `.save()`.
- `validate_html.py [page.html]` checks tag balance, unique ids and in-page links.
- `review_brief_r45.md` is the brief the fifth-review reviewers worked from. Copy it for the next round, change the revision, the line count and the list of what is new, and render a fresh text file. A reviewer must not open anything else in this repository.

To edit a page: write the edits as a script that uses `edit_lib`, run it, run `validate_html.py`, re-render the text and grep it for wording the edit made stale.
