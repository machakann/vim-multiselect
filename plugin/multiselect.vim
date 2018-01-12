" multiselect.vim : An library for multiple selection
" Maintainer : Masaaki Nakamura <https://github.com/machakann>
if &compatible || exists("g:loaded_multiselect")
  finish
endif
let g:loaded_multiselect = 1

" keymappings
nnoremap <silent> <Plug>(multiselect-check) :<C-u>call multiselect#keymap#check('n')<CR>
xnoremap <silent> <Plug>(multiselect-check) <Esc>:call multiselect#keymap#check('x')<CR>
nnoremap <silent> <Plug>(multiselect-checksearched) :<C-u>call multiselect#keymap#checkpattern('n', @/)<CR>
xnoremap <silent> <Plug>(multiselect-checksearched) <Esc>:call multiselect#keymap#checkpattern('x', @/)<CR>
nnoremap <silent> <Plug>(multiselect-uncheck) :<C-u>call multiselect#keymap#uncheck('n')<CR>
xnoremap <silent> <Plug>(multiselect-uncheck) <Esc>:call multiselect#keymap#uncheck('x')<CR>
nnoremap <silent> <Plug>(multiselect-uncheckall) :<C-u>call multiselect#keymap#uncheckall()<CR>
xnoremap <silent> <Plug>(multiselect-uncheckall) <Esc>:call multiselect#keymap#uncheckall()<CR>
nnoremap <silent> <Plug>(multiselect-toggle) :<C-u>call multiselect#keymap#toggle('n')<CR>
xnoremap <silent> <Plug>(multiselect-toggle) <Esc>:call multiselect#keymap#toggle('x')<CR>
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=4:
