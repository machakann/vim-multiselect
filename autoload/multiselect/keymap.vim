let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]

let s:inorderof = s:Multiselect.inorderof

let g:multiselect#keymap#openfold = get(g:, 'multiselect#keymap#openfold', s:TRUE)

function! multiselect#keymap#check(mode) abort  "{{{
	call s:multiselector.keymap_check(a:mode)
endfunction "}}}
function! multiselect#keymap#checkpattern(mode, pat) abort "{{{
	call s:multiselector.keymap_checkpattern(a:mode, a:pat)
endfunction "}}}
function! multiselect#keymap#uncheck(mode) abort  "{{{
	call s:multiselector.keymap_uncheck(a:mode)
endfunction "}}}
function! multiselect#keymap#uncheckall() abort  "{{{
	call s:multiselector.keymap_uncheckall()
endfunction "}}}
function! multiselect#keymap#toggle(mode) abort "{{{
	call s:multiselector.keymap_toggle(a:mode)
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
