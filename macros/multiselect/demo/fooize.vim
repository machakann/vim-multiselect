if exists("g:loaded_fooize")
  finish
endif
let g:loaded_fooize = 1

let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()
let s:shiftenv = s:Multiselect.shiftenv
let s:restoreenv = s:Multiselect.restoreenv

function! Fooize() abort
  let itemlist = s:multiselector.emit()
  if empty(itemlist)
    return
  endif

  call s:multiselector.sort(itemlist)
  let env = s:shiftenv()
  try
    for item in reverse(itemlist)
      call item.select()
      normal! cfoo
    endfor
  finally
    call s:restoreenv(env)
  endtry
endfunction

command! Fooize call Fooize()
nnoremap <silent> <Space>f :<C-u>call Fooize()<CR>
