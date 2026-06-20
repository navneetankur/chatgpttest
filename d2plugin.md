# D2 Vim Plugin Design

## Goal

Preview D2 diagrams as ASCII art inside Vim/Neovim using:

```sh
d2 --stdout-format txt -
```

The plugin should support:

* Visual selections
* Markdown fenced D2 blocks
* Automatic refresh
* Asynchronous rendering

---

## Preview Modes

A preview operates in one of three modes:

```text
selection
block
file
```

Stored per source buffer:

```vim
b:d2_mode
```

Possible values:

```text
block
file
```

Selection mode is active whenever:

```vim
exists(b:d2_start)
exists(b:d2_end)
```

---

## Manual Command

### Visual Selection

If `:D2Preview` is executed from a visual selection:

1. Save the selected line range.
2. Enter selection mode.
3. Render only that range.

Store:

```vim
b:d2_start
b:d2_end
```

Example:

```text
Lines 50-80 selected
:D2Preview
```

stores:

```vim
b:d2_start = 50
b:d2_end = 80
```

Subsequent refreshes continue rendering that same range.

Selection detection only occurs during manual command execution.

Automatic refreshes never recalculate the selection.

---

### Block Preview

Command:

```vim
:D2Preview
```

without a visual selection:

1. Clear any saved selection.
2. Set:

```vim
b:d2_mode = "block"
```

3. Render the current D2 block.

Cursor must be inside a D2 block.

---

### File Preview

Command:

```vim
:D2PreviewFile
```

1. Clear any saved selection.
2. Set:

```vim
b:d2_mode = "file"
```

3. Render all D2 blocks in the file.

---

## Preview Target Priority

```text
Saved selection
    >
Mode=file
Mode=block
```

---

## Preview Buffer

One preview buffer per source buffer.

Source buffer stores:

```vim
b:d2_preview_bufnr
b:d2_preview_dirty
b:d2_mode
b:d2_start
b:d2_end
b:d2_job
```

Preview buffer settings:

```vim
setlocal buftype=nofile
setlocal bufhidden=wipe
setlocal noswapfile
setlocal nomodifiable
setlocal readonly
```

The preview buffer is generated output and should not be editable.

---

## Automatic Refresh

Automatic refresh is based on cursor location.

The plugin intentionally does not track changes, modified ranges, hashes, or changedtick values.

A save only triggers a refresh when the cursor is currently within the area represented by the preview.

---

### Selection Mode

Selection mode is active when:

```vim
exists(b:d2_start)
exists(b:d2_end)
```

On save:

```text
Cursor inside saved range?
```

If yes:

```text
Render saved range
```

Otherwise:

```text
Ignore save
```

---

### Block Mode

On save:

```text
Cursor inside a d2 block?
```

If yes:

```text
Render current block
```

Otherwise:

```text
Ignore save
```

---

### File Mode

On save:

```text
Cursor inside a d2 block?
```

If yes:

```text
Render all d2 blocks
```

Otherwise:

```text
Ignore save
```

---

## Hidden Preview Handling

When a refresh would occur but the preview buffer is not visible:

```vim
b:d2_preview_dirty = 1
```

No rendering is performed while hidden.

---

## Refreshing Hidden Previews

When entering the preview buffer:

```text
BufEnter preview-buffer
```

If:

```text
dirty == 1
```

then:

```text
Render
Clear dirty flag
```

This covers:

```vim
:buffer
:b
:sbuffer
buffer pickers
manual navigation
```

No window tracking is required.

---

## Rendering

Rendering is asynchronous using:

```vim
jobstart(...)
```

No blocking shell commands should run inside the editor.

---

### Before Render

Insert a status line at the top of the preview:

```text
[rendering...]
```

The previous successful preview remains visible.

Example:

```text
[rendering...]

(previous preview remains visible)
```

---

## Render Completion

### Success

1. Replace preview contents with new output.
2. Remove status line.
3. Set:

```vim
b:d2_preview_dirty = 0
```

---

### Failure

Show:

```text
[render failed]
```

while preserving the last successful render.

Error reporting can be expanded later.

---

## Job Cancellation

Only one render job may be active per source buffer.

Before starting a render:

```vim
jobstop(b:d2_job)
```

if a previous job is still running.

Start the new job and store:

```vim
b:d2_job = new_job_id
```

---

## Completion Guard

When a job exits:

```text
job_id == current_job_id ?
```

If not:

```text
Ignore result
```

This prevents stale renders from replacing newer output.

Example:

```text
Render A
Render B
Render C
```

Completion order:

```text
C
A
B
```

Only C is accepted.

---

## Determining What To Render

### Selection Mode

```text
Render saved line range
```

---

### Block Mode

```text
Render current d2 block
```

Cursor must be inside a D2 block.

---

### File Mode

```text
Render all d2 blocks
```

---

## Future Ideas

### v2

* Better error reporting.
* Display D2 stderr.
* Dedicated refresh command.

### v3

* Optional live preview.
* Persistent D2 daemon/server if startup cost proves significant.
* Advanced preview window management.

### alternate design, not selected

#### Input Hash Optimization

To avoid unnecessary renders, compute a hash of the exact D2 input before starting a render job.

Store:

```vim
b:d2_input_hash
```

Before launching a render:

```text
Extract render target
Compute hash
Compare with previous hash
```

If:

```text
new_hash == b:d2_input_hash
```

then:

```text
Skip render
```

Otherwise:

```text
b:d2_input_hash = new_hash
Start render job
```

This avoids rerendering when:

* Saving unrelated changes.
* Repeated saves without diagram modifications.
* Cursor-based refresh logic triggers but the rendered content has not changed.

The optimization is intentionally omitted from v1 because the existing cursor-based rules already eliminate most unnecessary renders while keeping implementation simple. Though this can replace cursor inside d2 check completely and always send job if hash changed.
