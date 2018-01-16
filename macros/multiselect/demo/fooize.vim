if exists("g:loaded_fooize")
  finish
endif
let g:loaded_fooize = 1

let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()

function! s:stopautoindent() abort
  let indentopt = {}
  let indentopt.autoindent = &l:autoindent
  let indentopt.smartindent = &l:smartindent
  let indentopt.cindent = &l:cindent
  let indentopt.indentexpr = &l:indentexpr
  let &l:autoindent = 0
  let &l:smartindent = 0
  let &l:cindent = 0
  let &l:indentexpr = ''
  return indentopt
endfunction

function! s:restoreautoindent(indentopt) abort
  let &l:autoindent = a:indentopt.autoindent
  let &l:smartindent = a:indentopt.smartindent
  let &l:cindent = a:indentopt.cindent
  let &l:indentexpr = a:indentopt.indentexpr
endfunction

function! Fooize() abort
  let itemlist = s:multiselector.emit()
  if empty(itemlist)
    return
  endif

  call s:multiselector.sort(itemlist)
  let indentopt = s:stopautoindent()
  try
    for item in reverse(itemlist)
      call item.select()
      normal! cfoo
    endfor
  finally
    call s:restoreautoindent(indentopt)
  endtry
endfunction

command! Fooize call Fooize()
nnoremap <silent> <Space>f :<C-u>call Fooize()<CR>
