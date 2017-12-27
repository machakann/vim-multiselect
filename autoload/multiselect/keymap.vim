let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()
let s:MAXCOL = 2147483647

function! multiselect#keymap#check(mode) abort  "{{{
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()[0]
	let extended = type ==# "\<C-v>" ? s:is_extended() : 0
	call s:multiselector.check(head, tail, type, extended)
endfunction "}}}
function! multiselect#keymap#uncheck(mode) abort  "{{{
	if a:mode ==# 'n'
		call s:multiselector.uncheck()
	elseif a:mode ==# 'x'
		call s:multiselector.uncheck(getpos("'<"), getpos("'>"))
	endif
endfunction "}}}
function! multiselect#keymap#uncheckall(mode) abort  "{{{
	return s:multiselector.uncheckall()
endfunction "}}}
function! s:is_extended() abort "{{{
	let view = winsaveview()
	normal! gv
	let extended = winsaveview().curswant == s:MAXCOL
	execute "normal! \<Esc>"
	call winrestview(view)
	return extended
endfunction
"}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
