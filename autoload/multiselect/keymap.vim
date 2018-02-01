let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]

let s:inorderof = s:Multiselect.inorderof

let g:multiselect#keymap#openfold = !!get(g:, 'multiselect#keymap#openfold', s:FALSE)

function! multiselect#keymap#check(mode) abort  "{{{
	call s:multiselector.keymap_check(a:mode)
endfunction "}}}

function! multiselect#keymap#checkpattern(mode, pat) abort "{{{
	let options = {'openfold': g:multiselect#keymap#openfold}
	call s:multiselector.keymap_checkpattern(a:mode, a:pat, options)
endfunction "}}}

function! multiselect#keymap#uncheck(mode) abort  "{{{
	call s:multiselector.keymap_uncheck(a:mode)
endfunction "}}}

function! multiselect#keymap#uncheckall() abort  "{{{
	call s:multiselector.keymap_uncheckall()
endfunction "}}}

function! multiselect#keymap#undo() abort "{{{
	call s:multiselector.keymap_undo()
endfunction "}}}

function! multiselect#keymap#next(mode) abort "{{{
	call s:multiselector.keymap_next(a:mode)
endfunction "}}}

function! multiselect#keymap#previous(mode) abort "{{{
	call s:multiselector.keymap_previous(a:mode)
endfunction "}}}

function! multiselect#keymap#multiselect(mode) abort "{{{
	call s:multiselector.keymap_multiselect(a:mode)
endfunction "}}}

function! multiselect#keymap#broadcast(cmd, ...) abort "{{{
	let options = get(a:000, 0, {})
	call extend(options, {'openfold': g:multiselect#keymap#openfold})
	call s:multiselector.keymap_broadcast(a:cmd, options)
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
