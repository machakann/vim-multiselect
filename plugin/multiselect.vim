" multiselect.vim : An library for multiple selection
" Maintainer : Masaaki Nakamura <https://github.com/machakann>
if &compatible || exists("g:loaded_multiselect")
  finish
endif
let g:loaded_multiselect = 1



" keymappings
nnoremap <silent> <Plug>(multiselect-check) viw<Esc>:call multiselect#check('n')<CR>
xnoremap <silent> <Plug>(multiselect-check) <Esc>:call multiselect#check('x')<CR>
nnoremap <silent> <Plug>(multiselect-uncheck) :<C-u>call multiselect#uncheck('n')<CR>
xnoremap <silent> <Plug>(multiselect-uncheck) :<C-u>call multiselect#uncheck('x')<CR>
nnoremap <silent> <Plug>(multiselect-uncheckall) :<C-u>call multiselect#uncheckall('n')<CR>
xnoremap <silent> <Plug>(multiselect-uncheckall) :<C-u>call multiselect#uncheckall('x')<CR>



" default keymappings
if exists('g:multiselect_no_default_keymappings')
	finish
endif
nmap <CR> <Plug>(multiselect-check)
xmap <CR> <Plug>(multiselect-check)
nmap <BS> <Plug>(multiselect-uncheck)
xmap <BS> <Plug>(multiselect-uncheck)
nmap <S-BS> <Plug>(multiselect-uncheckall)
xmap <S-BS> <Plug>(multiselect-uncheckall)

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=4:
