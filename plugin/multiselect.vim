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
nnoremap <silent> <Plug>(multiselect-undo) :<C-u>call multiselect#keymap#undo()<CR>
xnoremap <silent> <Plug>(multiselect-undo) <Esc>:call multiselect#keymap#undo()<CR>
nnoremap <silent> <Plug>(multiselect-next) :<C-u>call multiselect#keymap#next('n')<CR>
xnoremap <silent> <Plug>(multiselect-next) :<C-u>call multiselect#keymap#next('x')<CR>
onoremap <silent> <Plug>(multiselect-next) :<C-u>call multiselect#keymap#next('o')<CR>
nnoremap <silent> <Plug>(multiselect-previous) :<C-u>call multiselect#keymap#previous('n')<CR>
xnoremap <silent> <Plug>(multiselect-previous) :<C-u>call multiselect#keymap#previous('x')<CR>
onoremap <silent> <Plug>(multiselect-previous) :<C-u>call multiselect#keymap#previous('o')<CR>
nnoremap <silent> <Plug>(multiselect) :<C-u>call multiselect#keymap#multiselect('n')<CR>
xnoremap <silent> <Plug>(multiselect) <Esc>:call multiselect#keymap#multiselect('x')<CR>

" broadcasting textobjects
xnoremap <silent> <Plug>(multiselect-iw) <Esc>:call multiselect#keymap#broadcast('iw')<CR>
xnoremap <silent> <Plug>(multiselect-aw) <Esc>:call multiselect#keymap#broadcast('aw')<CR>
xnoremap <silent> <Plug>(multiselect-iW) <Esc>:call multiselect#keymap#broadcast('iW')<CR>
xnoremap <silent> <Plug>(multiselect-aW) <Esc>:call multiselect#keymap#broadcast('aW')<CR>
xnoremap <silent> <Plug>(multiselect-i') <Esc>:call multiselect#keymap#broadcast("i'")<CR>
xnoremap <silent> <Plug>(multiselect-a') <Esc>:call multiselect#keymap#broadcast("a'")<CR>
xnoremap <silent> <Plug>(multiselect-i") <Esc>:call multiselect#keymap#broadcast('i"')<CR>
xnoremap <silent> <Plug>(multiselect-a") <Esc>:call multiselect#keymap#broadcast('a"')<CR>
xnoremap <silent> <Plug>(multiselect-i`) <Esc>:call multiselect#keymap#broadcast('i`')<CR>
xnoremap <silent> <Plug>(multiselect-a`) <Esc>:call multiselect#keymap#broadcast('a`')<CR>
xnoremap <silent> <Plug>(multiselect-i() <Esc>:call multiselect#keymap#broadcast('i(')<CR>
xnoremap <silent> <Plug>(multiselect-a() <Esc>:call multiselect#keymap#broadcast('a(')<CR>
xnoremap <silent> <Plug>(multiselect-i[) <Esc>:call multiselect#keymap#broadcast('i[')<CR>
xnoremap <silent> <Plug>(multiselect-a[) <Esc>:call multiselect#keymap#broadcast('a[')<CR>
xnoremap <silent> <Plug>(multiselect-i{) <Esc>:call multiselect#keymap#broadcast('i{')<CR>
xnoremap <silent> <Plug>(multiselect-a{) <Esc>:call multiselect#keymap#broadcast('a{')<CR>
xnoremap <silent> <Plug>(multiselect-it) <Esc>:call multiselect#keymap#broadcast('it')<CR>
xnoremap <silent> <Plug>(multiselect-at) <Esc>:call multiselect#keymap#broadcast('at')<CR>
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=4:
