if exists('g:loaded_d2preview')
  finish
endif
let g:loaded_d2preview = 1

function! s:current_d2_block() abort
  let l:save = getpos('.')
  let l:cursor = line('.')

  let l:start = search('^```d2\s*$', 'bnW')
  let l:end = search('^```\s*$', 'nW')

  call setpos('.', l:save)

  if l:start == 0 || l:end == 0
    return v:null
  endif

  if l:cursor <= l:start || l:cursor >= l:end
    return v:null
  endif

  return {
  \ 'line_start': l:start + 1,
  \ 'line_end': l:end - 1,
  \ }
endfunction
