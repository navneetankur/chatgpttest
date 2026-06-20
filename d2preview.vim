
" d2preview.vim
" Implementation based on design document.

if exists('g:loaded_d2preview')
  finish
endif
let g:loaded_d2preview = 1

command! -range D2Preview call d2preview#preview(<line1>, <line2>, mode())
command! D2PreviewFile call d2preview#preview_file()

let s:ns = {}

function! d2preview#preview(line1, line2, visualmode) abort
  let b:d2_preview_dirty = 0

  if a:visualmode =~# 'v'
    let b:d2_start = a:line1
    let b:d2_end   = a:line2
  else
    unlet! b:d2_start b:d2_end
    let b:d2_mode = 'block'
  endif

  call s:ensure_preview()
  call s:render()
endfunction

function! d2preview#preview_file() abort
  unlet! b:d2_start b:d2_end
  let b:d2_mode = 'file'
  call s:ensure_preview()
  call s:render()
endfunction

function! s:ensure_preview() abort
  if exists('b:d2_preview_bufnr') && bufexists(b:d2_preview_bufnr)
    return
  endif

  vnew
  let b:d2_preview_bufnr = bufnr('%')

  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal noswapfile
  setlocal nomodifiable
  setlocal readonly
endfunction

function! s:get_input() abort
  if exists('b:d2_start') && exists('b:d2_end')
    return join(getline(b:d2_start, b:d2_end), "\n")
  endif

  if get(b:, 'd2_mode', '') ==# 'file'
    return join(getline(1, '$'), "\n")
  endif

  return join(getline(1, '$'), "\n")
endfunction

function! s:render() abort
  let l:input = s:get_input()

  if exists('b:d2_job')
    call jobstop(b:d2_job)
  endif

  call s:set_status('[rendering...]')

  let l:cmd = ['d2', '--stdout-format', 'txt', '-']
  let l:job = jobstart(l:cmd, {
        \ 'stdin': 'pipe',
        \ 'on_stdout': function('s:on_stdout'),
        \ 'on_exit': function('s:on_exit')
        \ })

  let b:d2_job = l:job
  let b:d2_output = []

  call chansend(l:job, l:input)
  call chanclose(l:job, 'stdin')
endfunction

function! s:on_stdout(jobid, data, event) abort
  if a:jobid != get(b:, 'd2_job', -1)
    return
  endif
  call extend(b:d2_output, a:data)
endfunction

function! s:on_exit(jobid, code, event) abort
  if a:jobid != get(b:, 'd2_job', -1)
    return
  endif

  if a:code == 0
    let l:view = winsaveview()
    setlocal modifiable noreadonly
    call setline(1, b:d2_output)
    setlocal nomodifiable readonly
    call winrestview(l:view)
    let b:d2_preview_dirty = 0
  else
    call s:set_status('[render failed]')
  endif
endfunction

function! s:set_status(text) abort
  setlocal modifiable noreadonly
  call setline(1, [a:text, ''])
  setlocal nomodifiable readonly
endfunction
