let s:Multiselect = multiselect#import()
let s:multiselector = s:Multiselect.load()
let s:TRUE = 1
let s:FALSE = 0
let s:MAXCOL = 2147483647
let s:NULLPOS = [0, 0, 0, 0]

let s:inorderof = s:Multiselect.inorderof

let g:multiselect#keymap#openfold = get(g:, 'multiselect#keymap#openfold', s:TRUE)

function! multiselect#keymap#check(mode) abort  "{{{
	let head = getpos("'<")
	let tail = getpos("'>")
	let type = visualmode()
	let extended = type ==# "\<C-v>" ? s:is_extended() : 0
	let newitem = s:multiselector.check(head, tail, type, extended)
	call s:foldopen(newitem.head[1])
endfunction "}}}
function! multiselect#keymap#checksearched(mode) abort "{{{
	if empty(@/)
		return
	endif

	let view = winsaveview()
	let lastpattern = @/
	if a:mode ==# 'x'
		let start = getpos("'<")
		let end = getpos("'>")
	else
		let start = [0, 1, 1, 0]
		let end = [0, line('$'), col([line('$'), '$']), 0]
	endif
	let Region = s:Multiselect.Region(start, end)
	call setpos('.', Region.head)

	let head = s:searchpos(lastpattern, 'cW')
	if head == s:NULLPOS || !Region.isincluding(head)
		call winrestview(view)
		return
	endif
	while 1
		let tail = s:searchpos(lastpattern, 'ceW')
		if !Region.isincluding(tail)
			break
		endif
		let newitem = s:multiselector.check(head, tail, 'v')
		call s:foldopen(newitem.head[1])
		let head = s:searchpos(lastpattern, 'W')
		if head == s:NULLPOS || !Region.isincluding(head)
			break
		endif
	endwhile
	call winrestview(view)
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
function! s:searchpos(pat, flag) abort "{{{
	return [0] + searchpos(a:pat, a:flag) + [0]
endfunction "}}}
function! s:foldopen(lnum) abort "{{{
	if g:multiselect#keymap#openfold is s:FALSE
		return
	endif
	if a:lnum == 0 || foldclosed(a:lnum) == -1
		return
	endif

	let view = winsaveview()
	call cursor(a:lnum, 1)
	normal! zR
	call winrestview(view)
endfunction "}}}
" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set noet ts=4 sw=4 sts=-1:
